//
//  WeatherWebViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 3/05/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import "WeatherWebViewController.h"

@implementation WeatherWebViewController

#pragma mark - Methods that the superclass requires

- ( void ) goHome
{
    [ self spinnerOn ];

    NSURL        * url     = [ NSURL         URLWithString: @"http://m.metservice.com/towns/wellington" ];
    NSURLRequest * request = [ NSURLRequest requestWithURL: url ];

    [ self.webView loadRequest: request ];
}

- ( NSString * ) contentBlockingRules
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
          \"selector\": \".mob-adspace, .mob-footer\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \"\\/sites\\/all\\/themes\\/mobile\\/css\\/.*\", \
          \"resource-type\": [ \"style-sheet\" ] \
        }, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\", \
          \"if-domain\": [ \"doubleclick.net\", \"facebook.net\", \"googletagservices.com\", \"google-analytics.com\", \"newrelic.com\" ], \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      } \
    ]";
}

#pragma mark - WKNavigationDelegate methods

// This is how we could perform some of the hiding behaviour on iOS < 11.
//
//- ( void )    webView: ( WKWebView    * ) webView
//  didCommitNavigation: ( WKNavigation * ) navigation
//{
//    [ self.webView evaluateJavaScript: @"function hideThings() { document.getElementsByClassName('mob-adspace')[0].style.display='none'; }; document.addEventListener('DOMContentLoaded', hideThings, false);"
//                    completionHandler: nil ];
//
//    [ super webView: webView didCommitNavigation: navigation ];
//}

#pragma mark - Unfinished; maybe one day; seems unnecessary given load-on-show

// Would also need something like:
//
//    [ self.refreshControl endRefreshing ];
//
// ...in -webView:didCommitNavigation:.
//
//- ( void ) refreshView: ( UIRefreshControl * ) sender
//{
//    [ self.webView reload ];
//}
//
//- ( void ) viewDidLoad
//{
//    [ super viewDidLoad ];
//
//    self.refreshControl = [ [ UIRefreshControl alloc ] init ];
//
//    [ self.refreshControl addTarget: self
//                             action: @selector( refreshView: )
//                   forControlEvents: UIControlEventValueChanged ];
//
//    [ self.webView.scrollView addSubview: self.refreshControl ];
//}

@end
