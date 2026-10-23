//
//  SceneDelegate.h
//  Bus Panda
//
//  UIScene lifecycle support, required for apps built against the iOS 27
//  SDK and later. Single-scene only; the AppDelegate still owns the useful
//  parts of the view hierarchy, notifications, Core Data and WatchKit.
//

#import <UIKit/UIKit.h>

@interface SceneDelegate : UIResponder < UIWindowSceneDelegate >

// Created and assigned by UIKit from the storyboard named by the
// 'UISceneStoryboardFile' key in Info.plist, before -scene:willConnect...
// is called.
//
@property ( strong, nonatomic ) UIWindow * window;

@end
