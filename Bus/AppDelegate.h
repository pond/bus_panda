//
//  AppDelegate.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WatchConnectivity/WatchConnectivity.h>

#import "MasterViewController.h"

@interface AppDelegate : UIResponder < UIApplicationDelegate,
                                       UISplitViewControllerDelegate,
                                       UITabBarControllerDelegate,
                                       WCSessionDelegate >

// Useful parts of the view hierarchy, established at startup

@property ( strong, nonatomic ) UIWindow               * window;
@property ( strong, nonatomic ) UITabBarController     * tabBarController;
@property ( strong, nonatomic ) UISplitViewController  * splitViewController;
@property ( strong, nonatomic ) UINavigationController * masterNavigationController;
@property ( strong, nonatomic ) UINavigationController * detailNavigationController;
@property ( strong, nonatomic ) MasterViewController   * masterViewController;

@end
