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

// Whether the current web view was set up with obscured content insets; see
// -setUpWebViewForCurrentPage.
//
@property ( assign, nonatomic ) BOOL webViewUsesObscuredInsets;

- ( void ) reportError: ( NSError * ) error;

@end

// A web view that can ignore side safe area insets, so WebKit lays pages out
// across the full width with side bars (e.g. iPhone Duo's status bar and
// vertical bar column) overlaying them, as in Safari.
//
@interface SideInsetIgnoringWebView : WKWebView
@property ( assign, nonatomic ) BOOL ignoresSideInsets;
@end

@implementation SideInsetIgnoringWebView

- ( UIEdgeInsets ) safeAreaInsets
{
    UIEdgeInsets insets = super.safeAreaInsets;

    if ( self.ignoresSideInsets )
    {
        insets.left  = 0;
        insets.right = 0;
    }

    return insets;
}

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

// Return YES if the page about to be shown needs WebKit told what the bars
// cover (iOS 26+), e.g. because it uses "viewport-fit=cover" and would
// otherwise load hidden under the navigation bar. Default is NO.
//
- ( BOOL ) pageNeedsObscuredContentInsets
{
    return NO;
}

// Return YES to lay pages out across the full width, under any side bars,
// rather than within the side safe areas. Only suitable for views with no
// sidebar beside them. Default is NO.
//
- ( BOOL ) pageIgnoresSideSafeArea
{
    return NO;
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

    if ( [ error.domain isEqualToString: NSURLErrorDomain     ] && error.code == NSURLErrorCancelled ) return;
    if ( [ error.domain isEqualToString: @"WebKitErrorDomain" ] && error.code == 102                 ) return;

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

// When the view loads, create a full-view UIActivityIndicatorView with an
// opaque background, on top of the web view but hidden when not animating.
// Turning it on thus hides partial rendering, or any hide-elements-via-
// JavaScript style hackery going on in the web view beneath.
//
- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    self.activityView =
    [
       [ UIActivityIndicatorView alloc ] initWithFrame: self.view.bounds
    ];

    self.activityView.opaque                     = YES;
    self.activityView.backgroundColor            = UIColor.systemBackgroundColor;
    self.activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
    self.activityView.hidesWhenStopped           = YES;
    self.activityView.autoresizingMask           = UIViewAutoresizingFlexibleWidth |
                                                   UIViewAutoresizingFlexibleHeight;

    [ self.view addSubview: self.activityView ];

    [ self setUpWebViewForCurrentPage ];
    [ self reloadContentBlockingRulesAndGoHome ];
}

- ( void ) viewSafeAreaInsetsDidChange
{
    [ super viewSafeAreaInsetsDidChange ];
    [ self updateObscuredContentInsets ];
}

// The first load is started from -viewDidLoad, once content blocking rules
// are ready. Don't do that here too, as that'd fetch twice. We do need to load
// the page on subsequent re-appearances though, so that e.g. revisiting the
// Weather tab will reload the forecast.
//
- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];

    if ( self.hasAppeared ) [ self goHome ];
    else self.hasAppeared = YES;
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

// Create a web view suited to the page about to be shown, replacing any
// existing one if it was set up differently. Trying to change things like
// obscured inset values on an *existing* view doesn't work reliably, with
// pages ending up positioned incorrectly (e.g. the top edge of the page being
// hidden below the navigation bar is a common issue if moving from Windfinder
// to another provider).
//
- ( void ) setUpWebViewForCurrentPage
{
    BOOL useObscuredInsets = NO;

    if ( @available( iOS 26, * ) )
    {
        useObscuredInsets = [ self pageNeedsObscuredContentInsets ];
    }

    if ( self.webView != nil && useObscuredInsets == self.webViewUsesObscuredInsets ) return;

    if ( self.webView != nil )
    {
        [ self.webView stopLoading ];
        self.webView.navigationDelegate = nil;
        [ self.webView removeFromSuperview ];
    }

    WKWebViewConfiguration * configuration = [ [ WKWebViewConfiguration alloc ] init ];
    configuration.dataDetectorTypes        = WKDataDetectorTypeAll;

    SideInsetIgnoringWebView * webView =
    [
       [ SideInsetIgnoringWebView alloc ] initWithFrame: self.view.bounds
                                          configuration: configuration
    ];

    webView.ignoresSideInsets = [ self pageIgnoresSideSafeArea ];

    // Useful if you need to remotely examine the web view under simulation via
    // the host Mac's Safari's 'develop' menu for any reason.
    //
    #if DEBUG
        if ( @available( iOS 16.4, * ) )
        {
            webView.inspectable = YES;
        }
    #endif

    webView.navigationDelegate                        = self;
    webView.allowsBackForwardNavigationGestures       = YES;
    webView.translatesAutoresizingMaskIntoConstraints = NO;

    // Always pad the page by the safe area, so it starts below the bars
    // but can scroll beneath them. The default ("automatic") only does this
    // reliably for a view controller's main scroll view, but for others, like
    // this one inside the web view, it skips any direction the content can't
    // yet scroll, e.g. before a page has loaded.
    //
    webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;

    [ self.view insertSubview: webView belowSubview: self.activityView ];

    // On iOS 26+, fill the view so pages scroll under the Liquid Glass bars.
    // Earlier versions stay between the bars, as there's no way to position
    // "viewport-fit=cover" pages correctly beneath them.
    //
    UIView              * view   = self.view;
    NSLayoutYAxisAnchor * top    = view.safeAreaLayoutGuide.topAnchor;
    NSLayoutYAxisAnchor * bottom = view.safeAreaLayoutGuide.bottomAnchor;

    if ( @available( iOS 26, * ) )
    {
        top    = view.topAnchor;
        bottom = view.bottomAnchor;
    }

    [
        NSLayoutConstraint activateConstraints:
        @[
            [ webView.leadingAnchor  constraintEqualToAnchor: view.leadingAnchor  ],
            [ webView.trailingAnchor constraintEqualToAnchor: view.trailingAnchor ],
            [ webView.topAnchor      constraintEqualToAnchor: top                 ],
            [ webView.bottomAnchor   constraintEqualToAnchor: bottom              ]
        ]
    ];

    // Lets the bars update their appearance as the page scrolls.
    //
    [ self setContentScrollView: webView.scrollView
                        forEdge: NSDirectionalRectEdgeAll ];

    self.webView                   = webView;
    self.webViewUsesObscuredInsets = useObscuredInsets;

    [ self updateObscuredContentInsets ];
}

// If the web view uses obscured insets, keep them matching the bars, so that
// WebKit positions pages and their fixed headers below them. Pages that don't
// need this avoid it, as WebKit also fills the area under the bars with the
// colour of any fixed header, to which the black navigation title can't adapt.
//
- ( void ) updateObscuredContentInsets
{
    if ( @available( iOS 26, * ) )
    {
        if ( self.webViewUsesObscuredInsets == NO ) return;

        UIEdgeInsets safeArea = self.view.safeAreaInsets;
        self.webView.obscuredContentInsets = UIEdgeInsetsMake( safeArea.top, 0, safeArea.bottom, 0 );
    }
}

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
                    // The new page may need a differently set up web view;
                    // do that first, so the rules go on the one that's used.
                    //
                    [ self setUpWebViewForCurrentPage ];

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
