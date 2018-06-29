//
//  AppDelegate.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <CloudKit/CloudKit.h>
#import <WatchConnectivity/WatchConnectivity.h>

#import "UsefulTypes.h"
#import "MasterViewController.h"

// * App ID for general iCloud access
// * Ubiquity token for pre-V2 iCloud / Core Data sync
// * Core Data filename for local <-> remote store with pre-V2 iCloud code

// * V2 local Core Data store, to cache data from CloudKit
// * CloudKit custom zone ID, needed for change tracking

// * Core Data entity name and CloudKit record name for Bus Stop model
//   - In Core Data, there's a "stopID" field
//   - In CloudKit, the record ID is the stop ID (CKRecordID.recordName)
// * Custom notification used when the local store is updated by any means
//   (pre-V2 Core Data iCloud sync, or from CloudKit updates)

#define ICLOUD_ENABLED_APP_ID          @"XT4V976D8Y~uk~org~pond~Bus-Panda"
#define ICLOUD_TOKEN_ID_DEFAULTS_KEY   @"uk.org.pond.Bus-Panda.UbiquityIdentityToken"
#define OLD_CORE_DATA_FILE_NAME        @"Bus-Panda.sqlite"

#define NEW_CORE_DATA_FILE_NAME        @"Bus-Panda-2.sqlite"
#define CLOUDKIT_ZONE_ID               @"busPanda"

#define ENTITY_AND_RECORD_NAME         @"BusStop"
#define DATA_CHANGED_NOTIFICATION_NAME @"BusPandaDataChanged"


@interface AppDelegate : UIResponder < UIApplicationDelegate,
                                       UISplitViewControllerDelegate,
                                       UITabBarControllerDelegate,
                                       WCSessionDelegate >

@property (           strong, nonatomic ) UIWindow                     * window;
@property ( readonly, strong, nonatomic ) NSManagedObjectModel         * managedObjectModel;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContextLocal;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContextRemote;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinatorLocal;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinatorRemote;

// Shared utility methods

- ( NSURL               * ) applicationDocumentsDirectory;
- ( NSManagedObject     * ) findFavouriteStopByID: ( NSString * ) stopID;
- ( void                  ) saveContext;

- ( NSMutableDictionary * ) getCachedStopLocationDictionary;
- ( void                  ) clearCachedStops;

// Useful parts of the view hierarchy, established at startup

@property ( strong, nonatomic ) UITabBarController     * tabBarController;
@property ( strong, nonatomic ) UISplitViewController  * splitViewController;
@property ( strong, nonatomic ) UINavigationController * masterNavigationController;
@property ( strong, nonatomic ) UINavigationController * detailNavigationController;
@property ( strong, nonatomic ) MasterViewController   * masterViewController;

@end
