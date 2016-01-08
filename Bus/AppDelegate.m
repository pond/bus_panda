//
//  AppDelegate.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <unistd.h> // For usleep() only

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

    UINavigationController * masterNavigationController = splitViewController.viewControllers.firstObject;
    MasterViewController   * masterViewController       = ( MasterViewController * ) masterNavigationController.topViewController;

    // Set up iCloud and the associated data storage managed object context

    [ self iCloudAccountAvailabilityChanged: nil ];

    [
        [ NSNotificationCenter defaultCenter ] addObserver: self
                                                  selector: @selector( iCloudAccountAvailabilityChanged: )
                                                      name: NSUbiquityIdentityDidChangeNotification
                                                    object: nil
    ];

    masterViewController.managedObjectContext = self.managedObjectContext;

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

            [ self sendDataHasChangedNotification ];
        }
    }
    else
    {
        // iCloud seems to no longer be available. Remove any stored iCloud
        // token and send the 'data changed' notification.

        [ defaults removeObjectForKey: ICLOUD_TOKEN_ID_DEFAULTS_KEY ];
        [ self sendDataHasChangedNotification ];
    }

    [ defaults synchronize ];

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

// Send a notification saying that the iCloud data has changed. A listener is
// set up in MasterViewController.m. The notification is sent via GCD on a
// separate thread.
//
- ( void ) sendDataHasChangedNotification
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ ( void )
        {
            // TODO: Can this hack be removed?
            //
            // This is a hack to avoid potential race conditions. For example,
            // AppDelegate has to wake up iCloud (because it needs the various
            // state variables available for when 'will terminate' happens and
            // it has to quickly try and save context), but it's the
            // MasterViewController which registers for data change
            // notifications. Conceivably, AppDelegate could set up the iCloud
            // wakeup thread and have it run before the MVC gets to whatever
            // stage of initialisation is needed to register that handler. It
            // is very unlikely, but might happen. A short sleep here reduces
            // that chance to effectively zero by forcing a definite context
            // switch to what will be at that time a very busy main thread.
            //
            usleep( 100 ); // 100 microseconds => 0.1 seconds

            [ [ NSNotificationCenter defaultCenter ] postNotificationName: DATA_CHANGED_NOTIFICATION_NAME
                                                                   object: self
                                                                 userInfo: nil ];
        }
    );
}

// The directory the application uses to store the Core Data store file. This
// code uses a directory named "uk.org.pond.Bus-Panda" in the application's
// documents directory.
//
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

    _persistentStoreCoordinator = [
        [ NSPersistentStoreCoordinator alloc ]
        initWithManagedObjectModel: [ self managedObjectModel ]
    ];

    NSPersistentStoreCoordinator * psc = _persistentStoreCoordinator;

    // Set up iCloud in another thread: "In iOS, apps that use document storage
    // must call the URLForUbiquityContainerIdentifier: method of the
    // NSFileManager method for each supported iCloud container. Always call
    // the URLForUbiquityContainerIdentifier: method from a background thread -
    // not from your app’s main thread. This method depends on local and remote
    // services and, for this reason, does not always return immediately"
    //
    // https://developer.apple.com/library/ios/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html#//apple_ref/doc/uid/TP40012094-CH6-SW1
    //
    dispatch_async
    (
        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^
        {
            NSString * iCloudEnabledAppID = @"XT4V976D8Y~uk~org~pond~Bus-Panda";
            NSString * dataFileName       = @"Bus-Panda.sqlite";

            // "nil" for container identifier => choose the first from the entitlements
            // file's com.apple.developer.ubiquity-container-identifiers array. That's
            // nice as it avoids duplicating info there and here.
            //
            NSFileManager * fileManager = [ NSFileManager defaultManager ];
            NSURL         * iCloud      = [ fileManager URLForUbiquityContainerIdentifier: nil ];

            if ( iCloud )
            {
                NSURL * iCloudDataURL = [ [ self applicationDocumentsDirectory ] URLByAppendingPathComponent: dataFileName ];

                NSLog( @"iCloud is working: %@",  iCloud             );
                NSLog( @"dataFileName: %@",       dataFileName       );
                NSLog( @"iCloudEnabledAppID: %@", iCloudEnabledAppID );
                NSLog( @"iCloudDataURL: %@",      iCloudDataURL      );

                NSDictionary *options =
                @{
                    NSMigratePersistentStoresAutomaticallyOption: @YES,
                    NSInferMappingModelAutomaticallyOption:       @YES,
                    NSPersistentStoreUbiquitousContentNameKey:    iCloudEnabledAppID
                };

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
                NSLog( @"iCloud is NOT working - using a local store" );

                NSURL * localStore = [ [ self applicationDocumentsDirectory ] URLByAppendingPathComponent: dataFileName ];

                NSLog( @"dataFileName = %@",   dataFileName );
                NSLog( @"localStore URL = %@", localStore   );

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

            [ self sendDataHasChangedNotification ];
        }
     );

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

        moc.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;

        _managedObjectContext = moc;
    }

    return _managedObjectContext;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- ( void ) mergeChangesFromiCloud: ( NSNotification * ) notification
{
    NSLog( @"Merging changes from iCloud..." );

    NSManagedObjectContext * moc = self.managedObjectContext;

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

- ( void ) storesWillChange: ( NSNotification * ) notification
{
    NSLog( @"Stores will change..." );

    // Close to copy-and-paste on 'savContext', except for the 'reset' call
    // needed *inside* the atomicity wrapper of 'perform block and wait'.

    NSManagedObjectContext * moc = self.managedObjectContext;

    [
        moc performBlockAndWait: ^
        {
            NSError * error = nil;

            if ( [ moc hasChanges ] && ![ moc save: &error ] )
            {
                // Nothing much we can do here other than log the fault.
                //
                NSLog( @"Unresolved error %@, %@", error, [ error userInfo ] );
            }

            [ moc reset ];
        }
    ];

    // Reset the GUI but don't load any new data yet - have to wait for 'stores
    // did change' for that.

    UISplitViewController  * splitViewController  = ( UISplitViewController * ) self.window.rootViewController;
    UINavigationController * navigationController = splitViewController.viewControllers.lastObject;

    [ navigationController popToRootViewControllerAnimated: YES ];
}

- ( void ) storesDidChange: ( NSNotification * ) notification
{
    NSLog( @"Stores did change..." );

    // Close to copy-and-paste on 'mergeChangesFromiCloud', except it just
    // posts the 'changed' notification for other bits of the app, rather than
    // also trying to merge in changes.

    NSManagedObjectContext * moc = self.managedObjectContext;

    [
        moc performBlock: ^ ( void )
        {
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

@end
