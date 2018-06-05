//
//  WeatherWebViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 3/05/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import "WeatherWebViewController.h"

#import "INTULocationManager.h"

// "MetService" or "DarkSky"
//
#define WEATHER_SERVICE MetService

@implementation WeatherWebViewController

#pragma mark - Methods that the superclass requires

- ( void ) goHome
{
    [ self spinnerOn ];

#if WEATHER_SERVICE == MetService

    // MetService
    //
    NSURL        * url     = [ NSURL         URLWithString: @"http://m.metservice.com/towns/wellington" ];
    NSURLRequest * request = [ NSURLRequest requestWithURL: url ];

    [ self.webView loadRequest: request ];

#elif WEATHER_SERVICE == DarkSky

   // Dark Sky
   //
   dispatch_async
   (
       dispatch_get_main_queue(),
       ^ ( void )
       {
           INTULocationManager *locMgr = [ INTULocationManager sharedInstance ];

           [
               locMgr requestLocationWithDesiredAccuracy: INTULocationAccuracyCity
                                                 timeout: 2.5
                                    delayUntilAuthorized: NO
                                                   block:

               ^ ( CLLocation           * currentLocation,
                   INTULocationAccuracy   achievedAccuracy,
                   INTULocationStatus     status )
               {
                   CLLocationCoordinate2D coordinates;

                   if ( status == INTULocationStatusSuccess )
                   {
                       coordinates = currentLocation.coordinate;
                   }
                   else // Just give up and assume Wellington Central
                   {
                       coordinates.latitude  = -41.294649;
                       coordinates.longitude = 174.772871;
                   }

                   NSString     * url_str = [ NSString   stringWithFormat: @"https://darksky.net/forecast/%f,%f/ca12/en", coordinates.latitude, coordinates.longitude ];
                   NSURL        * url     = [ NSURL         URLWithString: url_str ];
                   NSURLRequest * request = [ NSURLRequest requestWithURL: url ];

                   [ self.webView performSelectorOnMainThread: @selector( loadRequest: )
                                                   withObject: request
                                                waitUntilDone: NO ];
               }
           ];
       }
   );

#else
#error Invalid 'WEATHER_SERVICE' value
#endif
}

- ( NSString * ) contentBlockingRules
{

#if WEATHER_SERVICE == MetService

    // MetService:
    // http://m.metservice.com/towns/wellington
    //
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
          \"selector\": \".mob-adspace, .mob-footer, .mobil-logo\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \"\\/special\\/mobile-add-service\\\\.js\", \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"url-filter-is-case-sensitive\": true, \
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

#elif WEATHER_SERVICE == DarkSky

    // Dark Sky:
    // https://darksky.net/forecast/-41.3135,174.776/ca12/en
    //
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
          \"selector\": \"div#sms, div#map-container, div#timeMachine, div#footer, nav\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\", \
          \"if-domain\": [ \"maps.darksky.net\" ] \
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

#else
#error Invalid 'WEATHER_SERVICE' value
#endif
}

- ( NSString * ) errorTitle
{
    return @"Weather cannot be checked";
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
