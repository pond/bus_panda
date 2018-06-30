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

#import "Constants.h"
#import "UsefulTypes.h"

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
