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

@end
