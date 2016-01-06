//
//  AppDelegate.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#define DATA_CHANGED_NOTIFICATION_NAME @"BusPandaDataChanged"

@interface AppDelegate : UIResponder <UIApplicationDelegate, UISplitViewControllerDelegate>

@property (           strong, nonatomic ) UIWindow                     * window;
@property ( readonly, strong, nonatomic ) NSManagedObjectContext       * managedObjectContext;
@property ( readonly, strong, nonatomic ) NSManagedObjectModel         * managedObjectModel;
@property ( readonly, strong, nonatomic ) NSPersistentStoreCoordinator * persistentStoreCoordinator;

- ( void    ) saveContext;
- ( NSURL * ) applicationDocumentsDirectory;

@end

