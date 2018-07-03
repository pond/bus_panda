//
//  AppDelegate.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"
#import "DataManager.h"
#import "DetailViewController.h"
#import "MasterViewController.h"
#import "StopMapViewController.h"
#import "BusInfoFetcher.h"
#import "NearestStopBusInfoFetcher.h"

@implementation AppDelegate

# pragma mark - Initialisation

- ( BOOL )          application: ( UIApplication * ) application
  didFinishLaunchingWithOptions: ( NSDictionary  * ) launchOptions
{
    NSUserDefaults * defaults = [ NSUserDefaults standardUserDefaults ];

    [ application registerForRemoteNotifications ];

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
    self.masterViewController = ( MasterViewController * ) self.masterNavigationController.topViewController;

    // Wake up local Core Data and iCloud. This also registers for remote
    // notifications (for CloudKit changes), but the AppDelegate object has
    // to handle them - see -didReceiveRemoteNotification:... later.
    //
    [ DataManager.dataManager setMasterViewController: self.masterViewController ];
    [ DataManager.dataManager awakenAllStores ];

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

    // If this is the first time the application has ever been run, set up a
    // collection of predefined useful stops.
    //
    BOOL hasRunBefore = [ defaults boolForKey: APP_HAS_RUN_BEFORE ];

    if ( hasRunBefore != YES )
    {
        [ defaults setBool: YES forKey: APP_HAS_RUN_BEFORE ];

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

# pragma mark - Termination

- ( void ) applicationWillTerminate: ( UIApplication * ) application
{
    [ DataManager.dataManager saveContext ];
}

#pragma mark - Notifications

- ( void )         application: ( UIApplication * ) application
  didReceiveRemoteNotification: ( NSDictionary  * ) userInfo
        fetchCompletionHandler: ( void ( ^ ) ( UIBackgroundFetchResult ) ) completionHandler
{
    [ DataManager.dataManager handleNotification: userInfo
                          fetchCompletionHandler: completionHandler ];
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

@end
