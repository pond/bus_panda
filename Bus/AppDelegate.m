//
//  AppDelegate.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "MasterViewController.h"

@implementation AppDelegate

# pragma mark - Initialisation

- ( BOOL )          application: ( UIApplication * ) application
  didFinishLaunchingWithOptions: ( NSDictionary  * ) launchOptions
{
    // Boilerplate master/detail view setup

    UISplitViewController  * splitViewController  = ( UISplitViewController * ) self.window.rootViewController;
    UINavigationController * navigationController = splitViewController.viewControllers.lastObject;

    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.delegate = self;

    // Set up iCloud and the associated data storage managed object context

    [ self iCloudAccountAvailabilityChanged: nil ];

    [
        [ NSNotificationCenter defaultCenter ] addObserver: self
                                                  selector: @selector( iCloudAccountAvailabilityChanged: )
                                                      name: NSUbiquityIdentityDidChangeNotification
                                                    object: nil
    ];

    UINavigationController * masterNavigationController = splitViewController.viewControllers.firstObject;
    MasterViewController   * controller                 = ( MasterViewController * ) masterNavigationController.topViewController;

    controller.managedObjectContext = self.managedObjectContext;

    return YES;
}

// Wake up iCloud; "notification" parameter is ignored.
//
- ( void ) iCloudAccountAvailabilityChanged: ( NSNotification * ) notification
{
    ( void ) notification;

    NSLog( @"iCloud ubiquity token has changed" );

    NSUserDefaults * defaults           = [ NSUserDefaults standardUserDefaults ];
    NSFileManager  * fileManager        = [ NSFileManager defaultManager ];
    id               currentiCloudToken = fileManager.ubiquityIdentityToken;

    if ( currentiCloudToken )
    {
        NSData * newTokenData =
        [
            NSKeyedArchiver archivedDataWithRootObject: currentiCloudToken
        ];

        [ defaults setObject: newTokenData
                      forKey: @"uk.org.pond.Bus-Panda.UbiquityIdentityToken" ];
    }
    else
    {
        [ defaults removeObjectForKey: @"uk.org.pond.Bus-Panda.UbiquityIdentityToken" ];
    }

    NSLog( @"iCloud ubiquity token now: %@", currentiCloudToken );
}

# pragma mark - Termination

- ( void ) applicationWillTerminate: ( UIApplication * ) application
{
    [ self saveContext ];
}

#pragma mark - Split view

- ( BOOL )    splitViewController: ( UISplitViewController * ) splitViewController
  collapseSecondaryViewController: ( UIViewController      * ) secondaryViewController
        ontoPrimaryViewController: ( UIViewController      * ) primaryViewController
{
    if ( [ secondaryViewController isKindOfClass: [ UINavigationController class ] ] &&
         [ [ ( UINavigationController * ) secondaryViewController topViewController ] isKindOfClass: [ DetailViewController class ] ] &&
         ( [ ( DetailViewController   * ) [ ( UINavigationController * ) secondaryViewController topViewController ] detailItem ] == nil ) )
    {
        // Return YES to indicate that we have handled the collapse by doing
        // nothing; the secondary controller will be discarded.
        //
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - Core Data stack

@synthesize managedObjectContext       = _managedObjectContext;
@synthesize managedObjectModel         = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

// The directory the application uses to store the Core Data store file. This
// code uses a directory named "uk.org.pond.Bus-Panda" in the application's
// documents directory.

- ( NSURL * ) applicationDocumentsDirectory
{
    return [ [ [ NSFileManager defaultManager ] URLsForDirectory: NSDocumentDirectory
                                                       inDomains: NSUserDomainMask ] lastObject ];
}

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

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- ( NSPersistentStoreCoordinator * ) persistentStoreCoordinator
{
    if ( _persistentStoreCoordinator != nil )
    {
        return _persistentStoreCoordinator;
    }

    _persistentStoreCoordinator = [ [ NSPersistentStoreCoordinator alloc ] initWithManagedObjectModel: [ self managedObjectModel ] ];

    NSPersistentStoreCoordinator * psc = _persistentStoreCoordinator;

//    // Set up iCloud in another thread.
//    //
//    dispatch_async
//    (
//        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^
//        {
            NSString * iCloudContainerID  = @"iCloud.uk.org.pond.Bus-Panda";
            NSString * iCloudEnabledAppID = @"XT4V976D8Y.uk.org.pond.Bus-Panda";
            NSString * dataFileName       = @"Bus-Panda.sqlite";

            NSFileManager * fileManager = [ NSFileManager defaultManager ];
            NSURL         * iCloud      = [ fileManager URLForUbiquityContainerIdentifier: iCloudContainerID ];

            if ( iCloud )
            {
                NSLog( @"iCloud is working: %@", iCloud );

                NSString * iCloudDataDirectoryName = @"Data.nosync";
                NSString * iCloudLogsDirectoryName = @"Logs";
                NSURL    * iCloudLogsPath          =
                [
                    NSURL fileURLWithPath: [ [ iCloud path ] stringByAppendingPathComponent: iCloudLogsDirectoryName ]
                ];

                NSLog( @"dataFileName = %@",            dataFileName            );
                NSLog( @"iCloudEnabledAppID = %@",      iCloudEnabledAppID      );
                NSLog( @"iCloudDataDirectoryName = %@", iCloudDataDirectoryName );
                NSLog( @"iCloudLogsDirectoryName = %@", iCloudLogsDirectoryName );
                NSLog( @"iCloudLogsPath = %@",          iCloudLogsPath          );

                NSString * iCloudDataDirectoryPath =
                [
                    [ iCloud path ] stringByAppendingPathComponent: iCloudDataDirectoryName
                ];

                if ( [ fileManager fileExistsAtPath: iCloudDataDirectoryPath ] == NO )
                {
                    NSError * fileSystemError;

                    [ fileManager createDirectoryAtPath: iCloudDataDirectoryPath
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: &fileSystemError ];

                    if ( fileSystemError != nil )
                    {
                        // TODO: This is in a GCD thread. What can we possibly
                        // do about such errors? If the folder can't be created
                        // because the pathname is wrong we've code bugs that
                        // retries won't solve. If the filesystem is full or
                        // corrupted, iOS couldn't handle a local store anyway
                        // so attempting to disable iCloud and fall back would
                        // fail.
                        //
                        NSLog( @"Error creating database directory %@", fileSystemError );
                    }
                }

                NSString *iCloudData = [ iCloudDataDirectoryPath stringByAppendingPathComponent: dataFileName ];

                NSLog( @"iCloudData = %@", iCloudData );

                NSDictionary *options =
                @{
                    NSMigratePersistentStoresAutomaticallyOption: @YES,
                    NSInferMappingModelAutomaticallyOption:       @YES,
                    NSPersistentStoreUbiquitousContentNameKey:    iCloudEnabledAppID,
                    NSPersistentStoreUbiquitousContentURLKey:     iCloudLogsPath
                };

                [
                    psc performBlockAndWait: ^ ( void )
                    {
                        [ psc addPersistentStoreWithType: NSSQLiteStoreType
                                           configuration: nil
                                                     URL: [ NSURL fileURLWithPath: iCloudData ]
                                                 options: options
                                                   error: nil ];
                    }
                ];
            }
            else
            {
                NSLog( @"iCloud is NOT working - using a local store" );

                NSURL * localStore = [ [ self applicationDocumentsDirectory ] URLByAppendingPathComponent: dataFileName ];

                NSLog( @"dataFileName = %@", dataFileName);
                NSLog( @"localStore URL = %@", localStore);

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
            }

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

//        }
//     );

    return _persistentStoreCoordinator;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- ( NSManagedObjectContext * ) managedObjectContext
{
    if ( _managedObjectContext != nil )
    {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator * psc = [ self persistentStoreCoordinator ];

    if ( psc != nil )
    {
        NSManagedObjectContext * moc = [ [ NSManagedObjectContext alloc ] initWithConcurrencyType: NSMainQueueConcurrencyType ];

        [
            moc performBlockAndWait: ^ ( void )
            {
                [ moc setPersistentStoreCoordinator: psc ];

                [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                            selector: @selector( mergeChangesFromiCloud: )
                                                                name: NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                                              object: psc ];
            }
        ];

        _managedObjectContext = moc;
    }

    return _managedObjectContext;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- ( void ) mergeChangesFromiCloud: ( NSNotification * ) notification
{
    NSLog( @"Merging changes from iCloud..." );

    NSManagedObjectContext * moc = [ self managedObjectContext ];

    [
        moc performBlock: ^ ( void )
        {
            [ moc mergeChangesFromContextDidSaveNotification: notification ];

            NSNotification * refreshNotification = [ NSNotification notificationWithName: DATA_CHANGED_NOTIFICATION_NAME
                                                                                  object: self
                                                                                userInfo: [ notification userInfo ] ];

            [ [ NSNotificationCenter defaultCenter ] postNotification: refreshNotification];
        }
    ];
}

#pragma mark - Core Data saving support

- ( void ) saveContext
{
    NSManagedObjectContext * managedObjectContext = self.managedObjectContext;

    if ( managedObjectContext != nil )
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
}

@end
