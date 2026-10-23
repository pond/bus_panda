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

#pragma mark - Methods that the superclass requires

- ( void ) goHome
{
    if ( ! _detailItem ) return;

    NSString     * tPath   = [ _detailItem    objectForKey: @"timetablePath" ];
    NSString     * urlStr  = [ NSString   stringWithFormat: @"https://www.metlink.org.nz/%@", tPath ];
    NSURL        * url     = [ NSURL         URLWithString: urlStr ];
    NSURLRequest * request = [ NSURLRequest requestWithURL: url    ];

    [ self.webView loadRequest: request ];
}

- ( NSString * ) contentBlockingRules
{
    return @" \
    [ \
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

- ( NSString * ) errorTitle
{
    return @"Timetable cannot be fetched";
}

#pragma mark - Managing the detail item

// Detail item should be a parent detail view table row item (dictionary).
//
- ( void ) setDetailItem: ( id ) newDetailItem
{
    if ( _detailItem != newDetailItem )
    {
        _detailItem = newDetailItem;
        [ self goHome ];
    }
}

#pragma mark - Split view support

// The split view's display mode button ("show/hide the list") only means
// anything when the split view is expanded, e.g. on iPad. When collapsed
// (iPhone; a narrow iPad window; possibly a folded iPhone Duo) it has no
// content, but on iOS 26+ an empty item still draws an empty Liquid Glass
// capsule next to the Back button. So only show it when expanded, and
// re-evaluate whenever the split view might collapse or expand.
//
- ( void ) updateDisplayModeButton
{
    UISplitViewController * split = self.splitViewController;

    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem             = ( split != nil && split.isCollapsed == NO )
                                                      ? split.displayModeButtonItem
                                                      : nil;
}

- ( void ) viewWillTransitionToSize: ( CGSize ) size
          withTransitionCoordinator: ( id <UIViewControllerTransitionCoordinator> ) coordinator
{
    [ super viewWillTransitionToSize: size withTransitionCoordinator: coordinator ];

    [
        coordinator animateAlongsideTransition: nil
                                    completion: ^ ( id <UIViewControllerTransitionCoordinatorContext> context )
        {
            [ self updateDisplayModeButton ];
        }
    ];
}

- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];
    [ self updateDisplayModeButton ];
}

@end
