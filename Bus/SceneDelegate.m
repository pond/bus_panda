//
//  SceneDelegate.m
//  Bus Panda
//
//  UIScene lifecycle support, required for apps built against the iOS 27
//  SDK and later. Single-scene only; the AppDelegate still owns the useful
//  parts of the view hierarchy, notifications, Core Data and WatchKit.
//

#import "SceneDelegate.h"

#import "AppDelegate.h"
#import "DataManager.h"

// Minimum interval, in seconds, between on-foreground iCloud fetches; see
// -sceneWillEnterForeground:.
//
#define FOREGROUND_FETCH_MINIMUM_INTERVAL ( double ) 60

@interface SceneDelegate ()

// When the most recent on-foreground iCloud fetch was started, if any.
//
@property ( strong, nonatomic ) NSDate * lastForegroundFetch;

@end

@implementation SceneDelegate

- ( void )         scene: ( UIScene                  * ) scene
    willConnectToSession: ( UISceneSession           * ) session
                 options: ( UISceneConnectionOptions * ) connectionOptions
{
    if ( ! [ scene isKindOfClass: [ UIWindowScene class ] ] ) return;

    // UIKit has already loaded Main.storyboard into self.window, so the root
    // tab bar controller exists; hand the window to the AppDelegate, which
    // does what used to happen in -application:didFinishLaunchingWithOptions:.
    //
    AppDelegate * appDelegate = ( AppDelegate * ) UIApplication.sharedApplication.delegate;
    [ appDelegate configureForWindow: self.window ];
}

// Fetch any iCloud changes we might have missed while in the background.
// CloudKit's "something changed" pushes are silent and best-effort: iOS may
// delay or drop them (and the Simulator rarely gets them), so without this,
// edits made on other devices might not appear until a manual pull-to-
// refresh. Only changes since the last fetch are requested, so this is
// normally a small, quick request.
//
// Not called at launch - only on returning from the background - so it
// doesn't duplicate the start-up fetch in -[DataManager awakenAllStores].
// Skipped if iCloud isn't available, if that start-up fetch is still under
// way, or if the last on-foreground fetch was very recent.
//
- ( void ) sceneWillEnterForeground: ( UIScene * ) scene
{
    DataManager * dataManager = DataManager.dataManager;

    if ( dataManager.checkingICloud ) return;
    if ( ! [ NSUserDefaults.standardUserDefaults boolForKey: ICLOUD_IS_AVAILABLE ] ) return;

    if ( self.lastForegroundFetch != nil &&
         -self.lastForegroundFetch.timeIntervalSinceNow < FOREGROUND_FETCH_MINIMUM_INTERVAL )
    {
        return;
    }

    self.lastForegroundFetch = [ NSDate date ];

    NSLog( @"Foreground fetch: Checking iCloud for changes" );

    [
        dataManager fetchRecentChangesWithCompletionBlock: ^ ( NSError * _Nullable error )
        {
            if ( error != nil ) NSLog( @"Foreground fetch: Failed: %@", error );
        }
        ignoringPriorChangeToken: NO
    ];
}

// Under the scene lifecycle, -applicationWillTerminate: is rarely called,
// so save on entering the background instead.
//
- ( void ) sceneDidEnterBackground: ( UIScene * ) scene
{
    [ DataManager.dataManager saveLocalContext ];
}

@end
