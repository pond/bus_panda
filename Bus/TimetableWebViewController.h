//
//  TimetableWebViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 3/04/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TimetableWebViewController : UIViewController <UIWebViewDelegate>

@property ( strong, nonatomic ) id                   detailItem;
@property ( weak,   nonatomic ) IBOutlet UIWebView * webView;

@end
