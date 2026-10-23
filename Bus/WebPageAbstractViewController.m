//
//  WebPageAbstractViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 4/05/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#import "ErrorPresenter.h"
#import "WebPageAbstractViewController.h"

@interface WebPageAbstractViewController ()

// YES once the view has appeared at least once; see -viewDidAppear:.
//
@property ( assign, nonatomic ) BOOL hasAppeared;

- ( void ) reportError: ( NSError * ) error;

@end

@implementation WebPageAbstractViewController

#pragma mark - Subclasses must implement...

// Fetch whatever the subclass considers the "home page" into self.webView.
//
- ( void ) goHome
{
    [ self doesNotRecognizeSelector: _cmd ];
}

// Return an NSString of JSON rules for content blocking, or 'nil' for none.
//
- ( NSString * ) contentBlockingRules
{
    [ self doesNotRecognizeSelector: _cmd ];
    return nil;
}

// Return an NSString giving the title for error popups.
//
- ( NSString * ) errorTitle
{
    return @"Information not available";
}

#pragma mark - Spinner

// Turn on an activity indicator of some sort. See also -spinnerOff.
//
- ( void ) spinnerOn
{
    [ self.activityView startAnimating ];
}

// Turn off the activity indicator started with -spinnerOn.
//
- ( void ) spinnerOff
{
    [ self.activityView stopAnimating ];
}

#pragma mark - Error reports

// Report an error from a web view navigation attempt. Ignores errors that
// only mean a navigation was superseded by a newer one, which then loads
// normally:
//
// - NSURLErrorDomain -999, NSURLErrorCancelled
// - WebKitErrorDomain 102, "Frame load interrupted" (policy change)
//
- ( void ) reportError: ( NSError * ) error
{
    if ( error == nil ) return;

    if ( [ error.domain isEqualToString: NSURLErrorDomain    ] && error.code == NSURLErrorCancelled ) return;
    if ( [ error.domain isEqualToString: @"WebKitErrorDomain" ] && error.code == 102                ) return;

    [ self spinnerOff ];

    [
        ErrorPresenter showModalAlertFor: self
                               withError: error
                                   title: [ self errorTitle ]
                              andHandler: ^( UIAlertAction *action )
        {
            [ self.navigationController popViewControllerAnimated: YES ];
        }
    ];
}

#pragma mark - View lifecycle

// When the view loads, create a WKWebView and UIActivityIndicatorView with
// frames that match and stretch to fit 'self.view'. Add them as subviews so
// that the activity view is on top of the web view, but hides when not
// animating; set a white opaque background. Turning on animation thus shows
// a 'full screen' activity indicator and can hide partial rendering or any
// hide-elements-via-JavaScript style hackery that might be going on in the
// web view beneath.
//
- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    WKWebViewConfiguration * configuration =
    [
        [ WKWebViewConfiguration alloc ] init
    ];

    configuration.dataDetectorTypes = WKDataDetectorTypeAll;

    self.webView =
    [
       [ WKWebView alloc ] initWithFrame: self.view.frame
                           configuration: configuration
    ];

    self.webView.navigationDelegate                  = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.autoresizingMask                    = UIViewAutoresizingFlexibleWidth |
                                                       UIViewAutoresizingFlexibleHeight;

    self.activityView =
    [
       [ UIActivityIndicatorView alloc ] initWithFrame: self.view.frame
    ];

    self.activityView.opaque                         = YES;
    self.activityView.backgroundColor                = UIColor.systemBackgroundColor;
    self.activityView.activityIndicatorViewStyle     = UIActivityIndicatorViewStyleMedium;
    self.activityView.hidesWhenStopped               = YES;
    self.activityView.autoresizingMask               = UIViewAutoresizingFlexibleWidth |
                                                       UIViewAutoresizingFlexibleHeight;

    self.view.autoresizesSubviews = YES;

    [ self.view addSubview: self.webView      ];
    [ self.view addSubview: self.activityView ];

    [ self reloadContentBlockingRulesAndGoHome ];
}

// The first load is started from -viewDidLoad, once content blocking rules
// are ready. Starting it here too used to race with that, giving spurious
// "Frame load interrupted" errors. Only later appearances reload, so that
// e.g. returning to the Weather tab still refreshes the forecast.
//
- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];

    if ( self.hasAppeared ) [ self goHome ];

    self.hasAppeared = YES;
}

- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ super viewWillDisappear: animated ];

    [ self spinnerOff ];
    [ self.webView stopLoading ];
}

#pragma mark - WKNavigationDelegate methods

- ( void )              webView: ( WKWebView    * ) webView
  didStartProvisionalNavigation: ( WKNavigation * ) navigation
{
    [ self spinnerOn ];
}

- ( void )    webView: ( WKWebView    * ) webView
  didCommitNavigation: ( WKNavigation * ) navigation
{
    [ self performSelector: @selector( spinnerOff )
                withObject: nil
                afterDelay: 1 ];
}

- ( void )             webView: ( WKWebView    * ) webView
  didFailProvisionalNavigation: ( WKNavigation * ) navigation
                     withError: ( NSError      * ) error
{
    [ self reportError: error ];
}

- ( void )  webView: ( WKWebView    * ) webView
  didFailNavigation: ( WKNavigation * ) navigation
          withError: ( NSError      * ) error
{
    [ self reportError: error ];
}

#pragma mark - Custom methods

// (Re)compile this view's content blocking rules, replace any previously
// installed rules with them, then load the home page. If compilation fails,
// the page is still loaded, just without content blocking.
//
- ( void ) reloadContentBlockingRulesAndGoHome
{
    [
        WKContentRuleListStore.defaultStore
            compileContentRuleListForIdentifier: @"ContentBlockingRules"
                         encodedContentRuleList: [ self contentBlockingRules ]
                              completionHandler: ^ ( WKContentRuleList * ruleList, NSError * error )
        {
            dispatch_async
            (
                dispatch_get_main_queue(),
                ^ ( void )
                {
                    WKUserContentController * controller = self.webView.configuration.userContentController;

                    [ controller removeAllContentRuleLists ];

                    if ( error == nil && ruleList != nil )
                    {
                        [ controller addContentRuleList: ruleList ];
                    }
                    else
                    {
                        NSLog( @"Content blocking rules failed to compile: %@", error );
                    }

                    [ self goHome ];
                }
            );
        }
    ];
}

@end
