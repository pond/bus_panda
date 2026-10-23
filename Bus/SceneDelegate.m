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

// Under the scene lifecycle, -applicationWillTerminate: is rarely called,
// so save on entering the background instead.
//
- ( void ) sceneDidEnterBackground: ( UIScene * ) scene
{
    [ DataManager.dataManager saveLocalContext ];
}

@end
