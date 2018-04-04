//    SMStoreSyncOperation.swift
//
//    The MIT License (MIT)
//
//    Copyright (c) 2016 Paul Wilkinson ( https://github.com/paulw11 )
//
//    Based on work by Nofel Mahmood
//
//    Portions copyright (c) 2015 Nofel Mahmood ( https://twitter.com/NofelMahmood )
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.


import Foundation
import CloudKit
import CoreData


enum SMSyncOperationError: Error {
    case localChangesFetchError
    case conflictsDetected(conflictedRecords: [CKRecord])
    case missingReferences(referringRcords: [CKRecord])
    case unknownError
}

extension SMSyncOperationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .localChangesFetchError:
            return NSLocalizedString("Failed to fetch local changes.", comment: "localChangesFetchError")
        case .conflictsDetected(let records):
            return String(format:NSLocalizedString("%d conflicted records detected.", comment: "conflictsDetected"),records.count)
        case .missingReferences(let records):
            return String(format:NSLocalizedString("%d records with missing references.", comment: "conflictsDetected"),records.count)
        case .unknownError:
            return NSLocalizedString("Unknown Seam3 error.", comment: "unknownError")
        }
    }
}

class SMStoreSyncOperation: Operation {
    
    static let SMStoreSyncOperationErrorDomain = "SMStoreSyncOperationDomain"
    static let SMSyncConflictsResolvedRecordsKey = "SMSyncConflictsResolvedRecordsKey"
    
    fileprivate var operationQueue: OperationQueue!
    fileprivate var localStoreMOC: NSManagedObjectContext!
    fileprivate var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    fileprivate var entities: Array<NSEntityDescription>
    fileprivate var database: CKDatabase?
    fileprivate let RETRYLIMIT = 5
    var syncConflictPolicy: SMSyncConflictResolutionPolicy
    var syncCompletionBlock: ((_ syncError:NSError?) -> ())?
    var syncConflictResolutionBlock: ((_ clientRecord:CKRecord,_ serverRecord:CKRecord)->CKRecord)?
    
    init(persistentStoreCoordinator:NSPersistentStoreCoordinator?,entitiesToSync entities:[NSEntityDescription], conflictPolicy:SMSyncConflictResolutionPolicy = .serverRecordWins, database: CKDatabase?) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.entities = entities
        self.database = database
        self.syncConflictPolicy = conflictPolicy
        super.init()
    }
    
    // MARK: Sync
    override func main() {
        print("Sync Started", terminator: "\n")
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        self.localStoreMOC = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        self.localStoreMOC.persistentStoreCoordinator = self.persistentStoreCoordinator
        if let completionBlock = self.syncCompletionBlock {
            do {
                try self.performSync()
                print("Sync Performed", terminator: "\n")
                completionBlock(nil)
            } catch let error as NSError {
                print("Sync Performed with Error", terminator: "\n")
                completionBlock(error)
            }
        }
    }
    
    func performSync() throws {
        var localChangesInServerRepresentation = try self.localChangesInServerRepresentation()
        do {
            try self.applyLocalChangesToServer(insertedOrUpdatedCKRecords: localChangesInServerRepresentation.insertedOrUpdatedCKRecords, deletedCKRecordIDs: localChangesInServerRepresentation.deletedCKRecordIDs)
            try self.fetchAndApplyServerChangesToLocalDatabase()
            SMServerTokenHandler.defaultHandler.commit()
            try SMStoreChangeSetHandler.defaultHandler.removeAllQueuedChangeSets(backingContext: self.localStoreMOC!)
            return
        } catch SMSyncOperationError.conflictsDetected(let conflictedRecords) {
            let resolvedRecords = self.resolveConflicts(conflictedRecords: conflictedRecords)
            var insertedOrUpdatedCKRecordsWithRecordIDStrings: Dictionary<String,CKRecord> = Dictionary<String,CKRecord>()
            for record in localChangesInServerRepresentation.insertedOrUpdatedCKRecords! {
                let ckRecord: CKRecord = record as CKRecord
                insertedOrUpdatedCKRecordsWithRecordIDStrings[ckRecord.recordID.recordName] = ckRecord
            }
            for record in resolvedRecords {
                insertedOrUpdatedCKRecordsWithRecordIDStrings[record.recordID.recordName] = record
            }
            localChangesInServerRepresentation.insertedOrUpdatedCKRecords = Array(insertedOrUpdatedCKRecordsWithRecordIDStrings.values)
            try self.applyLocalChangesToServer(insertedOrUpdatedCKRecords: localChangesInServerRepresentation.insertedOrUpdatedCKRecords, deletedCKRecordIDs: localChangesInServerRepresentation.deletedCKRecordIDs)
            try self.fetchAndApplyServerChangesToLocalDatabase()
            SMServerTokenHandler.defaultHandler.commit()
            try SMStoreChangeSetHandler.defaultHandler.removeAllQueuedChangeSets(backingContext: self.localStoreMOC!)
        } catch {
            throw error
        }
    }
    
    func fetchAndApplyServerChangesToLocalDatabase() throws {
        var moreComing = true
        var insertedOrUpdatedCKRecordsFromServer = [CKRecord]()
        var deletedCKRecordIDsFromServer = [CKRecordID]()
        while moreComing {
            let returnValue = self.fetchRecordChangesFromServer()
            insertedOrUpdatedCKRecordsFromServer.append(contentsOf: [] + returnValue.insertedOrUpdatedCKRecords)
            deletedCKRecordIDsFromServer.append(contentsOf: [] + returnValue.deletedRecordIDs)
            moreComing = returnValue.moreComing
        }
        try self.applyServerChangesToLocalDatabase(insertedOrUpdatedCKRecordsFromServer, deletedCKRecordIDs: deletedCKRecordIDsFromServer)
    }
    
    // MARK: Local Changes
    func applyServerChangesToLocalDatabase(_ insertedOrUpdatedCKRecords: [CKRecord], deletedCKRecordIDs:[CKRecordID]) throws {
        try self.insertOrUpdateManagedObjects(fromCKRecords: insertedOrUpdatedCKRecords)
        try self.deleteManagedObjects(fromCKRecordIDs: deletedCKRecordIDs)
    }
    
    func applyLocalChangesToServer(insertedOrUpdatedCKRecords: Array<CKRecord>? , deletedCKRecordIDs: Array<CKRecordID>?) throws {
        
        if insertedOrUpdatedCKRecords == nil && deletedCKRecordIDs == nil {
            return
        }
        
        var changedRecords = [String:CKRecord]()
        
        for record in insertedOrUpdatedCKRecords ?? [] {
            let recordName = record.recordID.recordName
            if let currentRecord = changedRecords[recordName] {
                if let currentDate = currentRecord.modificationDate,
                    let newDate = record.modificationDate {
                    if newDate > currentDate {
                        changedRecords[recordName] = record
                    }
                }
            } else {
                changedRecords[recordName] = record
            }
        }
        
        let ckModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: Array(changedRecords.values), recordIDsToDelete: deletedCKRecordIDs)
        ckModifyRecordsOperation.database = self.database
        let savedRecords: [CKRecord] = [CKRecord]()
        var conflictedRecords: [CKRecord] = [CKRecord]()
        ckModifyRecordsOperation.modifyRecordsCompletionBlock = ({(savedRecords,deletedRecordIDs,operationError)->Void in
            if operationError != nil {
                print("Operation error \(operationError!)")
            }
        })
        ckModifyRecordsOperation.perRecordCompletionBlock = ({(ckRecord,operationError)->Void in
            
            let error:NSError? = operationError as NSError?
            if error != nil && error!.code == CKError.serverRecordChanged.rawValue
            {
                print("Conflicted Record \(error!)", terminator: "\n")
                conflictedRecords.append(ckRecord)
            }
        })
        self.operationQueue.addOperation(ckModifyRecordsOperation)
        self.operationQueue.waitUntilAllOperationsAreFinished()
        guard conflictedRecords.isEmpty else {
            throw SMSyncOperationError.conflictsDetected(conflictedRecords: conflictedRecords)
        }
        if !savedRecords.isEmpty {
            let recordIDSubstitution = "recordIDSubstitution"
            let fetchPredicate: NSPredicate = NSPredicate(format: "%K == $recordIDSubstitution", SMStore.SMLocalStoreRecordIDAttributeName)
            for record in savedRecords {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: record.recordType)
                let recordIDString: String = record.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                fetchRequest.predicate = fetchPredicate.withSubstitutionVariables([recordIDSubstitution:recordIDString])
                fetchRequest.fetchLimit = 1
                let results = try self.localStoreMOC!.fetch(fetchRequest)
                if results.count > 0 {
                    let managedObject = results.last as? NSManagedObject
                    let encodedFields = record.encodedSystemFields()
                    managedObject?.setValue(encodedFields, forKey: SMStore.SMLocalStoreRecordEncodedValuesAttributeName)
                }
            }
            try self.localStoreMOC.saveIfHasChanges()
        }
    }
    
    func resolveConflicts(conflictedRecords: [CKRecord]) -> [CKRecord]
    {
        var finalCKRecords: [CKRecord] = [CKRecord]()
        if conflictedRecords.count > 0 {
            var conflictedRecordsWithStringRecordIDs: Dictionary<String,(clientRecord:CKRecord?,serverRecord:CKRecord?)> = Dictionary<String,(clientRecord:CKRecord?,serverRecord:CKRecord?)>()
            for record in conflictedRecords {
                conflictedRecordsWithStringRecordIDs[record.recordID.recordName] = (record,nil)
            }
            let ckFetchRecordsOperation:CKFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: conflictedRecords.map({(object)-> CKRecordID in
                let ckRecord:CKRecord = object as CKRecord
                return ckRecord.recordID
            }))
            
            ckFetchRecordsOperation.database = database
            
            ckFetchRecordsOperation.perRecordCompletionBlock = ({(record,recordID,error)->Void in
                if error == nil {
                    let ckRecord: CKRecord? = record
                    let ckRecordID: CKRecordID? = recordID
                    if conflictedRecordsWithStringRecordIDs[ckRecordID!.recordName] != nil {
                        conflictedRecordsWithStringRecordIDs[ckRecordID!.recordName] = (conflictedRecordsWithStringRecordIDs[ckRecordID!.recordName]!.clientRecord,ckRecord)
                    }
                }
            })
            self.operationQueue?.addOperation(ckFetchRecordsOperation)
            self.operationQueue?.waitUntilAllOperationsAreFinished()
            
            for key in Array(conflictedRecordsWithStringRecordIDs.keys) {
                let value = conflictedRecordsWithStringRecordIDs[key]!
                var clientServerCKRecord = value as (clientRecord:CKRecord?,serverRecord:CKRecord?)
                
                switch self.syncConflictPolicy {
                    
                case .clientTellsWhichWins:
                    if self.syncConflictResolutionBlock != nil {
                        clientServerCKRecord.serverRecord = self.syncConflictResolutionBlock!(clientServerCKRecord.clientRecord!,clientServerCKRecord.serverRecord!)
                    } else {
                        print("ClientTellsWhichWins conflict resolution policy requires to set syncConflictResolutionBlock on the instance of SMStore.  Defaulting to serverRecordWins")
                    }
                    
                case .clientRecordWins:
                    
                    if let clientRecord = clientServerCKRecord.clientRecord {
                        clientServerCKRecord.serverRecord = clientRecord
                    }
                    
                case .serverRecordWins:
                    print("Resolving conflict in favour of server")
                    if clientServerCKRecord.serverRecord == nil {
                        if let clientRecord = clientServerCKRecord.clientRecord {
                            do {
                                try deleteManagedObjects(fromCKRecordIDs: [clientRecord.recordID])
                            } catch {
                                NSLog("Error deleting client record \(error)")
                            }
                            clientServerCKRecord.clientRecord = nil
                        }
                    }
                }
                if let serverRecord = clientServerCKRecord.serverRecord {
                    finalCKRecords.append(serverRecord)
                } else if let clientRecord = clientServerCKRecord.clientRecord {
                    finalCKRecords.append(clientRecord)
                }
            }
            
        }
        return finalCKRecords
    }
    
    func localChangesInServerRepresentation() throws -> (insertedOrUpdatedCKRecords:Array<CKRecord>?,deletedCKRecordIDs:Array<CKRecordID>?) {
        let changeSetHandler = SMStoreChangeSetHandler.defaultHandler
        let insertedOrUpdatedCKRecords = try changeSetHandler.recordsForUpdatedObjects(backingContext: self.localStoreMOC!)
        let deletedCKRecordIDs = try changeSetHandler.recordIDsForDeletedObjects(self.localStoreMOC!)
        return (insertedOrUpdatedCKRecords,deletedCKRecordIDs)
    }
    
    func fetchRecordChangesFromServer() -> (insertedOrUpdatedCKRecords:Array<CKRecord>,deletedRecordIDs:Array<CKRecordID>,moreComing:Bool) {
        
        var syncOperationError: Error? = nil
        var moreComing = false
        
        let token = SMServerTokenHandler.defaultHandler.token()
        let recordZoneID = CKRecordZoneID(zoneName: SMStore.SMStoreCloudStoreCustomZoneName, ownerName: CKOwnerDefaultName)
        let fetchRecordChangesOperation = CKFetchRecordChangesOperation(recordZoneID: recordZoneID, previousServerChangeToken: token)
        fetchRecordChangesOperation.database = self.database
        var insertedOrUpdatedCKRecords: [CKRecord] = [CKRecord]()
        var deletedCKRecordIDs: [CKRecordID] = [CKRecordID]()
        fetchRecordChangesOperation.fetchRecordChangesCompletionBlock = { serverChangeToken,clientChangeToken,operationError in
            if operationError == nil {
                SMServerTokenHandler.defaultHandler.save(serverChangeToken: serverChangeToken!)
                SMServerTokenHandler.defaultHandler.commit()
            } else {
                syncOperationError = operationError
            }
        }
        fetchRecordChangesOperation.recordChangedBlock = { record in
            let ckRecord:CKRecord = record as CKRecord
            insertedOrUpdatedCKRecords.append(ckRecord)
        }
        fetchRecordChangesOperation.recordWithIDWasDeletedBlock = { recordID in
            deletedCKRecordIDs.append(recordID as CKRecordID)
        }
        self.operationQueue!.addOperation(fetchRecordChangesOperation)
        self.operationQueue!.waitUntilAllOperationsAreFinished()
        if syncOperationError == nil {
            
            if !insertedOrUpdatedCKRecords.isEmpty {
                let recordIDs: [CKRecordID] = insertedOrUpdatedCKRecords.map { record in
                    return record.recordID
                }
                var recordTypes: Set<String> = Set<String>()
                for record in insertedOrUpdatedCKRecords {
                    recordTypes.insert(record.recordType)
                }
                var desiredKeys: [String]?
                for recordType in recordTypes {
                    if desiredKeys == nil {
                        desiredKeys = [String]()
                    }
                    let entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[recordType]
                    if entity != nil {
                        let properties = Array(entity!.propertiesByName.keys).filter {  key in
                            if key == SMStore.SMLocalStoreRecordIDAttributeName || key == SMStore.SMLocalStoreRecordEncodedValuesAttributeName {
                                return false
                            }
                            return true
                        }
                        desiredKeys!.append(contentsOf: properties)
                    }
                }
                insertedOrUpdatedCKRecords.removeAll()
                let fetchRecordsOperation: CKFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
                fetchRecordsOperation.desiredKeys = desiredKeys
                fetchRecordsOperation.database = self.database
                fetchRecordsOperation.fetchRecordsCompletionBlock =  { recordsByRecordID,operationError in
                    if operationError == nil && recordsByRecordID != nil {
                        insertedOrUpdatedCKRecords = Array(recordsByRecordID!.values)
                    }
                }
                self.operationQueue.addOperation(fetchRecordsOperation)
                self.operationQueue.waitUntilAllOperationsAreFinished()
            }
            if fetchRecordChangesOperation.moreComing {
                print("More records coming", terminator: "\n")
            } else {
                print("No more records coming", terminator: "\n")
            }
            moreComing = fetchRecordChangesOperation.moreComing
        }
        return (insertedOrUpdatedCKRecords,deletedCKRecordIDs,moreComing)
    }
    
    func insertOrUpdateManagedObjects(fromCKRecords ckRecords:Array<CKRecord>, retryCount: Int = 0) throws {
        var deferredRecords = [CKRecord]()
        for record in ckRecords {
            var success = false
            do {
                let _ = try record.createOrUpdateManagedObjectFromRecord(usingContext: self.localStoreMOC!)
                success = true
            } catch SMStoreError.missingRelatedObject {
                deferredRecords.append(record)
            }
            if success {
                try self.localStoreMOC.saveIfHasChanges()
            }
        }
        
        if !deferredRecords.isEmpty {
            
            if retryCount < self.RETRYLIMIT  {
                try self.insertOrUpdateManagedObjects(fromCKRecords: deferredRecords, retryCount:retryCount+1)
            } else {
                throw SMSyncOperationError.missingReferences(referringRcords: deferredRecords)
            }
        }
    }
    
    func deleteManagedObjects(fromCKRecordIDs ckRecordIDs:Array<CKRecordID>) throws {
        if !ckRecordIDs.isEmpty {
            let predicate = NSPredicate(format: "%K IN $ckRecordIDs",SMStore.SMLocalStoreRecordIDAttributeName)
            let ckRecordIDStrings = ckRecordIDs.map({(object)->String in
                let ckRecordID:CKRecordID = object
                return ckRecordID.recordName
            })
            let entityNames = self.entities.map { (entity) in
                return entity.name!
            }
            for name in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name as String)
                fetchRequest.predicate = predicate.withSubstitutionVariables(["ckRecordIDs":ckRecordIDStrings])
                let results = try self.localStoreMOC.fetch(fetchRequest)
                if !results.isEmpty {
                    for object in results as! [NSManagedObject] {
                        self.localStoreMOC.delete(object)
                    }
                }
            }
        }
        try self.localStoreMOC.saveIfHasChanges()
    }
}
