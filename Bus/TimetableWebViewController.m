//
//  TimetableWebViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 3/04/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "ErrorPresenter.h"
#import "TimetableWebViewController.h"

@implementation TimetableWebViewController

#pragma mark - Spinner

// Turn on an activity indicator of some sort. At the time of writing this
// comment, the network activity indicator in the status bar is used. See
// also -spinnerOff.
//
- ( void ) spinnerOn
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
}

// Turn off the activity indicator started with -spinnerOn.
//
- ( void ) spinnerOff
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
}

#pragma mark - View lifecycle

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];
    if ( _detailItem ) [ self configureView ];
}

- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ super viewWillDisappear: animated ];
    [ self spinnerOff ];
}

#pragma mark - Managing the detail item

// Detail item should be a parent detail view table row item (dictionary).

- ( void ) setDetailItem: ( id ) newDetailItem
{
    if ( _detailItem != newDetailItem )
    {
        _detailItem = newDetailItem;
        [ self configureView ];
    }
}

- ( void ) configureView
{
    if ( ! self.webView ) return; // Not "enough" of this resource has loaded yet

    NSString     * tPath   = [ _detailItem    objectForKey: @"timetablePath" ];
    NSString     * urlStr  = [ NSString   stringWithFormat: @"https://www.metlink.org.nz/%@", tPath ];
    NSURL        * url     = [ NSURL         URLWithString: urlStr ];
    NSURLRequest * request = [ NSURLRequest requestWithURL: url    ];

    [ self.webView loadRequest: request ];
}

#pragma mark - Optional UIWebViewDelegate delegate methods

- ( BOOL )           webView: ( UIWebView               * ) webView
  shouldStartLoadWithRequest: ( NSURLRequest            * ) request
              navigationType: ( UIWebViewNavigationType   )navigationType
{
    return YES;
}

- ( void ) webViewDidStartLoad: ( UIWebView * ) webView
{
    [ self spinnerOn ];
}

- ( void ) webViewDidFinishLoad: ( UIWebView * ) webView
{
    [ self spinnerOff ];
}

- ( void )     webView: ( UIWebView * ) webView
  didFailLoadWithError: ( NSError   * ) error
{
    [ self spinnerOff ];

    if ( error )
    {
        [
            ErrorPresenter showModalAlertFor: self
                                   withError: error
                                       title: @"Timetable not available"
                                  andHandler: ^( UIAlertAction *action )
            {
                [ self.navigationController popViewControllerAnimated: YES ];
            }
        ];
    }
}

@end
