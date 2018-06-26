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
#define DATA_CHANGED_NOTIFICATION_NAME @"BusPandaDataChanged"

@interface AppDelegate : UIResponder < UIApplicationDelegate,
                                       UISplitViewControllerDelegate,
                                       UITabBarControllerDelegate,
                                       WCSessionDelegate >

@property (           strong, nonatomic ) UIWindow                     * window;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContext;
@property ( readonly, strong, nonatomic ) NSManagedObjectModel         * managedObjectModel;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinator;

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
