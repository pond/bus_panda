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
#import "MasterViewController.h"

@interface DataManager : NSObject

// This class is a singleton. Use this method to retrieve the instance.
//
+ ( DataManager * _Nonnull ) dataManager;

// To avoid referencing AppDelegate from non-main threads, we have it
// tell us where the MasterViewController is at startup then use this
// local copy for reference.
//
@property ( strong ) MasterViewController * _Nonnull masterViewController;

// Run this at startup, once you have a view controller to use for presenting
// any alerts that might be needed. Make sure you've set masterViewController
// (see above) first.
//
- ( void ) awakenAllStores;

// Call from AppDelegate's -application:didReceiveRemoteNotification:...
// method, passing the second two parameters through. Handles CloudKit
// notifications only.
//
- ( void ) handleNotification: ( NSDictionary  * _Nonnull ) userInfo
       fetchCompletionHandler: ( void ( ^ _Nonnull ) ( UIBackgroundFetchResult ) ) completionHandler;

// Local Core Data storage (with manual CloudKit sync)
//
@property ( readonly, strong, nonatomic ) NSManagedObjectModel         * _Nonnull managedObjectModel;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * _Nonnull managedObjectContextLocal;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * _Nonnull persistentStoreCoordinatorLocal;

// Updating records

- ( void ) addOrEditFavourite: ( NSString * _Nullable ) stopID
           settingDescription: ( NSString * _Nullable ) stopDescription
             andPreferredFlag: ( NSNumber * _Nullable ) preferred
            includingCloudKit: ( BOOL                 ) includeCloudKit;

- ( void )    deleteFavourite: ( NSString * _Nullable ) stopID
            includingCloudKit: ( BOOL                 ) includeCloudKit;

// Fetched results management and query interfaces

@property ( readonly, strong, nonatomic ) NSFetchedResultsController * _Nonnull fetchedResultsControllerLocal;

- ( BOOL                        ) shouldShowSectionHeader;
- ( NSInteger                   ) numberOfSections;
- ( NSManagedObject * _Nullable ) findFavouriteStopByID: ( NSString * _Nonnull ) stopID;

// CloudKit change management

- ( void ) fetchRecentChangesWithCompletionBlock: ( void ( ^ _Nonnull )( NSError * _Nullable error ) ) completionHandler
                        ignoringPriorChangeToken: ( BOOL ) forceFetchAll;

// Shared utility methods

- ( void                           ) saveLocalContext;
- ( NSMutableDictionary * _Nonnull ) getCachedStopLocationDictionary;
- ( void                           ) clearCachedStops;

@end
