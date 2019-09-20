//
//  AppDelegate.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"

#import "Constants.h"
#import "DataManager.h"
#import "DetailViewController.h"
#import "MasterViewController.h"
#import "StopMapViewController.h"
#import "BusInfoFetcher.h"
#import "NearestStopBusInfoFetcher.h"

@interface AppDelegate ()

    // Keep a permanent reference to the data manager singleton, so it
    // doesn't go away at inconvenient moments!
    //
    @property ( strong ) DataManager * dataManager;

@end

@implementation AppDelegate

    @synthesize dataManager = _dataManager;

# pragma mark - Initialisation

- ( BOOL )          application: ( UIApplication * ) application
  didFinishLaunchingWithOptions: ( NSDictionary  * ) launchOptions
{
    NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;

    [ application registerForRemoteNotifications ];

    if (@available(iOS 11, *))
    {
        self.window.tintColor = [ UIColor colorNamed: @"busLivery" ];
    }

    // Tab bar setups

    self.tabBarController = ( UITabBarController * ) self.window.rootViewController;
    self.tabBarController.delegate = self;

    // TODO: Implement "follow" and/or "settings".
    //
    NSMutableArray * viewControllers = [ ( NSMutableArray * ) self.tabBarController.viewControllers mutableCopy ];

    [ viewControllers removeObjectAtIndex: 4 ]; // Settings
    [ viewControllers removeObjectAtIndex: 2 ]; // Follow

    [ self.tabBarController setViewControllers: viewControllers ];

    // Boilerplate master/detail view setup

    self.splitViewController = ( UISplitViewController * ) self.tabBarController.viewControllers.firstObject;
    self.splitViewController.delegate = self;
    self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;

    self.detailNavigationController = self.splitViewController.viewControllers.lastObject;
    self.detailNavigationController.topViewController.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;

    self.masterNavigationController = self.splitViewController.viewControllers.firstObject;
    self.masterViewController = ( MasterViewController * ) self.masterNavigationController.topViewController;

    // Wake up local Core Data and iCloud. This also registers for remote
    // notifications (for CloudKit changes), but the AppDelegate object has
    // to handle them - see -didReceiveRemoteNotification:... later.
    //
    _dataManager = DataManager.dataManager;
    [ _dataManager setMasterViewController: self.masterViewController ];
    [ _dataManager awakenAllStores ];

    // On a clean install, some iOS versions may not read the Settings bundle
    // into the NSUserDefaults unless the user has by happenstance manually
    // launched the system Settings application first. Work around this in a
    // clumsy way which involves basically duplicating the defaults in the
    // settings bundle. There are some complex attempts to work around this on
    // e.g. StackOverflow but they all have issues with e.g. localized strings,
    // changes of iOS version, BOOL vs NSString values and so-on.
    //
    id shouldNotBeNil = [ defaults objectForKey: SHORTEN_DISPLAYED_NAMES ];

    if ( shouldNotBeNil == nil )
    {
        [ defaults setBool: YES forKey: SHORTEN_DISPLAYED_NAMES ];

        // ...and in future, add any more settings here too.
    }

    shouldNotBeNil = [ defaults objectForKey: WEATHER_PROVIDER ];

    if ( shouldNotBeNil == nil )
    {
        [ defaults setValue: WEATHER_PROVIDER_METSERVICE forKey: WEATHER_PROVIDER ];
    }

#ifdef SCREENSHOT_BUILD

    NSLog( @"Startup: Screenshot build: Checking local data" );

    NSFetchedResultsController * frc     = DataManager.dataManager.fetchedResultsControllerLocal;
    NSArray                    * results = nil;
    NSError                    * error   = nil;
    BOOL                         success;

    success = [ frc performFetch: &error ];

    if ( success == YES && error == nil ) results = [ frc fetchedObjects ];

    if ( results != nil )
    {
        NSLog( @"Startup: Have %lu existing local entries to remove", ( unsigned long ) results.count );

        for ( NSManagedObject * object in results )
        {
            NSString * stopID = [ object valueForKey: @"stopID" ];
            [ DataManager.dataManager deleteFavourite: stopID includingCloudKit: NO ];
        }
    }
    else
    {
        NSLog( @"Startup: No existing local entries, or error: %@", error );
    }

    NSDictionary * cannedStops = @{
        @"5000": @"Courtenay Aroy",
        @"5516": @"Courtenay Blair",
        @"5514": @"Courtenay Reading",
        @"5513": @"Manners BK",
        @"5515": @"Manners Body",
        @"7418": @"Express",
        @"7018": @"Riddiford At Hall",
        @"6910": @"Opposite Les Mills",
        @"6000": @"Station A",
        @"6001": @"Station B",
        @"5500": @"Station C",
        @"7120": @"Rintoul At Stoke",
        @"TALA": @"Talavera - Cable Car",
        @"7711": @"Willis St - Unity"
    };

    for ( NSString * key in cannedStops )
    {
        NSString * stopID          = key;
        NSString * stopDescription = cannedStops[ key ];
        NSNumber * preferred       = @( NO );

        if ( [ key hasPrefix: @"6" ] ) preferred = @( YES );

        NSLog( @"Startup: Add canned stop: %@ (%@): %@", stopID, preferred, stopDescription );

        [ DataManager.dataManager addOrEditFavourite: stopID
                                  settingDescription: stopDescription
                                    andPreferredFlag: preferred
                                   includingCloudKit: NO ];
    }
#endif

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

# pragma mark - Termination

- ( void ) applicationWillTerminate: ( UIApplication * ) application
{
    [ DataManager.dataManager saveLocalContext ];
}

#pragma mark - Notifications

- ( void )                             application: ( UIApplication * ) application
  didRegisterForRemoteNotificationsWithDeviceToken: ( NSData        * ) deviceToken
{
    NSLog( @"Notifications: Registered successfully" );
}

- ( void )                             application: ( UIApplication * ) application
  didFailToRegisterForRemoteNotificationsWithError: ( NSError       * ) error
{
    NSLog( @"Notifications: Failed to register: %@", error );
}

- ( void )         application: ( UIApplication * ) application
  didReceiveRemoteNotification: ( NSDictionary  * ) userInfo
        fetchCompletionHandler: ( void ( ^ ) ( UIBackgroundFetchResult ) ) completionHandler
{
    CKNotification * notification = [ CKNotification notificationFromRemoteNotificationDictionary: userInfo ];

    NSLog( @"Notifications: Notification received" );

    if ( [ notification.subscriptionID isEqualToString: CLOUDKIT_SUBSCRIPTION_ID ] )
    {
        NSLog(@ "Notifications: Is a CloudKit change notification; calling DataManager" );

        [ DataManager.dataManager handleNotification: userInfo
                              fetchCompletionHandler: completionHandler ];
    }
    else
    {
        completionHandler( UIBackgroundFetchResultNoData );
    }
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

@end
