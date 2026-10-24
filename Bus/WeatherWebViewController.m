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

@interface WeatherWebViewController ()

// The weather provider whose content blocking rules were most recently
// compiled and installed; see -contentBlockingRules and -goHome.
//
@property ( strong, nonatomic ) NSString * rulesProvider;

@end

@implementation WeatherWebViewController

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    // Watch for user defaults changes as we'll need to reload the weather page
    // if someone changes their weather provider settings.
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
    if ( [ keyPath isEqualToString: WEATHER_PROVIDER ] )
    {
        // Only reload now if the page is on screen. Otherwise, -goHome
        // notices the change when the view next appears.
        //
        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                if ( self.isViewLoaded == YES && self.view.window != nil )
                {
                    [ self goHome ];
                }
            }
        );
    }
    else
    {
        [ super observeValueForKeyPath: keyPath
                              ofObject: object
                                change: change
                               context: context ];
    }
}

#pragma mark - Methods that the superclass requires

- ( void ) goHome
{
    NSString * provider = [ NSUserDefaults.standardUserDefaults stringForKey: WEATHER_PROVIDER ];

    // If the provider has changed since its content blocking rules were last
    // installed, install the new provider's rules first. That compiles them
    // via -contentBlockingRules, which records the new provider, then calls
    // back here, at which point the providers match and the page loads.
    //
    if ( ! [ provider ?: @"" isEqualToString: self.rulesProvider ?: @"" ] )
    {
        [ self reloadContentBlockingRulesAndGoHome ];
        return;
    }

    [ self spinnerOn ];

    if      ( [ provider isEqualToString: WEATHER_PROVIDER_WEATHERWATCH ] ) [ self visitWeatherWatch ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_ACCUWEATHER  ] ) [ self visitAccuWeather  ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WINDFINDER   ] ) [ self visitWindfinder   ];
    else                                                                    [ self visitMetService   ];
}


- ( NSString * ) contentBlockingRules
{
    NSString * provider = [ NSUserDefaults.standardUserDefaults stringForKey: WEATHER_PROVIDER ];

    self.rulesProvider = provider;

    if      ( [ provider isEqualToString: WEATHER_PROVIDER_WEATHERWATCH ] ) return [ self rulesForWeatherWatch ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_ACCUWEATHER  ] ) return [ self rulesForAccuWeather  ];
    else if ( [ provider isEqualToString: WEATHER_PROVIDER_WINDFINDER   ] ) return [ self rulesForWindfinder   ];
    else                                                                    return [ self rulesForMetService   ];
}

- ( NSString * ) errorTitle
{
    return @"Weather cannot be checked";
}

// YES if the Weather tab should show pages at full width - no sidebar.
//
- ( BOOL ) pageIgnoresSideSafeArea
{
    return YES;
}

// Windfinder's page uses "viewport-fit=cover". This must only depend on the
// provider, as a provider change always reinstalls content blocking rules,
// which is when the web view is set up for the new page.
//
- ( BOOL ) pageNeedsObscuredContentInsets
{
    NSString * provider = [ NSUserDefaults.standardUserDefaults stringForKey: WEATHER_PROVIDER ];
    return [ provider isEqualToString: WEATHER_PROVIDER_WINDFINDER ];
}

#pragma mark - Custom provider fetchers

// MetService:
// http://www.metservice.com/towns/wellington
//
- ( void ) visitMetService
{
    NSURL * url;

//    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
//    {
        url = [ NSURL URLWithString: @"https://www.metservice.com/towns-cities/wellington" ];
//    }
//    else
//    {
//        url = [ NSURL URLWithString: @"http://m.metservice.com/towns-cities/wellington" ];
//    }

    [ self.webView loadRequest: [ NSURLRequest requestWithURL: url ] ];
}

// Windfinder:
// https://www.windfinder.com/forecast/wellington
//
- ( void ) visitWindfinder
{
    NSURL * url = [ NSURL URLWithString: @"https://www.windfinder.com/forecast/wellington" ];
    [ self.webView loadRequest: [ NSURLRequest requestWithURL: url ] ];
}

// WeatherWatch:
// https://weatherwatch.co.nz/forecasts/Wellington
//
- ( void ) visitWeatherWatch
{
    NSURL * url = [ NSURL URLWithString: @"https://weatherwatch.co.nz/forecasts/Wellington" ];
    [ self.webView loadRequest: [ NSURLRequest requestWithURL: url ] ];
}

// AccuWeather:
// https://www.accuweather.com/web-api/three-day-redirect?lat=-41.294649&lon=174.772871
//
- ( void ) visitAccuWeather
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

            NSString     * url_str = [ NSString   stringWithFormat: @"https://www.accuweather.com/web-api/three-day-redirect?lat=%f&lon=%f", coordinates.latitude, coordinates.longitude ];
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
          \"selector\": \"iframe, [id^=google_ads], [data-slot-name=\\\"first\\\"], [data-module-name=\\\"current-conditions\\\"], [data-module-name=\\\"advert\\\"], #freshwidget-button, #FreshWidget, #ModalOverlay, #ModalComponent, .BannerAd, .Header, .Footer-section--promo, .BannerAd-wrapper, #google_image_div\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \"freshwidget\\\\.js\", \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"url-filter-is-case-sensitive\": true, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \"fuse\\\\.js\", \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"url-filter-is-case-sensitive\": true, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      }, \
      { \
        \"trigger\": { \
          \"url-filter\": \"adrum-.+\\\\.js\", \
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
          \"if-domain\": [ \"doubleclick.net\", \"facebook.net\", \"pubmatic.com\", \"appdynamics.com\", \"googletagservices.com\", \"googlesyndication.com\", \"google-analytics.com\", \"adservice.google.com\", \"adservice.google.co.nz\", \"fuseplatform.net\", \"amazon-adsystem.com\", \"imrworldwide.com\", \"criteo.net\", \"gtmss.metservice.com\" ], \
          \"resource-type\": [ \"script\" ] \
        }, \
        \"action\": { \
          \"type\": \"block\" \
        } \
      } \
    ]";
}

// Windfinder
//
- ( NSString * ) rulesForWindfinder
{
    return [ self rulesForGenericUntrustworthy ];
}

// WeatherWatch
//
- ( NSString * ) rulesForWeatherWatch
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
        \"selector\": \"[id^=google_ads], .top-bar-wrapper, .top-banner-ad, .ad-horizontal, .ad-sticky-bottom, #google_image_div\" \
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

// AccuWeather
//
- ( NSString * ) rulesForAccuWeather
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
        \"selector\": \"popup-banner, #google-center-div, .adsbygoogle, .glacier-ad, .adhesion-header, .has-adhesion, #gameSnacks, [id^=google_ads], .ad-horizontal, .ad-sticky-bottom, #google_image_div\" \
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

// Generic (currently only used for Windfinder).
//
- ( NSString * ) rulesForGenericUntrustworthy
{
    return @" \
    [ \
      { \
        \"trigger\": { \
          \"url-filter\": \".*\" \
        }, \
        \"action\": { \
          \"type\": \"css-display-none\", \
        \"selector\": \"[id^=google_ads], [data-ad-slot], [class^=da-]:has(> [data-ad-slot]), .top-banner-ad, #google-center-div, .ad-horizontal, .ad-sticky-bottom, #google_image_div\" \
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
