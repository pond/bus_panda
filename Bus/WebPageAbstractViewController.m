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

- ( void ) reportError: ( NSError * ) error;

@end

@implementation WebPageAbstractViewController

static NSString * contentBlockingRules = @"";

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

// Turn on an activity indicator of some sort. At the time of writing this
// comment, the network activity indicator in the status bar is used. See
// also -spinnerOff.
//
- ( void ) spinnerOn
{
    [ self.activityView startAnimating ];
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
}

// Turn off the activity indicator started with -spinnerOn.
//
- ( void ) spinnerOff
{
    [ self.activityView stopAnimating ];
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
}

#pragma mark - Error reports

// Report an error from a web view navigation attempt; ignores spurious
// NSURLErrorDomain code -999 errors that iOS seems to just generate now
// and again, since pages appear to load fine regardless of this.
//
- ( void ) reportError: ( NSError * ) error
{
    if ( error && ( ! [ error.domain isEqualToString: NSURLErrorDomain ] || error.code != -999 ) )
    {
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
    self.activityView.backgroundColor                = [ UIColor whiteColor ];
    self.activityView.activityIndicatorViewStyle     = UIActivityIndicatorViewStyleGray;
    self.activityView.hidesWhenStopped               = YES;
    self.activityView.autoresizingMask               = UIViewAutoresizingFlexibleWidth |
                                                       UIViewAutoresizingFlexibleHeight;

    self.view.autoresizesSubviews = YES;

    [ self.view addSubview: self.webView      ];
    [ self.view addSubview: self.activityView ];

    NSString * contentBlockingRules = [ self contentBlockingRules ];

    if ( @available( iOS 11, * ) )
    {
        [
            WKContentRuleListStore.defaultStore
                compileContentRuleListForIdentifier: @"ContentBlockingRules"
                             encodedContentRuleList: contentBlockingRules
                                  completionHandler: ^ ( WKContentRuleList * ruleList, NSError * error )
            {
                [ super viewDidLoad ];

                if ( error == nil )
                {
                    [ self.webView.configuration.userContentController addContentRuleList: ruleList ];
                    [ self goHome ];
                }
            }
        ];
    }
    else
    {
        [ self goHome ];
    }
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self goHome ];
}

- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ self spinnerOff ];
    [ super viewWillDisappear: animated ];
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

@end
