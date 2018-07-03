//
//  DataManager.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 30/06/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import <unistd.h> // For usleep() only

#import "DataManager.h"

#import "AppDelegate.h"
#import "ErrorPresenter.h"

@interface DataManager ()

// Legacy iCloud Core Data connections (now read-only)
//
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContextRemote;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinatorRemote;
@property ( readonly, strong, nonatomic ) NSFetchedResultsController   * fetchedResultsControllerRemote;

// An application-wide cache of bus stop locations for the map view.
// This is updated or cleared and refreshed via StopMapViewController,
// but retained by the AppDelegate so that any number of new instances
// of the map view's controller will be able to reuse the same data.
//
@property ( strong ) NSMutableDictionary * cachedStopLocations;

// Queue with a big nested block full of a series of complex actions we
// undertake every time iCloud availability alters in some way, or at
// application startup. Can be cancelled and restarted at any time.
//
@property ( strong ) NSOperationQueue * dataStoreAwakeningQueue;

- ( NSURL * ) applicationDocumentsDirectory;

@end

@implementation DataManager

#pragma mark - Initialisation

@synthesize managedObjectModel               = _managedObjectModel;

@synthesize managedObjectContextLocal        = _managedObjectContextLocal;
@synthesize persistentStoreCoordinatorLocal  = _persistentStoreCoordinatorLocal;
@synthesize fetchedResultsControllerLocal    = _fetchedResultsControllerLocal;

@synthesize managedObjectContextRemote       = _managedObjectContextRemote;
@synthesize persistentStoreCoordinatorRemote = _persistentStoreCoordinatorRemote;
@synthesize fetchedResultsControllerRemote   = _fetchedResultsControllerRemote;

+ ( DataManager * ) dataManager
{
    static DataManager     * singleton = nil;
    static dispatch_once_t   onceToken;

    dispatch_once
    (
        &onceToken,
        ^{ singleton = [ [ self alloc ] init ]; }
    );

    return singleton;
}

- ( DataManager * ) init
{
    if ( self = [ super init ] )
    {
        [ self clearCachedStops ]; // Initialises the cache
    }

    return self;
}

// Cornerstone method which wakes up all the iCloud stuff - CloudKit, legacy
// data and so forth. Sets up notifications (re-sets them up if need be!) and
// establishes (or, again, re-establishes) custom CloudKit zones and change
// subscriptions, syncs everything up and tries to ensure the UI ends up in a
// consistent state locally relative to remote data.
//
// Called internally by the iCloud availability change notification handliner
// as well as by the app delegate at startup.
//
- ( void ) awakenAllStores
{
    NSUserDefaults * defaults = [ NSUserDefaults standardUserDefaults ];

    // The "old school" NSUbiquityIdentityDidChangeNotification event will
    // tell us if the user signs in/out and lets us know the high level account
    // status changes. CloudKit introduces more fine-grained levels such as
    // 'restricted', but all we care about is signed in or out, or if the user
    // changes. The signed in user is easily detected by the ubiquity token, so
    // we keep using the old token change mechanism here.
    //
    [
        [ NSNotificationCenter defaultCenter ] addObserver: self
                                                  selector: @selector( iCloudIdentityDidChange: )
                                                      name: CKAccountChangedNotification// NSUbiquityIdentityDidChangeNotification
                                                    object: nil
    ];

    // The handler above flushes out a bunch of settings and calls back here if
    // it needs to re-run the at-startup-like checks on old Core Data migration
    // and so forth. That's why we have an operation queue tracking the whole
    // set of calls below and frequent cancellation checks; we may need to
    // interrupt and restart this at any time.
    //
    if ( _dataStoreAwakeningQueue == nil )
    {
        _dataStoreAwakeningQueue = [ [ NSOperationQueue alloc ] init ];
    }

    [ _dataStoreAwakeningQueue cancelAllOperations ];

    // Need to define the block operation object up here, so that inside the
    // block we can reference this and check if "we" have been cancelled.
    //
    NSBlockOperation * awakenOperation = [ [ NSBlockOperation alloc ] init ];
    __weak NSBlockOperation * thisOperation = awakenOperation;

    // Define the one and only block that we'll pass to an NSBlockOperation
    // instance and then place on the queue at the very end of this method.
    //
    id awakenOperationBlock = ^ ( void )
    {
        [
            [ CKContainer defaultContainer ] accountStatusWithCompletionHandler: ^ ( CKAccountStatus accountStatus, NSError * error )
            {
                if ( thisOperation.cancelled ) return;

                if ( accountStatus == CKAccountStatusNoAccount )
                {
                    NSLog( @"-- !! Not signed in to iCloud" );

                    if ( [ defaults boolForKey: HAVE_SHOWN_ICLOUD_SIGNIN_WARNING ] != YES )
                    {
                        [ defaults setBool: YES forKey: HAVE_SHOWN_ICLOUD_SIGNIN_WARNING ];

                        if ( thisOperation.cancelled ) return;

                        [ self showMessage: @"Sign in to iCloud to synchronise favourites between devices.\n\nOtherwise, Bus Panda can still save favourites but only on this device."
                                 withTitle: @"Not signed in to iCloud"
                                 andButton: @"Got it!" ];
                    }
                }
                else if ( accountStatus != CKAccountStatusAvailable )
                {
                    NSLog( @"-- !! Unusual iCloud account status %ld", accountStatus );

                    if ( thisOperation.cancelled ) return;

                    [ self showMessage: @"iCloud is not available, either due to parental controls or an error. Bus Panda will not be able to synchronise favourite stops with your other devices."
                             withTitle: @"Cannot use iCloud"
                             andButton: @"Got it!" ];
                }
                else
                {
                    NSLog(@"-- !! CloudKit is ready");

                    CKContainer                  * container     = [ CKContainer defaultContainer ];
                    CKDatabase                   * database      = [ container privateCloudDatabase ];
                    CKRecordZone                 * zone          = [ [ CKRecordZone alloc ] initWithZoneName: CLOUDKIT_ZONE_NAME ];
                    CKModifyRecordZonesOperation * zoneOperation =
                    [
                        [ CKModifyRecordZonesOperation alloc ] initWithRecordZonesToSave: @[ zone ]
                                                                   recordZoneIDsToDelete: nil
                    ];

                    zoneOperation.qualityOfService                 = NSQualityOfServiceUtility;
                    zoneOperation.modifyRecordZonesCompletionBlock =
                    ^ (
                        NSArray<CKRecordZone   *> * _Nullable savedRecordZones,
                        NSArray<CKRecordZoneID *> * _Nullable deletedRecordZoneIDs,
                        NSError                   * _Nullable operationError
                    )
                    {
                        if ( error != nil )
                        {
                            NSLog( @"On-startup: FATAL: Could not create zone: %@", error );
                        }
                        else
                        {
                            // Now set up the operation which fetches all changes
                            // for our first-time startup. This has a special
                            // action for on-completion, because if it finds that
                            // there were no changes in Cloud Kit, it'll go and
                            // check the legacy Core Data store for information.

                            id completionBlock = ^ ( NSError * _Nullable error )
                            {
                                if ( thisOperation.cancelled ) return;

                                // If no error & we had something from CloudKit, we're done as
                                // if anything is in there at all, it's considered data master.
                                //
                                // If no error & user defaults say "nothing from CloudKit yet"
                                // and user defaults say "I haven't migrated from old Core Data"
                                // then this is assumed first app run on any device post-CloudKit
                                // for this user. Pull old core data records.

                                NSLog( @"On-startup: Fetch changes complete: %@", error );

                                BOOL hasReceivedUpdatesBefore = [ defaults boolForKey: HAVE_RECEIVED_CLOUDKIT_DATA  ];
                                BOOL haveReadLegacyICloudData = [ defaults boolForKey: HAVE_READ_LEGACY_ICLOUD_DATA ];

                                if ( hasReceivedUpdatesBefore != YES && haveReadLegacyICloudData != YES )
                                {
                                    // This one-liner kicks off all the old iCloud Core Data
                                    // persistent storage stuff, leading in due course to
                                    // various notifications (if things work!) about stores
                                    // changing & becoming available. This leads to all old
                                    // data from there being pulled down and re-stored in
                                    // the new local storage with CloudKit sync.

                                    if ( thisOperation.cancelled ) return;
                                    [ self managedObjectContextRemote ];
                                }
                            };

                            if ( thisOperation.cancelled ) return;

                            [ self fetchRecentChangesWithCompletionBlock: completionBlock
                                                ignoringPriorChangeToken: YES ];

                            // With that underway, we can set up our subscription to
                            // CloudKit changes, to react at run-time.

                            NSPredicate         * predicate    = [ NSPredicate predicateWithValue: YES ];
                            CKQuerySubscription * subscription = [
                                [ CKQuerySubscription alloc ] initWithRecordType: ENTITY_AND_RECORD_NAME
                                                                       predicate: predicate
                                                                  subscriptionID: CLOUDKIT_SUBSCRIPTION_ID
                                                                         options: CKQuerySubscriptionOptionsFiresOnRecordCreation |
                                                                                  CKQuerySubscriptionOptionsFiresOnRecordUpdate   |
                                                                                  CKQuerySubscriptionOptionsFiresOnRecordDeletion
                            ];

                            CKNotificationInfo * info = [ [ CKNotificationInfo alloc ] init ];

                            info.shouldSendContentAvailable = true; // "Silent" notification
                            subscription.notificationInfo   = info;

                            CKModifySubscriptionsOperation * subscriptionsOperation = [
                                [ CKModifySubscriptionsOperation alloc ] initWithSubscriptionsToSave: @[ subscription ]
                                                                             subscriptionIDsToDelete: nil
                            ];

                            subscriptionsOperation.qualityOfService = NSQualityOfServiceUtility;

                            if ( thisOperation.cancelled ) return;
                            [ database addOperation: subscriptionsOperation ];
                        }
                    };

                    if ( thisOperation.cancelled ) return;
                    [ database addOperation: zoneOperation ];
                }
            }
        ];
    };

    // As per comments far above :-) now finally add the big block we just
    // defined as a (cancelleable) operation that'll get run when iOS is ready.
    //
    [ awakenOperation addExecutionBlock: awakenOperationBlock ];
    [ _dataStoreAwakeningQueue addOperation: awakenOperation ];
}

#pragma mark - Support utilities

// The directory the application uses to store the Core Data store file. This
// code uses a directory named "uk.org.pond.Bus-Panda" in the application's
// documents directory.
//
- ( NSURL * ) applicationDocumentsDirectory
{
    return [ [ [ NSFileManager defaultManager ] URLsForDirectory: NSDocumentDirectory
                                                       inDomains: NSUserDomainMask ] lastObject ];
}

// Send a notification saying that the iCloud data has changed. A listener is
// set up in MasterViewController.m. The notification is sent via GCD on a
// separate thread, which seems to make reception of it more reliable (!).
//
- ( void ) sendDataHasChangedNotification
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ ( void )
        {
            [ [ NSNotificationCenter defaultCenter ] postNotificationName: DATA_CHANGED_NOTIFICATION_NAME
                                                                   object: self
                                                                 userInfo: nil ];
        }
    );
}

// iCloud availability has changed - available <-> not available, or another
// user has signed in.
//
// We have to treat this pretty much as if the app has been installed from
// clean - flush everything and redo the whole Core Data and CloudKit iCloud
// dance.
//
- ( void ) iCloudIdentityDidChange: ( NSNotification * ) notification
{
    ( void ) notification;

    NSLog( @"iCloud identity has changed" );

    NSUserDefaults * defaults           = [ NSUserDefaults standardUserDefaults ];
    NSFileManager  * fileManager        = [ NSFileManager defaultManager ];
    id               currentiCloudToken = fileManager.ubiquityIdentityToken;

    if ( currentiCloudToken )
    {
        // The iCloud token may have changed. Read whatever old value was
        // stored ("nil" if not). If there's a change, record the new value
        // and send the 'data changed' notification. If there's no change in
        // the token, do nothing.

        id oldiCloudToken = [ defaults objectForKey: ICLOUD_TOKEN_ID_DEFAULTS_KEY ];

        if ( [ currentiCloudToken isEqual: oldiCloudToken ] == NO )
        {
            NSData * currentTokenData =
            [
                NSKeyedArchiver archivedDataWithRootObject: currentiCloudToken
            ];

            [ defaults setObject: currentTokenData
                          forKey: ICLOUD_TOKEN_ID_DEFAULTS_KEY ];

            // Since the user may have changed, we have to flush all of the
            // local data and resync from scratch.
            //
            [ defaults setBool: NO forKey: HAVE_RECEIVED_CLOUDKIT_DATA  ];
            [ defaults setBool: NO forKey: HAVE_READ_LEGACY_ICLOUD_DATA ];

            NSError * error   = nil;
            BOOL      success = [ self.fetchedResultsControllerLocal performFetch: &error ];

            if ( success != YES || error != nil )
            {
                NSLog( @"iCloud identity has changed: Cannot read local data, halting here - %@", error );
            }
            else
            {
                NSArray * results = self.fetchedResultsControllerLocal.fetchedObjects;

                NSLog( @"iCloud identity has changed: Purging all local data" );

                for ( NSManagedObject * object in results )
                {
                    NSString * stopID = [ object valueForKey: @"stopID" ];
                    [ self deleteFavourite: stopID includingCloudKit: NO ];
                }

                // Now we need to re-awaken everything to make sure we try and
                // resync to CloudKit and/or legacy iCloud Core Data stores.
                //
                [ self awakenAllStores ];
            }
        }
    }
    else
    {
        // iCloud seems to no longer be available. Remove any stored iCloud
        // token but leave things otherwise as they are; the local data is
        // still available, we just can't sync it to CloudKit now.
        //
        [ defaults removeObjectForKey: ICLOUD_TOKEN_ID_DEFAULTS_KEY ];
    }

    NSLog( @"iCloud ubiquity token now: %@", currentiCloudToken );
}

// Utility method - call with a pointer to an NSError instance, which may be
// "nil", and a pointer to a title NSString shown in the error report if the
// NSError pointer is not "nil".
//
// Ensures that the error dialogue is shown on the main thread, so can be
// called from other threads safely.
//
- ( void ) handleError: ( NSError  * ) error
             withTitle: ( NSString * ) title
{
    if ( error )
    {
        [ self showMessage: [ error localizedDescription ]
                 withTitle: title
                 andButton: @"OK" ];
    }
}

// Back-end to -handleError:withTitle:, or for generalised message display;
// pass in the message string to show, title text and button text.
//
- ( void ) showMessage: ( NSString * ) message
             withTitle: ( NSString * ) title
             andButton: ( NSString * ) button
{
    AppDelegate          * delegate  = ( AppDelegate * ) [ [ UIApplication sharedApplication ] delegate ];
    MasterViewController * presenter = [ delegate masterViewController ];

    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ {
            [ ErrorPresenter showModalPopupFor: presenter
                                   withMessage: message
                                         title: title
                                        button: button
                                    andHandler: ^( UIAlertAction *action ) {} ];
        }
    );
}

#pragma mark - Core data, local storage

// The managed object model for the application. It is a fatal error for the
// application not to be able to find and load its model.
//
- ( NSManagedObjectModel * ) managedObjectModel
{
    if ( _managedObjectModel != nil )
    {
        return _managedObjectModel;
    }

    NSURL * modelURL = [ [ NSBundle mainBundle ] URLForResource: @"Bus-Panda" withExtension: @"momd" ];

    _managedObjectModel = [ [ NSManagedObjectModel alloc ] initWithContentsOfURL: modelURL ];
    return _managedObjectModel;
}

// Local storage only for Core Data.
//
- ( NSPersistentStoreCoordinator * ) persistentStoreCoordinatorLocal
{
    if ( _persistentStoreCoordinatorLocal != nil )
    {
        return _persistentStoreCoordinatorLocal;
    }

    _persistentStoreCoordinatorLocal = [
        [ NSPersistentStoreCoordinator alloc ]
        initWithManagedObjectModel: [ self managedObjectModel ]
    ];

    NSPersistentStoreCoordinator * psc        = _persistentStoreCoordinatorLocal;
    NSURL                        * localStore =
    [
        [ self applicationDocumentsDirectory ] URLByAppendingPathComponent: NEW_CORE_DATA_FILE_NAME
    ];

    NSLog( @"Core Data: Using a local store for %@", _persistentStoreCoordinatorLocal );
    NSLog( @"localStore URL = %@", localStore );

    NSDictionary * options =
    @{
        NSMigratePersistentStoresAutomaticallyOption: @YES,
        NSInferMappingModelAutomaticallyOption:       @YES
    };

    [
        psc performBlockAndWait: ^ ( void )
        {
            [ psc addPersistentStoreWithType: NSSQLiteStoreType
                               configuration: nil
                                         URL: localStore
                                     options: options
                                       error: nil ];
        }
    ];

    return _persistentStoreCoordinatorLocal;
}

// Return an NSManagedObjectContext instance for local Core Data storage.
//
- ( NSManagedObjectContext * ) managedObjectContextLocal
{
    if ( _managedObjectContextLocal != nil )
    {
        return _managedObjectContextLocal;
    }

    NSPersistentStoreCoordinator * psc = [ self persistentStoreCoordinatorLocal ];

    if ( psc != nil )
    {
        NSManagedObjectContext * moc = [ [ NSManagedObjectContext alloc ] initWithConcurrencyType: NSMainQueueConcurrencyType ];

        [
            moc performBlockAndWait: ^ ( void )
            {
                [ moc setPersistentStoreCoordinator: psc ];
            }
        ];

        _managedObjectContextLocal = moc;
    }

    return _managedObjectContextLocal;
}

#pragma mark - Core data, legacy iCloud storage

// Remote storage only for Core Data:
//
//   http://timroadley.com/2012/04/03/core-data-in-icloud/
//
// On first call, the new store coordinator is configured to completely replace
// any current local cache of data it might have. On subsequent calls, the same
// already-built instance is returned.
//
// You'll need stores-will-change / stores-have-changed notification handlers
// set up to know when to actually try and read data using this coordinator.
// Typically, you don't call here directly; call -managedObjectContextRemote
// instead, which does all that for you.
//
// You MUST NOT CALL THIS FROM THE MAIN THREAD. It has intentionally got
// blocking semantics and must be called, directly or indirectly, only from
// some other context, because:
//
//   "In iOS, apps that use document storage must call the
//    URLForUbiquityContainerIdentifier: method of the NSFileManager method
//    for each supported iCloud container. Always call the
//    URLForUbiquityContainerIdentifier: method from a background thread -
//    not from your app’s main thread. This method depends on local and remote
//    services and, for this reason, does not always return immediately"
//
// https://developer.apple.com/library/ios/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html#//apple_ref/doc/uid/TP40012094-CH6-SW1
//
// If you call here when iCloud is *not* working, then no data source will
// ever get added.
//
- ( NSPersistentStoreCoordinator * ) persistentStoreCoordinatorRemote
{
    if ( _persistentStoreCoordinatorRemote != nil )
    {
        return _persistentStoreCoordinatorRemote;
    }

    _persistentStoreCoordinatorRemote = [
        [ NSPersistentStoreCoordinator alloc ]
        initWithManagedObjectModel: [ self managedObjectModel ]
    ];

    NSPersistentStoreCoordinator * psc = _persistentStoreCoordinatorRemote;

    // "nil" for container identifier => choose the first from the entitlements
    // file's com.apple.developer.ubiquity-container-identifiers array. That's
    // nice as it avoids duplicating info there and here.
    //
    NSFileManager * fileManager = [ NSFileManager defaultManager ];
    NSURL         * iCloud      = [ fileManager URLForUbiquityContainerIdentifier: nil ];

    if ( iCloud )
    {
        NSURL * iCloudDataURL =
        [
            [ self applicationDocumentsDirectory ] URLByAppendingPathComponent: OLD_CORE_DATA_FILE_NAME
        ];

        NSLog( @"iCloud is working: %@",  iCloud                );
        NSLog( @"iCloudEnabledAppID: %@", ICLOUD_ENABLED_APP_ID );
        NSLog( @"iCloudDataURL: %@",      iCloudDataURL         );

// https://stackoverflow.com/questions/2622017/suppressing-deprecated-warnings-in-xcode
//
// We need the old iCloud stuff for people migrating from Bus Panda V1 but
// don't want the unnecessary build noise of deprecation warnings.
//
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        NSDictionary * options =
        @{
            NSMigratePersistentStoresAutomaticallyOption:        @YES,
            NSInferMappingModelAutomaticallyOption:              @YES,
            NSPersistentStoreUbiquitousContentNameKey:           ICLOUD_ENABLED_APP_ID,
            NSPersistentStoreRebuildFromUbiquitousContentOption: @YES
        };

#pragma clang diagnostic pop

        [
            psc performBlockAndWait: ^ ( void )
            {
                [ psc addPersistentStoreWithType: NSSQLiteStoreType
                                   configuration: nil
                                             URL: iCloudDataURL
                                         options: options
                                           error: nil ];
            }
        ];
    }
    else
    {
        NSLog( @"iCloud is NOT working - cannot use a remote PSC!" );
    }

    return _persistentStoreCoordinatorRemote;
}

// Return an NSManagedObjectContext instance for iCloud Core Data storage:
//
//   http://timroadley.com/2012/04/03/core-data-in-icloud/
//
// You MUST NOT CALL THIS FROM THE MAIN THREAD. It has intentionally got
// blocking semantics and must be called, directly or indirectly, only from
// some other context.
//
- ( NSManagedObjectContext * ) managedObjectContextRemote
{
    if ( _managedObjectContextRemote != nil )
    {
        return _managedObjectContextRemote;
    }

    NSPersistentStoreCoordinator * psc = [ self persistentStoreCoordinatorRemote ];

    if ( psc != nil )
    {
        NSManagedObjectContext * moc = [ [ NSManagedObjectContext alloc ] initWithConcurrencyType: NSMainQueueConcurrencyType ];

        [
            moc performBlockAndWait: ^ ( void )
            {
                [ moc setPersistentStoreCoordinator: psc ];

                [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                            selector: @selector( storesWillChange: )
                                                                name: NSPersistentStoreCoordinatorStoresWillChangeNotification
                                                              object: psc ];

                [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                            selector: @selector( storesDidChange: )
                                                                name: NSPersistentStoreCoordinatorStoresDidChangeNotification
                                                              object: psc ];
            }
        ];

        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

        _managedObjectContextRemote = moc;
    }

    return _managedObjectContextRemote;
}

- ( void ) storesWillChange: ( NSNotification * ) notification
{
    NSLog( @"**** Stores will change..." );

    // No need to disable the GUI here, because it uses the local Core Data
    // store only with a different SQLite database file. This legacy code is
    // only here so we can pull down any old iCloud-hosted Core Data records
    // in full on first-run-of-new-version.

    NSManagedObjectContext * moc = self.managedObjectContextRemote;

    [
        moc performBlock: ^
        {
            [ moc reset ];
        }
    ];
}

- ( void ) storesDidChange: ( NSNotification * ) notification
{
    NSLog( @"**** Stores did change..." );

    [
        self.managedObjectContextRemote performBlockAndWait: ^ ( void )
        {
            NSArray * results = [ self getLegacyFavouritesFromICloud ];

            for ( NSManagedObject * object in results )
            {
                NSNumber * preferred       = [ object valueForKey: @"preferred"       ];
                NSString * stopID          = [ object valueForKey: @"stopID"          ];
                NSString * stopDescription = [ object valueForKey: @"stopDescription" ];

                NSLog(@"Legacy iCloud Core Data result: %@ (%@): %@", stopID, preferred, stopDescription);

                [ self addOrEditFavourite: stopID
                       settingDescription: stopDescription
                         andPreferredFlag: preferred
                        includingCloudKit: YES ];
            }
        }
    ];
}

#pragma mark - Core Data saving support

- ( void ) saveContext
{
    NSManagedObjectContext * managedObjectContext = self.managedObjectContextLocal;

    [
        managedObjectContext performBlockAndWait: ^
        {
            NSError * error = nil;

            if ( [ managedObjectContext hasChanges ] && ![ managedObjectContext save: &error ] )
            {
                // This is called from -applicationWillTerminate, so there is
                // really nothing much we can do here other than log the fault.
                //
                NSLog( @"Unresolved error %@, %@", error, [ error userInfo ] );
            }
        }
    ];
}

#pragma mark - Adding and modifying favourites

// Utility method - save the given CloudKit record into the given CloudKit
// database, reporting an error to the user if it fails but taking no other
// remedial action. The third parameter is the title string to use if there
// is an error to report.
//
- ( void ) saveRecord: ( CKRecord   * ) record
           inDatabase: ( CKDatabase * ) database
         onErrorTitle: ( NSString   * ) errorTitle
{
    [
        database saveRecord: record
          completionHandler: ^ ( CKRecord * _Nullable record, NSError * _Nullable error )
        {
            [ self handleError: error withTitle: errorTitle ];
        }
    ];
}

// Create-or-update a favourite stop. Pass the stop ID. If an existing record
// is found, it'll be updated with the given stop description and preferred
// flag; else a new record will be created. Pass 'nil' for stopDescription if
// you want to preserve an existing value; default is to match stopID string
// for new records. Similarly, pass 'nil' for preferred flag if you want to
// preserve that; default is 'not preferred' for new records.
//
// Modifies the local table view first, then will, if the final parameter is
// YES, also push changes out to CloudKit; else it won't.
//
- ( void ) addOrEditFavourite: ( NSString * ) stopID
           settingDescription: ( NSString * ) stopDescription
             andPreferredFlag: ( NSNumber * ) preferred
            includingCloudKit: ( BOOL       ) includeCloudKit
{
    // First update local records.

    NSLog(@"ADD OR EDIT FAVOURITE");
    NSLog(@"StopID %@",          stopID);
    NSLog(@"stopDescription %@", stopDescription);
    NSLog(@"preferred %@",       preferred);

    if ( stopID == nil ) return; // Indicates nasty bug, but try not to just crash...

    BOOL                     oldShowSectionFlag = self.shouldShowSectionHeader;
    NSNumber               * oldPreferred       = @( ! preferred.boolValue );
    NSManagedObject        * object             = [ DataManager.dataManager findFavouriteStopByID: stopID ];
    NSManagedObjectContext * context            = self.managedObjectContextLocal;
    NSError                * error              = nil;

    if ( object == nil )
    {
        object =
        [
            NSEntityDescription insertNewObjectForEntityForName: ENTITY_AND_RECORD_NAME
                                         inManagedObjectContext: context
        ];

        [ object setValue: stopID forKey: @"stopID" ];

        if ( stopDescription == nil ) stopDescription = [ stopID copy ];
        if ( preferred       == nil ) preferred       = STOP_IS_NOT_PREFERRED_VALUE;
    }
    else
    {
        oldPreferred = [ object valueForKey: @"preferred" ];
    }

    if ( stopDescription != nil ) [ object setValue: stopDescription forKey: @"stopDescription" ];
    if ( preferred       != nil ) [ object setValue: preferred       forKey: @"preferred"       ];

    if ( ! [ context save: &error ] )
    {
        [ self handleError: error
                 withTitle: NSLocalizedString( @"Could not change 'preferred' stop setting", "Error message shown when changing the 'preferred' setting fails" ) ];

        return;
    }

    // Avoid animation issues if the section headers appear or dispppear by
    // sending a 'data changed' notification that causes a full reload and
    // table redraw.
    //
    BOOL newShowSectionFlag = self.shouldShowSectionHeader;
    if ( oldShowSectionFlag != newShowSectionFlag ) [ self sendDataHasChangedNotification ];

    if ( preferred.boolValue != oldPreferred.boolValue )
    {
        // If there's no section header than (A) is there only one favourite
        // stop, (B) is that stop now preferred and (C) have we detected this
        // condition before? If not, tell the user what's going on.
        //
        NSUserDefaults * defaults = [ NSUserDefaults standardUserDefaults ];

        if (
               newShowSectionFlag == NO &&
               self.fetchedResultsControllerLocal.fetchedObjects.count == 1 &&
               [ [ self.fetchedResultsControllerLocal.fetchedObjects[ 0 ] valueForKey: @"preferred" ] isEqual: STOP_IS_PREFERRED_VALUE ] &&
               [ defaults boolForKey: @"haveShownSingleSectionWarning" ] != YES
           )
        {
            [ defaults setBool: YES forKey: @"haveShownSingleSectionWarning" ];

            [ self showMessage: @"When you have a mixture of preferred and normal stops, they show up in different sections.\n\nOtherwise, you only see one list."
                     withTitle: @"You have only one preferred and favourite stop"
                     andButton: @"Got it!" ];
        }
    }

    // Now update iCloud?
    //
    if ( includeCloudKit == NO ) return;

    CKContainer    * container  = [ CKContainer defaultContainer ];
    CKDatabase     * database   = [ container privateCloudDatabase ];
    CKRecordZoneID * zoneID     = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_NAME ownerName: CKCurrentUserDefaultName ];
    CKRecordID     * recordID   = [ [ CKRecordID alloc ] initWithRecordName: stopID zoneID: zoneID ];
    NSString       * errorTitle = NSLocalizedString(
        @"Could not save changes in iCloud",
        @"Error message shown when trying to save favourite stop changes to iCloud"
    );

    [
        database fetchRecordWithID: recordID
                 completionHandler: ^ ( CKRecord * _Nullable record, NSError * _Nullable error )
        {
            if ( record == nil || error.code == CKErrorUnknownItem ) // (If 'error' is nil, dereference of code will be 'nil' and comparison will fail)
            {
                CKRecord * record = [ [ CKRecord alloc ] initWithRecordType: ENTITY_AND_RECORD_NAME
                                                                   recordID: recordID ];

                [ record setObject: stopDescription forKey: @"stopDescription" ];
                [ record setObject: preferred       forKey: @"preferred"       ];

                NSLog(@"NEW RECORD create %@", record);
                [ self saveRecord: record inDatabase: database onErrorTitle: errorTitle ];
            }
            else if ( error != nil )
            {
                NSLog(@"CLOUD KIT ERROR %@", error);
                [ self handleError: error withTitle: errorTitle ];
            }
            else
            {
                if ( stopDescription != nil ) [ record setObject: stopDescription forKey: @"stopDescription" ];
                if ( preferred       != nil ) [ record setObject: preferred       forKey: @"preferred"       ];

                NSLog(@"EXISTING RECORD update %@", record);
                [ self saveRecord: record inDatabase: database onErrorTitle: errorTitle ];
            }
        }
    ];
}

// Modifies the local table view first, then will, if the final parameter is
// YES, also push changes out to CloudKit; else it won't.
//
- ( void ) deleteFavourite: ( NSString * ) stopID
         includingCloudKit: ( BOOL       ) includeCloudKit
{
    NSLog(@"REMOVE FAVOURITE");
    NSLog(@"StopID %@", stopID);

    if ( stopID == nil ) return; // Indicates nasty bug, but try not to just crash...

    NSManagedObject * object = [ DataManager.dataManager findFavouriteStopByID: stopID ];

    // Nothing being found implies strange bugs; can't trust the data; bail out.
    //
    if ( object == nil ) return;

    // First update local records.

    BOOL                     oldShowSectionFlag = self.shouldShowSectionHeader;
    NSManagedObjectContext * context            = self.managedObjectContextLocal;
    NSError                * error              = nil;

    [ context deleteObject: object ];

    if ( ! [ context save: &error ] )
    {
        [ self handleError: error
                 withTitle: NSLocalizedString( @"Could not delete favourite", "Error message shown when favourite stop deletion fails" ) ];
    }

    // Avoid animation issues if the section headers appear or dispppear by
    // sending a 'data changed' notification that causes a full reload and
    // table redraw.
    //
    BOOL newShowSectionFlag = self.shouldShowSectionHeader;
    if ( oldShowSectionFlag != newShowSectionFlag ) [ self sendDataHasChangedNotification ];

    // Now update iCloud?
    //
    if ( includeCloudKit == NO ) return;

    CKContainer    * container  = [ CKContainer defaultContainer ];
    CKDatabase     * database   = [ container privateCloudDatabase ];
    CKRecordZoneID * zoneID     = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_NAME ownerName: CKCurrentUserDefaultName ];
    CKRecordID     * recordID   = [ [ CKRecordID alloc ] initWithRecordName: stopID zoneID: zoneID ];
    NSString       * errorTitle = NSLocalizedString(
        @"Could not remove favourite from in iCloud",
        @"Error message shown when trying to remove favourite stop from iCloud"
    );

    [
        database deleteRecordWithID: recordID
                  completionHandler: ^ ( CKRecordID * _Nullable recordID, NSError * _Nullable error )
        {
            NSLog(@"DELETE RECORD - %@ / error result: %@", recordID, error);
            [ self handleError: error withTitle: errorTitle ];
        }
    ];
}

#pragma mark - Query interfaces

// Returns an existing NSFetchedResultsController instance or generates a new
// one when called for the first time. Reads the local Core Data store only.
//
- ( NSFetchedResultsController * ) fetchedResultsControllerLocal
{
    if ( _fetchedResultsControllerLocal != nil )
    {
        return _fetchedResultsControllerLocal;
    }

    NSFetchRequest      * fetchRequest = [ [ NSFetchRequest alloc] init ];
    NSEntityDescription * entity       = [ NSEntityDescription entityForName: ENTITY_AND_RECORD_NAME
                                                      inManagedObjectContext: self.managedObjectContextLocal ];

    [ fetchRequest setEntity: entity ];

    NSSortDescriptor * sortDescriptor1 = [ [ NSSortDescriptor alloc] initWithKey: @"preferred"
                                                                       ascending: NO ];

    NSSortDescriptor * sortDescriptor2 = [ [ NSSortDescriptor alloc] initWithKey: @"stopDescription"
                                                                       ascending: YES ];

    [ fetchRequest setSortDescriptors: @[ sortDescriptor1, sortDescriptor2 ] ];

    NSFetchedResultsController * frc = [ [ NSFetchedResultsController alloc ] initWithFetchRequest: fetchRequest
                                                                              managedObjectContext: self.managedObjectContextLocal
                                                                                sectionNameKeyPath: @"preferred"
                                                                                         cacheName: nil ];

    // TODO: The delegation of responsibilities into DataManager feels largely
    //       correct, except for a fetched results controller being needed for
    //       the add-or-edit favourites stuff, but such an entity being meant
    //       for use with a table view, and that view is in the Master View
    //       Controller. In practice, the hack of "just knowing" that we must
    //       set the MVC as delegate works, but is nasty.

    AppDelegate * appDelegate = ( AppDelegate * ) [ [ UIApplication sharedApplication ] delegate ];
    frc.delegate = appDelegate.masterViewController;

    // Initial warm-up of local store.
    //
    [ frc performFetch: nil ];

    _fetchedResultsControllerLocal = frc;
    return _fetchedResultsControllerLocal;
}

// Returns an existing NSFetchedResultsController instance or generates a new
// one when called for the first time. Reads the remote legacy iCloud data only.
//
- ( NSFetchedResultsController * ) fetchedResultsControllerRemote
{
    if ( _fetchedResultsControllerRemote != nil )
    {
        return _fetchedResultsControllerRemote;
    }

    NSFetchRequest      * fetchRequest = [ [ NSFetchRequest alloc] init ];
    NSEntityDescription * entity       = [ NSEntityDescription entityForName: ENTITY_AND_RECORD_NAME
                                                      inManagedObjectContext: self.managedObjectContextRemote ];

    [ fetchRequest setEntity: entity ];

    // Fetch requests must include at least one sort descriptor. This is a
    // fairly arbitary choice...
    //
    NSSortDescriptor * sortDescriptor = [ [ NSSortDescriptor alloc] initWithKey: @"stopDescription"
                                                                      ascending: YES ];

    [ fetchRequest setSortDescriptors: @[ sortDescriptor ] ];

    NSFetchedResultsController * frc = [ [ NSFetchedResultsController alloc ] initWithFetchRequest: fetchRequest
                                                                              managedObjectContext: self.managedObjectContextRemote
                                                                                sectionNameKeyPath: @"preferred"
                                                                                         cacheName: nil ];

    _fetchedResultsControllerRemote = frc;
    return _fetchedResultsControllerRemote;
}

// Look up a stop in the local Core Data records by stop ID. Returns the
// NSManagedObject for the found record, or "nil" if not found.
//
- ( NSManagedObject * ) findFavouriteStopByID: ( NSString * ) stopID
{
    NSError                * error       = nil;
    NSManagedObjectContext * moc         = [ self managedObjectContextLocal ];
    NSManagedObjectModel   * mom         = [ self managedObjectModel ];
    NSEntityDescription    * styleEntity = [ mom entitiesByName ][ ENTITY_AND_RECORD_NAME ];
    NSFetchRequest         * request     = [ [ NSFetchRequest alloc ] init ];
    NSPredicate            * predicate   =
    [
        NSPredicate predicateWithFormat: @"(stopID == %@)",
        stopID
    ];

    [ request setEntity:              styleEntity ];
    [ request setIncludesSubentities: NO          ];
    [ request setPredicate:           predicate   ];

    NSArray * results = [ moc executeFetchRequest: request error: &error ];

    if ( error != nil || [ results count ] < 1 )
    {
        return nil;
    }

    return results[ 0 ];
}

// Support method - returns YES if the section header should be shown for a
// table presenting the Core Data store contents, else NO. The idea is to hide
// the section header when only one section is present, because all bus stops
// are either normal or preferred. Things go wrong in that case because we
// don't easily know e.g. the section title and it looks odd to just have a
// one-section table anyway.
//
- ( BOOL ) shouldShowSectionHeader
{
    NSInteger sectionCount = [ self numberOfSections ];
    return ( sectionCount < 2 ) ? NO : YES;
}

// Support method - returns the number of sections in the Core Data store.
//
- ( NSInteger ) numberOfSections
{
    return self.fetchedResultsControllerLocal.sections.count;
}

// Retrieve favourites data, if any, from the legacy iCloud Core Data store.
//
// This is intended really just for one-shot data migrations and is not very
// efficient as it intentionally does not provide any cache name for the
// results, so it'll re-fetch every time.
//
// Returns an empty array if things work but there are no results; a non-empty
// array if things work and there are results; or 'nil' if there was an error.
//
- ( NSArray * ) getLegacyFavouritesFromICloud
{
    NSLog( @"**** getLegacyFavouritesFromICloud" );

    NSError * error   = nil;
    BOOL      success = [ self.fetchedResultsControllerRemote performFetch: &error ];

    // "Returns an empty array if things work but there are no results; a
    //  non-empty array if things work and there are results; or 'nil' if
    //  there was an error."
    //
    if ( success != YES || error != nil )
    {
        NSLog( @"**** getLegacyFavouritesFromICloud: FAILED: %@", error );
        return nil;
    }
    else
    {
        NSArray * results = self.fetchedResultsControllerRemote.fetchedObjects;
        if ( results == nil ) results = @[];

        NSLog(@"**** getLegacyFavouritesFromICloud: Results count: %lu", results.count );

        return results;
    }
}

//// Asynchronous, full CloudKit fetch of all stop data. Call with a completion
//// handler that might give an error, or an NSArray of CKRecords.
////
//// Note that by "all", we mean "assumed less than 'a few hundreds'" since the
//// CloudKit documentation tells us not to use the mechanism employed herein if
//// the result set is likely to be larger than that (it'd only return the first
//// few hundred if so). It seems very unlikely that someone would have more than
//// even 50 or so favourite stops in Bus Panda.
////
//// TODO: Maybe one day turn this into a paginated interface using a
/////      CKQueryOperation instead of using the convenience interface - just
////       in case someone really *does* have that many favourites stored!
////
//// Simple example without any error handling:
////
////     [
////         self fetchAllStopsViaCloudKit: ^ ( NSArray * _Nullable results, NSError * _Nullable error )
////         {
////             NSLog(@"%@", results);
////         }
////     ];
////
//- ( void ) fetchAllStopsViaCloudKit: ( CloudKitQueryCompletionHandler ) completionHandler
//{
//    CKContainer    * container  = [ CKContainer defaultContainer ];
//    CKDatabase     * database   = [ container privateCloudDatabase ];
//    CKRecordZoneID * zoneID     = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_NAME ownerName: CKCurrentUserDefaultName ];
//    NSPredicate    * predicate  = [ NSPredicate predicateWithValue: YES ];
//    CKQuery        * query      =
//    [
//        [ CKQuery alloc ] initWithRecordType: ENTITY_AND_RECORD_NAME
//                                   predicate: predicate
//    ];
//
//    [ database performQuery: query
//               inZoneWithID: zoneID
//          completionHandler: completionHandler ];
//}

#pragma mark - CloudKit change management

// When called, creates a CloudKit operation that fetches recent changes from
// the server. Fetches all possible changes, but will recursively call itself
// if CloudKit indicates that more changes are coming in one of the updates.
// Creates, updates or deletes records as required.
//
// The completion block is passed to the fetchRecordZoneChangesCompletionBlock
// parameter of the operation and called with an error (or not) once the fetch
// operation has finished. I'm not clear on whether this happens in the case of
// a multi-fetch operation (where CloudKit indicates "more to come" during the
// token update within the custom zone); it probably does. It may be 'nil'.
//
// The boolean parameter is "YES" to ignore any local change token and fetch
// from the very start of all data. This also raises the fetch priority from
// Background to Utility on assumption of a full data refresh being performed
// a little more urgently than normal, for the user's benefit.
//
- ( void ) fetchRecentChangesWithCompletionBlock: ( void ( ^ )( NSError * _Nullable error ) ) completionHandler
                        ignoringPriorChangeToken: ( BOOL ) forceFetchAll
{
    NSUserDefaults      * defaults  = [ NSUserDefaults standardUserDefaults ];
    CKContainer         * container = [ CKContainer defaultContainer ];
    CKDatabase          * database  = [ container privateCloudDatabase ];
    CKRecordZoneID      * zoneID    = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_NAME ownerName: CKCurrentUserDefaultName ];
    CKServerChangeToken * token     = nil;

    // Is there a previous change token we can start fetches using?

    if ( forceFetchAll == NO )
    {
        NSData * archivedToken = [ defaults objectForKey: CLOUDKIT_FETCHED_CHANGES_TOKEN ];

        if ( archivedToken != nil )
        {
            token = [ NSKeyedUnarchiver unarchiveObjectWithData: archivedToken ];
        }
    }

    // Fetch changes

    CKFetchRecordZoneChangesOptions * options = [ [ CKFetchRecordZoneChangesOptions alloc ] init ];
    options.previousServerChangeToken = token;

    NSDictionary                      * optionsMap       = @{ zoneID: options };
    CKFetchRecordZoneChangesOperation * changesOperation = [
        [ CKFetchRecordZoneChangesOperation alloc ] initWithRecordZoneIDs: @[ zoneID ]
                                                    optionsByRecordZoneID: optionsMap
    ];

    changesOperation.qualityOfService = forceFetchAll ? NSQualityOfServiceUtility : NSQualityOfServiceBackground;
    changesOperation.fetchAllChanges  = YES;
    changesOperation.recordZoneIDs    = @[ zoneID ];

    changesOperation.recordChangedBlock =
    ^ ( CKRecord * _Nonnull record )
    {
        [ defaults setBool: YES forKey: HAVE_RECEIVED_CLOUDKIT_DATA ];
        [ self recordDidChange: record ];
    };

    changesOperation.recordWithIDWasDeletedBlock =
    ^ (
        CKRecordID * _Nonnull recordID,
        NSString   * _Nonnull recordType
    )
    {
        [ defaults setBool: YES forKey: HAVE_RECEIVED_CLOUDKIT_DATA ];
        [ self recordDidDelete: recordID ];
    };

    changesOperation.recordZoneChangeTokensUpdatedBlock =
    ^ (
        CKRecordZoneID      * _Nonnull  recordZone,
        CKServerChangeToken * _Nullable serverChangeToken,
        NSData              * _Nullable clientChangeTokenData
    )
    {
        if ( serverChangeToken == nil ) return;

        [ defaults setObject: [ NSKeyedArchiver archivedDataWithRootObject: serverChangeToken ]
                      forKey: CLOUDKIT_FETCHED_CHANGES_TOKEN ];
    };

    changesOperation.recordZoneFetchCompletionBlock =
    ^ (
        CKRecordZoneID      * _Nonnull  recordZoneID,
        CKServerChangeToken * _Nullable serverChangeToken,
        NSData              * _Nullable clientChangeTokenData,
        BOOL                            moreComing,
        NSError             * _Nullable recordZoneError
    )
    {
        if ( recordZoneError != nil || serverChangeToken == nil ) return;

        [ defaults setObject: [ NSKeyedArchiver archivedDataWithRootObject: serverChangeToken ]
                      forKey: CLOUDKIT_FETCHED_CHANGES_TOKEN ];
    };

    changesOperation.fetchRecordZoneChangesCompletionBlock = completionHandler;

    [ database addOperation: changesOperation ];
}

// Called from AppDelegate when notifications arrive.
//
- ( void ) handleNotification: ( NSDictionary  * ) userInfo
       fetchCompletionHandler: ( void ( ^ ) ( UIBackgroundFetchResult ) ) completionHandler
{
    CKNotification * notification = [ CKNotification notificationFromRemoteNotificationDictionary: userInfo ];

    if ( [ notification.subscriptionID isEqualToString: CLOUDKIT_SUBSCRIPTION_ID ] )
    {
        [
            self fetchRecentChangesWithCompletionBlock: ^ ( NSError * _Nullable error )
                                                        {
                                                            completionHandler( UIBackgroundFetchResultNewData );
                                                        }
                              ignoringPriorChangeToken: NO
        ];
    }
    else
    {
        completionHandler( UIBackgroundFetchResultNoData );
    }
}

// Call if a notification from CloudKit indicates that a record changed (or
// was added).
//
- ( void ) recordDidChange: ( CKRecord * _Nonnull ) record
{
    NSLog( @"CloudKit change: Assert presence of %@", record );

    [ self addOrEditFavourite: record.recordID.recordName
           settingDescription: [ record objectForKey: @"stopDescription" ]
             andPreferredFlag: [ record objectForKey: @"preferred"       ]
            includingCloudKit: NO ];
}

// Call if a notification from CloudKit indicates that a record was deleted.
//
- ( void ) recordDidDelete: ( CKRecordID * _Nonnull ) recordID
{
    NSLog( @"CloudKit change: Assert removal of: %@", recordID );

    [ self deleteFavourite: recordID.recordName
         includingCloudKit: NO ];
}

#pragma mark - Cached bus stop location management

// The stops are managed by StopMapViewController entirely, so all we do here
// is return a reference to the mutable dictionary that's being held by the
// AppDelegate for reuse across multiple map view instances.
//
- ( NSMutableDictionary * ) getCachedStopLocationDictionary
{
    return self.cachedStopLocations;
}

// We still need to provide a way to clear out / reinitialise the set of
// stops though.
//
- ( void ) clearCachedStops
{
    self.cachedStopLocations = [ [ NSMutableDictionary alloc ] init ];
}

@end
