//    Zone.swift
//
//    The MIT License (MIT)
//
//    Copyright (c) 2015 Nofel Mahmood ( https://twitter.com/NofelMahmood )
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

class Zone {
  var zone: CKRecordZone!
  var subscription: CKSubscription!
  
  init() {
    let uniqueID = NSUUID().uuidString
    let zoneName = "Seam_Zone_" + uniqueID
    zone = CKRecordZone(zoneName: zoneName)
    let subscriptionName = zone.zoneID.zoneName + "Subscription"
    subscription = CKRecordZoneSubscription(zoneID: zone.zoneID)
    subscription = CKRecordZoneSubscription(zoneID: zone.zoneID, subscriptionID: subscriptionName)
    let subscriptionNotificationInfo = CKNotificationInfo()
    subscriptionNotificationInfo.alertBody = ""
    subscriptionNotificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = subscriptionNotificationInfo
    subscriptionNotificationInfo.shouldBadge = false
  }
  
  init(zoneName: String) {
    zone = CKRecordZone(zoneName: zoneName)
    let subscriptionName = zone.zoneID.zoneName + "Subscription"
    subscription = CKRecordZoneSubscription(zoneID: zone.zoneID, subscriptionID: subscriptionName)
    let subscriptionNotificationInfo = CKNotificationInfo()
    subscriptionNotificationInfo.alertBody = ""
    subscriptionNotificationInfo.shouldSendContentAvailable = true
    subscription.notificationInfo = subscriptionNotificationInfo
    subscriptionNotificationInfo.shouldBadge = false
  }
  
  // MARK: Error

  static let errorDomain = "com.seam.zone.error"
  enum ZoneError: Error {
    case ZoneCreationFailed
    case ZoneSubscriptionCreationFailed
  }
  
  // MARK: Methods

    func zoneExistsOnServer(resultBlock: @escaping (_ result: Bool) -> ()) {
    let fetchRecordZonesOperation = CKFetchRecordZonesOperation(recordZoneIDs: [zone.zoneID])
    fetchRecordZonesOperation.fetchRecordZonesCompletionBlock = { (recordZonesByID, error) in
      let successful = error == nil && recordZonesByID != nil && recordZonesByID![self.zone.zoneID] != nil
        resultBlock(successful)
    }
      OperationQueue().addOperation(fetchRecordZonesOperation)
  }
  
  func subscriptionExistsOnServer(resultBlock: @escaping (_ result: Bool) -> ()) {
    let fetchZoneSubscriptionsOperation = CKFetchSubscriptionsOperation(subscriptionIDs: [subscription.subscriptionID])
    fetchZoneSubscriptionsOperation.fetchSubscriptionCompletionBlock = { (subscriptionsByID, error) in
      let successful = error == nil && subscriptionsByID != nil && subscriptionsByID![self.subscription.subscriptionID] != nil
      resultBlock(successful)
    }
  }
  
  func createZone() throws {
    var error: Error?
    let operationQueue = OperationQueue()
    let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
    modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = { (_,_,operationError) in
      error = operationError
    }
    operationQueue.addOperation(modifyRecordZonesOperation)
    operationQueue.waitUntilAllOperationsAreFinished()
    guard error == nil else {
      throw ZoneError.ZoneCreationFailed
    }
  }
  
  func createSubscription() throws {
    var error: Error?
    let operationQueue = OperationQueue()
    let modifyZoneSubscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
    modifyZoneSubscriptionsOperation.modifySubscriptionsCompletionBlock = { (_,_,operationError) in
      error = operationError
    }
    operationQueue.addOperation(modifyZoneSubscriptionsOperation)
    operationQueue.waitUntilAllOperationsAreFinished()
    guard error == nil else {
      throw ZoneError.ZoneSubscriptionCreationFailed
    }
  }
  
  func createSubscription(completionBlock: ((_ successful: Bool) -> ())?) {
    let fetchZoneSubscriptions = CKFetchSubscriptionsOperation(subscriptionIDs: [subscription.subscriptionID])
    fetchZoneSubscriptions.fetchSubscriptionCompletionBlock = { (subscriptionsByID, error) in
      guard let _ = subscriptionsByID, error == nil else {
        completionBlock?(false)
        return
      }
    }
    let modifyZoneSubscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
    modifyZoneSubscriptionsOperation.modifySubscriptionsCompletionBlock = { (_,_,operationError) in
      if operationError != nil {
        completionBlock?(false)
      } else {
        completionBlock?(true)
      }
    }
    OperationQueue().addOperation(modifyZoneSubscriptionsOperation)
  }
}
