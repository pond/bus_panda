//
//  WeatherWebViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 3/05/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import "WeatherWebViewController.h"

#import "Constants.h"
#import "INTULocationManager.h"

// TODO: WUnderground and Weather.com disabled as experience is very poor.
//       See settings PList.

@implementation WeatherWebViewController

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    // Watch for user defaults changes as we'll need to reload the weather page
    // if someone changes their weather provider settings.
    //
    // Watch for user defaults changes as we'll need to reload the table data
    // to reflect a 'shorten names to fit' settings change.
    //
    NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;

    [ defaults addObserver: self
                forKeyPath: WEATHER_PROVIDER
                   options: NSKeyValueObservingOptionNew
                   context: nil ];
}

- ( void ) dealloc
{
    NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;
    [ defaults removeObserver: self forKeyPath: WEATHER_PROVIDER ];
}

// Called via KVO when the user defaults change.
//
- ( void ) observeValueForKeyPath: ( NSString     * ) keyPath
                         ofObject: ( id             ) object
                           change: ( NSDictionary * ) change
                          context: ( void         * ) context
{
    ( void ) object;
    ( void ) change;
    ( void ) context;

    if ( [ keyPath isEqualToString: WEATHER_PROVIDER ] )
    {
        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                if ( self.isViewLoaded == YES && self.view.window != nil )
                {
                    [ self reloadContentBlockingRulesAndGoHome ];
                }
            }
        );
    }
}

#pragma mark - Methods that the superclass requires

- ( void ) goHome
{
    [ self spinnerOn ];

    NSString * provider = [ NSUserDefaults.standardUserDefaults stringForKey: WEATHER_PROVIDER ];

    if      ( [ provider isEqualToString: WEATHER_PROVIDER_DARK_SKY     ] ) [ self visitDarkSky            ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WEATHER_COM  ] ) [ self visitWeatherCom         ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WUNDERGROUND ] ) [ self visitWeatherUnderground ];
    else                                                                    [ self visitMetService         ];
}


- ( NSString * ) contentBlockingRules
{
    NSString * provider = [ NSUserDefaults.standardUserDefaults stringForKey: WEATHER_PROVIDER ];

    if      ( [ provider isEqualToString: WEATHER_PROVIDER_DARK_SKY     ] ) return [ self rulesForDarkSky            ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WEATHER_COM  ] ) return [ self rulesForWeatherCom         ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WUNDERGROUND ] ) return [ self rulesForWeatherUnderground ];
    else                                                                    return [ self rulesForMetService         ];
}

- ( NSString * ) errorTitle
{
    return @"Weather cannot be checked";
}

#pragma mark - Custom provider fetchers

// MetService:
// http://m.metservice.com/towns/wellington
//
- ( void ) visitMetService
{
    NSURL * url;

    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        url = [ NSURL URLWithString: @"https://www.metservice.com/towns-cities/wellington" ];
    }
    else
    {
        url = [ NSURL URLWithString: @"http://m.metservice.com/towns-cities/wellington" ];
    }

    [ self.webView loadRequest: [ NSURLRequest requestWithURL: url ] ];
}

// Dark Sky
// https://darksky.net/forecast/-41.3135,174.776/ca12/en
//
- ( void ) visitDarkSky
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

// Weather.com
// https://weather.com/en-NZ/weather/hourbyhour/l/-41.3135,174.776
//
- ( void ) visitWeatherCom
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

            NSString     * url_str = [ NSString   stringWithFormat: @"https://weather.com/en-NZ/weather/hourbyhour/l/%f,%f", coordinates.latitude, coordinates.longitude ];
            NSURL        * url     = [ NSURL         URLWithString: url_str ];
            NSURLRequest * request = [ NSURLRequest requestWithURL: url ];

            [ self.webView performSelectorOnMainThread: @selector( loadRequest: )
                                            withObject: request
                                         waitUntilDone: NO ];
        }
    ];
}

// Weather Underground
// https://www.wunderground.com/weather/en/wellington/-41.3135%2C174.776
//
- ( void ) visitWeatherUnderground
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

            NSString     * url_str = [ NSString   stringWithFormat: @"https://www.wunderground.com/weather/en/wellington/%f%%2C%f", coordinates.latitude, coordinates.longitude ];
            NSURL        * url     = [ NSURL         URLWithString: url_str ];
            NSURLRequest * request = [ NSURLRequest requestWithURL: url ];

            [ self.webView performSelectorOnMainThread: @selector( loadRequest: )
                                            withObject: request
                                         waitUntilDone: NO ];
        }
    ];
}

#pragma mark - Custom provider content blocking rules

// MetService
//
- ( NSString * ) rulesForMetService
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
        \"selector\": \".mob-adspace, .mob-footer, .mobil-logo, .advertisement, #header-promos, #google_image_div\" \
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
          \"if-domain\": [ \"doubleclick.net\", \"facebook.net\", \"googletagservices.com\", \"googlesyndication.com\", \"google-analytics.com\", \"adservice.google.com\", \"adservice.google.co.nz\", \"newrelic.com\", \"pubmatic.com\", \"rubiconproject.com\", \"ampproject.org\", \"adsafeprotected.com\" ], \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      } \
    ]";
}

// Dark Sky
//
- ( NSString * ) rulesForDarkSky
{
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
}

// Weather.com
//
- ( NSString * ) rulesForWeatherCom
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
          \"selector\": \".wx-adWrapper, .ad_module, .adsbygoogle, .region.region-top.hourly\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\", \
          \"if-domain\": [ \"adservice.google.co.nz\", \"adservice.google.com\", \"googletagservices.com\", \"google-analytics.com\", \"amazon-adsystem.com\", \"doubleclick.net\", \"newrelic.com\", \"googlesyndication.com\", \"googlesyndication.com\" ], \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      } \
    ]";
}

// Weather Underground
//
- ( NSString * ) rulesForWeatherUnderground
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
          \"selector\": \".ad-wrap, .ad-mobile, .region-favorites-bar\" \
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
