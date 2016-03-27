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
#import "BusInfoFetcher.h"

@interface AppDelegate ()

// An application-wide cache of bus stop locations for the map view.
// This is updated or cleared and refreshed via StopMapViewController,
// but retained by the AppDelegate so that any number of new instances
// of the map view's controller will be able to reuse the same data.

@property ( strong ) NSMutableDictionary * cachedStopLocations;

@end

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

    // Initialse the cached bus stop location data

    [ self clearCachedStops ];

    // If this is the first time the application has ever been run, set up a
    // collection of predefined useful stops.
    //
    NSUserDefaults * defaults     = [ NSUserDefaults standardUserDefaults ];
    BOOL             hasRunBefore = [ defaults boolForKey: @"hasRunBefore" ];

    if ( hasRunBefore != YES )
    {
        [ defaults setBool: YES forKey: @"hasRunBefore" ];
        [ defaults synchronize ];

        // TODO: The below is used for screenshots in the simulator; for the
        // real world, something similar to load a sensible set of first-time
        // stops would be good. But a first-install on your *local* device
        // does not mean you have a first-install for *any* of your devices;
        // we have to check the ever-difficult, flaky, badly documented and
        // hard to understand (especially in view of iOS 5/6 vs 7 vs 8 major
        // changes) iCloud.
        //
        // There are a few online blogs which discuss possible approaches but
        // until the most basic Core Data / iCloud stuff seems to actually
        // work properly, I'm steering well clear.

        //        NSDictionary * cannedStops = @{
        //            @"5000": @"Courtenay Aroy",
        //            @"5516": @"Courtenay Blair",
        //            @"5514": @"Courtenay Reading",
        //            @"7418": @"Express",
        //            @"5513": @"Manners BK",
        //            @"5515": @"Manners Body",
        //            @"4113": @"Murphy Wellington Girls",
        //            @"7018": @"Riddiford At Hall",
        //            @"1200": @"Sparse",
        //            @"6000": @"Station A",
        //            @"6001": @"Station B",
        //            @"5500": @"Station C",
        //            @"7120": @"Rintoul At Stoke",
        //            @"TALA": @"Talavera - Cable Car Station"
        //        };
        //
        //        [
        //            cannedStops enumerateKeysAndObjectsUsingBlock: ^ ( NSString * stopID,
        //                                                               NSString * stopDescription,
        //                                                               BOOL     * stop )
        //            {
        //                [ self addFavourite: stopID withDescription: stopDescription ];
        //            }
        //        ];
    }
    
    // Wake up the WatchKit extension and this applicaftion via WCSession.
    //
    if ( [ WCSession isSupported ] )
    {
        WCSession * session = [ WCSession defaultSession ];

        session.delegate = self;
        [ session activateSession ];

        // Leaning on the WCSessionDelegate method to check session details and
        // send an update is a reliable way to get the ball rolling.
        //
        [ self sessionWatchStateDidChange: session ];
    }

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

# pragma mark - WCSessionDelegate support

// WCSessionDelegate.
//
// In iOS 9.3, a delegate must support this method for multiple Apple watches
// to be used. Since the companion application is read-only, we don't need to
// do anything here other than provide an empty implementation.
//
- ( void )               session: ( WCSession                * ) session
  activationDidCompleteWithState: ( WCSessionActivationState   ) activationState
                           error: ( NSError                  * ) error
{
}

// WCSessionDelegate.
//
// In iOS 9.3, a delegate must support this method for multiple Apple watches
// to be used. Since the companion application is read-only, we don't need to
// do anything here other than provide an empty implementation.
//
- ( void ) sessionDidBecomeInactive: ( WCSession * ) session
{
}

// WCSessionDelegate.
//
// In iOS 9.3, a delegate must support this method for multiple Apple watches
// to be used. Since the companion application is read-only, we don't need to
// do anything here other than provide an empty implementation.
//
- ( void ) sessionDidDeactivate: ( WCSession * ) session
{
    [ [ WCSession defaultSession ] activateSession ];
}

// WCSessionDelegate.
//
// A state change has occurred with a Watch; it has paired, and/or the Bus
// Panda companion application has been installed (or vice versa). Check the
// session details and prompt a data update if need be.
//
- ( void ) sessionWatchStateDidChange: ( WCSession * ) session
{
    if ( session.paired && session.watchAppInstalled )
    {
        UISplitViewController  * splitViewController  = ( UISplitViewController * ) self.window.rootViewController;
        UINavigationController * masterNavigationController = splitViewController.viewControllers.firstObject;
        MasterViewController   * masterViewController       = ( MasterViewController * ) masterNavigationController.topViewController;

        [ masterViewController updateWatch: nil ];
    }
}

// WCSessionDelegate.
//
// The Watch app is asking us to do something and expects a reply.
//
- ( void ) session: ( WCSession                     * ) session
 didReceiveMessage: ( NSDictionary <NSString *, id> * ) message
      replyHandler: ( void (^)( NSDictionary <NSString *, id> * _Nonnull ) ) replyHandler
{
    NSString * action = message[ @"action" ];

    if ( [ action isEqualToString: @"getBuses" ] == YES )
    {
        NSString * stopID = message[ @"data" ];

        if ( stopID != nil )
        {
            [
                BusInfoFetcher getAllBusesForStop: stopID
                                completionHandler: ^ ( NSMutableArray * allBuses )
                {
                    replyHandler( @{ @"allBuses": allBuses } );
                }
            ];
        }
    }
    else
    {
        replyHandler( @{} );
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
