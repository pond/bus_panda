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
#import "StopMapViewController.h"
#import "BusInfoFetcher.h"
#import "NearestStopBusInfoFetcher.h"

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
    NSUserDefaults * defaults = [ NSUserDefaults standardUserDefaults ];

    // Tab bar setups

    self.tabBarController = ( UITabBarController * ) self.window.rootViewController;
    self.tabBarController.delegate = self;

    // Boilerplate master/detail view setup

    self.splitViewController = ( UISplitViewController * ) self.tabBarController.viewControllers.firstObject;
    self.splitViewController.delegate = self;
    self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;

    self.detailNavigationController = self.splitViewController.viewControllers.lastObject;
    self.detailNavigationController.topViewController.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;

    self.masterNavigationController = self.splitViewController.viewControllers.firstObject;
    self.masterViewController       = ( MasterViewController * ) self.masterNavigationController.topViewController;

    // Set up iCloud and the associated data storage managed object context


    [
        [ NSNotificationCenter defaultCenter ] addObserver: self
                                                  selector: @selector( iCloudAccountAvailabilityChanged: )
                                                      name: NSUbiquityIdentityDidChangeNotification
                                                    object: nil
    ];

    self.masterViewController.managedObjectContext = self.managedObjectContext;

    // Initialse the cached bus stop location data.
    //
    [ self clearCachedStops ];

    // On a clean install, some iOS versions may not read the Settings bundle
    // into the NSUserDefaults unless the user has by happenstance manually
    // launched the system Settings application first. Work around this in a
    // clumsy way which involves basically duplicating the defaults in the
    // settings bundle. There are some complex attempts to work around this on
    // e.g. StackOverflow but they all have issues with e.g. localized strings,
    // changes of iOS version, BOOL vs NSString values and so-on.
    //
    id shouldNotBeNil = [ defaults objectForKey: @"shorten_names_preference" ];

    if ( shouldNotBeNil == nil )
    {
        [ defaults setBool: YES forKey: @"shorten_names_preference" ];

        // ...and in future, add any more settings here too.

        [ defaults synchronize ];
    }

    // If this is the first time the application has ever been run, set up a
    // collection of predefined useful stops.
    //
    BOOL hasRunBefore = [ defaults boolForKey: @"hasRunBefore" ];

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

        [ self pushListOfStopsToWatch: session ];
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

# pragma mark - Tab controller

// Here we take setup or restoration steps when the user switches between
// tabs. The restoration identifier in the storyboard is used to determine
// which tab has been selected when called here.
//
- ( BOOL ) tabBarController: ( UITabBarController * ) tabBarController
 shouldSelectViewController: ( UIViewController   * ) viewController
{
    // Mostly relevant to iPhone where there's no split view.
    //
    // For Favourite Stops, make sure we always pop back from a timetable view,
    // if present, to just showing the current stop when the tab is chosen.
    // This is generally the Useful Thing To Do (though not always). If the
    // *current* tab is already the 'favourites' view then allow repeated taps
    // on that tap to act like "back" and pop down to the root if need be.
    //
    if ( [ viewController.restorationIdentifier isEqualToString: @"FavouriteStops" ] )
    {
        // If we've navigated beyond the master view of favourite stops...
        //
        if ( self.masterNavigationController.viewControllers.count == 2 )
        {
            UINavigationController * stopsNavigationController = self.masterNavigationController.viewControllers.lastObject;

            // ...and we're showing a particular stop, but there isn't a
            // timetable view pushed on top of that...
            //
            if ( stopsNavigationController.viewControllers.count == 1 )
            {
                // ...and we're already on the Favourites tab, then pop down
                // to the root view.
                //
                if ( tabBarController.selectedIndex == 0 )
                {
                    [ self.masterNavigationController popToRootViewControllerAnimated: YES ];
                }
            }

            // ...and we're showing a particular stop with a timetable view
            // pushed on top, so pop it away.
            //
            else
            {
                [ stopsNavigationController popToRootViewControllerAnimated: YES ];
            }
        }
    }

    // For Nearby Stops, make sure we always pop back to the map when the
    // tab is selected and be sure that the StopMapViewController presenting
    // the content is configured for "nearby stops" mode.
    //
    else if ( [ viewController.restorationIdentifier isEqualToString: @"NearbyStops" ] )
    {
        UINavigationController * navigationController = ( UINavigationController * ) viewController;
        [ navigationController popToRootViewControllerAnimated: YES ];

        StopMapViewController * stopMapController = (StopMapViewController * ) navigationController.topViewController;
        [ stopMapController configureForNearbyStops ];
    }

    return YES;
}

# pragma mark - WCSessionDelegate and related methods

// WCSessionDelegate.
//
// In iOS 9.3, a delegate must support this method for multiple Apple watches
// to be used. Since the companion application is read-only, we don't need to
// do anything here other than - just in case - manually call the 'watch state
// did change' method to provoke a pushed update to the watch.
//
- ( void )               session: ( WCSession                * ) session
  activationDidCompleteWithState: ( WCSessionActivationState   ) activationState
                           error: ( NSError                  * ) error
{
    [ self pushListOfStopsToWatch: session ];
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
    [ self pushListOfStopsToWatch: session ];
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

    if ( [ action isEqualToString: @"getStops" ] == YES )
    {
        [ self pushListOfStopsToWatch: session ];
    }
    else if ( [ action isEqualToString: @"getBuses" ] == YES )
    {
        NSString * stopID = message[ @"data" ];

        if ( stopID != nil )
        {
            [
                BusInfoFetcher getAllBusesForStop: stopID
                      usingWebScraperInsteadOfAPI: NO
                                completionHandler: ^ ( NSMutableArray * allBuses )
                {
                    replyHandler( @{ @"allBuses": allBuses } );
                }
            ];
        }
    }
    else if ( [ action isEqualToString: @"getNearest" ] == YES )
    {
        @try
        {
            NearestStopBusInfoFetcher * fetcher = [ [ NearestStopBusInfoFetcher alloc ] init ];
            [ fetcher beginWithWatchOSReplyHandler: replyHandler ];
        }
        @catch ( NSException * exception )
        {
            replyHandler( @{ @"error": @"Bus Panda was unable to read your location" } );
        }
    }
    else
    {
        replyHandler( @{} );
    }
}

// Call the MasterViewController and tell it to update the Watch App with
// the current list of stops.
//
// The optional WCSession * parameter tells the method which session to use;
// if omitted, it uses "[ WCSession defaultSession ]".
//
// If WCSession is not currently suppported, reports no watch paired or
// reports no watch app installed, nothing will happen.
//
- ( void ) pushListOfStopsToWatch: ( WCSession * ) session
{
    if ( [ WCSession isSupported ] && session.paired && session.watchAppInstalled )
    {
        [ self.masterViewController updateWatch: nil ];
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

    [ self.detailNavigationController popToRootViewControllerAnimated: YES ];
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

// This is intended really just for one-shot data migrations and is not very
// efficient as it intentionally does not provide any cache name for the
// results, so it'll re-fetch every time.
//
- ( NSArray * ) getAllFavourites
{
    NSFetchRequest      * fetchRequest = [ [ NSFetchRequest alloc] init ];
    NSEntityDescription * entity       = [ NSEntityDescription entityForName: @"BusStop"
                                                      inManagedObjectContext: self.managedObjectContext ];

    [ fetchRequest setEntity:         entity ];
    [ fetchRequest setFetchBatchSize: 50     ];

    NSSortDescriptor * sortDescriptor = [ [ NSSortDescriptor alloc] initWithKey: @"stopDescription"
                                                                      ascending: YES ];

    [ fetchRequest setSortDescriptors: @[ sortDescriptor ] ];

    NSFetchedResultsController * frc = [ [ NSFetchedResultsController alloc ] initWithFetchRequest: fetchRequest
                                                                              managedObjectContext: self.managedObjectContext
                                                                                sectionNameKeyPath: @"preferred"
                                                                                         cacheName: nil ];
    return frc.fetchedObjects;
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
