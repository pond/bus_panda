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

#import "MasterViewController.h"

#define ICLOUD_TOKEN_ID_DEFAULTS_KEY   @"uk.org.pond.Bus-Panda.UbiquityIdentityToken"
#define ICLOUD_ENABLED_APP_ID          @"XT4V976D8Y~uk~org~pond~Bus-Panda"
#define CORE_DATA_FILE_NAME            @"Bus-Panda.sqlite"
#define DATA_CHANGED_NOTIFICATION_NAME @"BusPandaDataChanged"
#define ENTITY_AND_RECORD_NAME         @"BusStop"
#define CLOUDKIT_ZONE_ID               @"busPanda"

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

- ( void    ) saveContext;
- ( NSURL * ) applicationDocumentsDirectory;

- ( NSMutableDictionary * ) getCachedStopLocationDictionary;
- ( void                  ) clearCachedStops;

// Useful parts of the view hierarchy, established at startup

@property ( strong, nonatomic ) UITabBarController     * tabBarController;
@property ( strong, nonatomic ) UISplitViewController  * splitViewController;
@property ( strong, nonatomic ) UINavigationController * masterNavigationController;
@property ( strong, nonatomic ) UINavigationController * detailNavigationController;
@property ( strong, nonatomic ) MasterViewController   * masterViewController;

@end
