//
//  TimetableWebViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 3/04/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "TimetableWebViewController.h"

@interface TimetableWebViewController ()

@end

@implementation TimetableWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if ( _detailItem ) [ self configureView ];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing the detail item

// Detail item should be a parent detail view table row item (dictionary).

- (void)setDetailItem:(id)newDetailItem {
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;

        // Update the view.
        [self configureView];
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

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

@end
