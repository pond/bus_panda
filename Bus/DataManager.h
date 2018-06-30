//
//  DataManager.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 30/06/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//
//  Manage the local Core Data store, the legacy iCloud Core Data store (read
//  only) and CloudKit synchronisation.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <CloudKit/CloudKit.h>

#import "UsefulTypes.h"

// * App ID for general iCloud access
// * Ubiquity token for pre-V2 iCloud / Core Data sync
// * Core Data filename for local <-> remote store with pre-V2 iCloud code
//
#define ICLOUD_ENABLED_APP_ID          @"XT4V976D8Y~uk~org~pond~Bus-Panda"
#define ICLOUD_TOKEN_ID_DEFAULTS_KEY   @"uk.org.pond.Bus-Panda.UbiquityIdentityToken"
#define OLD_CORE_DATA_FILE_NAME        @"Bus-Panda.sqlite"

// * V2 local Core Data store, to cache data from CloudKit
// * Custom zone name so we can use the CloudKit 'getChanges' method etc.
// * Custom subscription ID for subscription to changes in the custom zone
//
#define NEW_CORE_DATA_FILE_NAME        @"Bus-Panda-2.sqlite"
#define CLOUDKIT_ZONE_NAME             @"busPanda"
#define CLOUDKIT_SUBSCRIPTION_ID       @"busPandaChanges"

// * Core Data entity name and CloudKit record name for Bus Stop model
//   - In Core Data, there's a "stopID" field
//   - In CloudKit, the record ID is the stop ID (CKRecordID.recordName)
// * Custom notification used when the local store is updated by any means
//   (pre-V2 Core Data iCloud sync, or from CloudKit updates)
//
#define ENTITY_AND_RECORD_NAME         @"BusStop"
#define DATA_CHANGED_NOTIFICATION_NAME @"BusPandaDataChanged"

@interface DataManager : NSObject

// This class is a singleton. Use this method to retrieve the instance.
//
+ ( DataManager * ) dataManager;

// Run this at startup, once you have a view controller to use for presenting
// any alerts that might be needed.
//
- ( void ) awakenAllStores: ( UIViewController * ) viewController
            forApplication: ( UIApplication    * ) application;

// Call from AppDelegate's -application:didReceiveRemoteNotification:...
// method, passing the second two parameters through. Handles CloudKit
// notifications only.
//
- ( void ) handleNotification: ( NSDictionary  * ) userInfo
       fetchCompletionHandler: ( void ( ^ ) ( UIBackgroundFetchResult ) ) completionHandler;

// Local Core Data storage (with manual CloudKit sync)
//
@property ( readonly, strong, nonatomic ) NSManagedObjectModel         * managedObjectModel;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContextLocal;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinatorLocal;

// Legacy iCloud Core Data connections (now read-only)
//
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContextRemote;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinatorRemote;

// Updating records

- ( void ) addOrEditFavourite: ( NSString * ) stopID
           settingDescription: ( NSString * ) stopDescription
             andPreferredFlag: ( NSNumber * ) preferred
            includingCloudKit: ( BOOL       ) includeCloudKit;

- ( void )    deleteFavourite: ( NSString * ) stopID
            includingCloudKit: ( BOOL       ) includeCloudKit;

// Fetched results management and query interfaces

@property ( readonly, strong, nonatomic ) NSFetchedResultsController * fetchedResultsController;

- ( BOOL              ) shouldShowSectionHeader;
- ( NSInteger         ) numberOfSections;
- ( NSManagedObject * ) findFavouriteStopByID: ( NSString * ) stopID;

// Shared utility methods

- ( void                  ) saveContext;
- ( NSMutableDictionary * ) getCachedStopLocationDictionary;
- ( void                  ) clearCachedStops;

@end
