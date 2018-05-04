//
//  WebPageAbstractViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 4/05/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface WebPageAbstractViewController : UIViewController <WKNavigationDelegate>

@property ( strong, nonatomic ) WKWebView               * webView;
@property ( strong, nonatomic ) UIActivityIndicatorView * activityView;

- ( void ) spinnerOn;
- ( void ) spinnerOff;

@end
