//
//  DetailViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "HTMLReader.h"

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "BusInfoFetcher.h"
#import "ServiceDescriptionCell.h"
#import "TimetableWebViewController.h"

#import "UsefulTypes.h"

#import "Bus_Panda-Swift.h"

@interface DetailViewController ()

@property ( strong, nonatomic ) NSURLSessionTask * apiTask;
@property ( strong, nonatomic ) NSURLSessionTask * scrapeTask;
@property ( strong, nonatomic ) NSMutableArray   * parsedSections;

@property ( strong, nonatomic ) UIRefreshControl * refreshControl;
@property ( strong, nonatomic ) UIView           * activityView;

- ( void ) showActivityViewer;
- ( void ) hideActivityViewer;

- ( void ) handleApiTaskResults:    ( NSMutableArray * ) sections;
- ( void ) handleScrapeTaskResults: ( NSMutableArray * ) sections;
- ( void ) mergeResults:            ( NSMutableArray * ) sections;

@end

@implementation DetailViewController

// This shows a full-screen modal activity spinner which stops the user doing
// actions in the underlying application that might result in state confusion.
//
// See also: -hideActivityViewer
//
- ( void ) showActivityViewer
{
    if ( self.activityView ) return;

    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;

    AppDelegate * delegate = ( AppDelegate * ) [ [ UIApplication sharedApplication ] delegate ];
    UIWindow    * window   = delegate.window;

    self.activityView =
    [
        [ UIView alloc ] initWithFrame: CGRectMake( 0,
                                                    0,
                                                    window.bounds.size.width,
                                                    window.bounds.size.height )
    ];

    self.activityView.backgroundColor = [ UIColor blackColor ];
    self.activityView.alpha           = 0.5;

    UIActivityIndicatorView * activityWheel =
    [
       [ UIActivityIndicatorView alloc ] initWithFrame: CGRectMake( window.bounds.size.width  / 2 - 12,
                                                                    window.bounds.size.height / 2 - 12,
                                                                    24,
                                                                    24 )
    ];

    activityWheel.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    activityWheel.autoresizingMask           = ( UIViewAutoresizingFlexibleLeftMargin  |
                                                 UIViewAutoresizingFlexibleRightMargin |
                                                 UIViewAutoresizingFlexibleTopMargin   |
                                                 UIViewAutoresizingFlexibleBottomMargin );

    [ self.activityView addSubview: activityWheel ];
    [ window addSubview: self.activityView ];

    [ [ [ self.activityView subviews ] objectAtIndex: 0 ] startAnimating ];
}

// For details, see -showActivityViewer.
//
-( void ) hideActivityViewer
{
    if ( ! self.activityView ) return;

    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;

    [ self.activityView removeFromSuperview ];
    [ [ [ self.activityView subviews ] objectAtIndex: 0 ] stopAnimating ];

    self.activityView = nil;
}

#pragma mark - Managing the detail item

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
    if ( ! self.detailItem ) return;
    if ( self.activityView != nil ) return;

    NSString * stopID          = [ self.detailItem valueForKey: @"stopID"          ];
    NSString * stopDescription = [ self.detailItem valueForKey: @"stopDescription" ];

    self.title = stopDescription;
    if ( self.refreshControl.refreshing == NO ) [ self showActivityViewer ];

    // Kick off fetcher tasks for both the API and the web scraper.
    //
    self.parsedSections = nil;
    self.apiTask        =
    [
        BusInfoFetcher getAllBusesForStop: stopID
              usingWebScraperInsteadOfAPI: NO
                        completionHandler: ^ ( NSMutableArray * sections )
        {
            [ self handleApiTaskResults: sections ];
        }
    ];

    self.scrapeTask =
    [
        BusInfoFetcher getAllBusesForStop: stopID
              usingWebScraperInsteadOfAPI: YES
                        completionHandler: ^ ( NSMutableArray * sections )
        {
            [ self handleScrapeTaskResults: sections ];
        }
    ];
}

- ( void ) handleApiTaskResults: ( NSMutableArray * ) sections
{
    self.apiTask = nil;
    [ self mergeResults: sections ];
}

- ( void ) handleScrapeTaskResults: ( NSMutableArray * ) sections
{
    self.scrapeTask = nil;
    [ self mergeResults: sections ];
}

- ( void ) mergeResults: ( NSMutableArray * ) sections
{
    // If there are no parsed sections stored locally yet, then just take
    // what we were given. Otherwise, have to merge the results.
    //
    if ( self.parsedSections == nil || self.parsedSections.count == 0 )
    {
        self.parsedSections = sections;

        [ self hideActivityViewer ];
        [ self.refreshControl endRefreshing ];
        [ self.tableView      reloadData    ];

        // NOTE EARLY EXIT to reduce unnecessary code indentation in a
        // simple either-or method.
        //
        return;
    }

    // This will all cascade through with "nil" if there are no sections or
    // services, since we'd be just sending messages to "nil" at each step.
    //
    NSDictionary * firstSection  = [ sections firstObject ];
    NSArray      * firstServices = [ firstSection objectForKey: @"services" ];
    NSDictionary * firstService  = [ firstServices firstObject ];

    // Since we already have some parsed sections present by this point,
    // then either that's showing an error already, or it was successful.
    // Either way, we can ignore the new data if it's just an error case.
    //
    if ( [ firstService objectForKey: @"error" ] == nil )
    {
        // Enumerate over the existing sections and the new sections.
        // For any item count greater in the new data, append the new
        // items. This is a very simple heuristic and risks duplicates
        // or omissions if the bus count changes / things shift between
        // sections due to ETA alterations around the midnight threshold,
        // but since we're only likely to be talking about stuff beyond
        // the API's 20 item limit then this is unlikely to be an issue
        // and is less troublesome than complex heuristics attempting to
        // match services exactly (the web scraper has no access to a
        // unique service ID, unlike the API).

        [
            sections enumerateObjectsWithOptions: NSEnumerationConcurrent
                                      usingBlock: ^ ( NSDictionary * newSection,
                                                      NSUInteger     index,
                                                      BOOL         * _Nonnull stop )
            {
                if ( index < self.parsedSections.count )
                {
                    NSDictionary   * existingSection  = self.parsedSections[ index ];
                    NSMutableArray * existingServices = existingSection[ @"services" ];
                    NSArray        *      newServices =      newSection[ @"services" ];

                    if ( newServices.count > existingServices.count )
                    {
                        NSUInteger   offset        = existingServices.count;
                        NSUInteger   count         = newServices.count - offset;
                        NSArray    * servicesToAdd = [ newServices subarrayWithRange: NSMakeRange( offset, count ) ];

                        [ existingServices addObjectsFromArray: servicesToAdd ];
                    }
                }
                else
                {
                    [ self.parsedSections addObject: newSection ];
                }
            }
        ];

        [ self.tableView reloadData ];
    }
}

#pragma mark - View lifecycle

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    // Pull-to-refresh

    self.refreshControl = [ [ UIRefreshControl alloc ] init ];

    [ self.refreshControl addTarget: self
                             action: @selector( configureView )
                   forControlEvents: UIControlEventValueChanged ];

    [ self.tableView addSubview: self.refreshControl ];

    // Populate the table

    [ self configureView ];
}

// http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];
    [ self.tableView deselectRowAtIndexPath: [ self.tableView indexPathForSelectedRow ]
                                   animated: animated ];
}

- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ super viewWillDisappear: animated ];

    [ self.apiTask    cancel ];
    [ self.scrapeTask cancel ];

    self.apiTask = self.scrapeTask = nil;
}

#pragma mark - Table View

- ( NSInteger ) numberOfSectionsInTableView: ( UITableView * ) tableView
{
    return [ self.parsedSections count ];
}

- ( NSInteger ) tableView: ( UITableView * ) tableView
    numberOfRowsInSection: ( NSInteger     ) section
{
    return [ self.parsedSections[ section ][ @"services" ] count ];
}

- ( UITableViewCell * ) tableView: ( UITableView * ) tableView
            cellForRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    UITableViewCell * cell = [ tableView dequeueReusableCellWithIdentifier: @"ServiceCell"
                                                              forIndexPath: indexPath ];

    [ self configureCell: cell atIndexPath: indexPath ];

    return cell;
}

- ( BOOL ) tableView: ( UITableView * ) tableView canEditRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    return NO;
}

// Don't bother showing a section title for "Today" in any view; call here
// to ask if the first section is for that. Returns YES if so else NO.
//
- ( BOOL ) firstSectionIsForToday
{
    return [ self.parsedSections[ 0 ][ @"title" ] isEqualToString: TODAY_SECTION_TITLE ]
           ? YES : NO;
}

- ( UIView * ) tableView: ( UITableView * ) tableView
  viewForHeaderInSection: ( NSInteger     ) section
{
    if ( section == 0 && [ self firstSectionIsForToday ] ) return nil;

    UIView  * cell  = [ tableView dequeueReusableCellWithIdentifier: @"SectionHeader" ];
    UILabel * label = ( UILabel * )[ cell viewWithTag: 1 ];

    [ label setText: self.parsedSections[ section ][ @"title" ] ];

    return cell;
}

- ( CGFloat )    tableView: ( UITableView * ) tableView
  heightForHeaderInSection: ( NSInteger     ) section
{
    if ( section == 0 && [ self firstSectionIsForToday ] ) return 0.0;

    UIView * cell = [ tableView dequeueReusableCellWithIdentifier: @"SectionHeader" ];
    return [ cell bounds ].size.height;
}

- ( void ) configureCell: ( UITableViewCell * ) cell
             atIndexPath: ( NSIndexPath     * ) indexPath
{
    ServiceDescriptionCell * sdc      = ( ServiceDescriptionCell * ) cell;
    NSUInteger               section  = indexPath.section;
    NSUInteger               row      = indexPath.row;
    NSArray                * services = self.parsedSections[ section ][ @"services" ];

    if ( row > services.count )
    {
        sdc.number.text = @"";
        sdc.name.text   = @"";
        sdc.when.text   = @"";

        sdc.number.backgroundColor = [ UIColor whiteColor ];

        return;
    }

    NSDictionary * entry  = ( NSDictionary * ) services[ row ];

    NSString     * colour = entry[ @"colour" ];
    NSString     * number = entry[ @"number" ];
    NSString     * name   = entry[ @"name"   ];
    NSString     * when   = entry[ @"when"   ];

    sdc.number.text = number;
    sdc.name.text   = name;
    sdc.when.text   = when;

    UIColor * background = [ RouteColours colourFromHexString: colour ];

    sdc.number.backgroundColor = background;

    // http://stackoverflow.com/questions/19456288/text-color-based-on-background-image

    CGFloat red, green, blue, alpha;
    int threshold = 105;

    [ background getRed: &red green: &green blue: &blue alpha: &alpha ];

    int bgDelta = ((red * 0.299) + (green) * 0.587) + (blue * 0.114);

    UIColor * foreground = (255 - bgDelta < threshold) ? [UIColor blackColor] : [UIColor whiteColor];

    sdc.number.textColor = foreground;
}

#pragma mark - Segues

- ( void ) prepareForSegue: ( UIStoryboardSegue * ) segue
                    sender: ( id                  ) sender
{
    if ( [ [ segue identifier ] isEqualToString: @"showTimetable" ] )
    {
        NSIndexPath * indexPath = [ self.tableView indexPathForSelectedRow ];
        NSUInteger    section   = indexPath.section;
        NSUInteger    row       = indexPath.row;
        NSArray     * services  = self.parsedSections[ section ][ @"services" ];

        // For timetables other than "today", the HTML from MetLink does not
        // include a date specifier. Might be a temporary bug, so we check for
        // that - but otherwise, we add it in.

        NSMutableDictionary * entry = [ NSMutableDictionary dictionaryWithDictionary: services[ row ] ];

        if (
               NO == [ self.parsedSections[ section ][ @"title" ] isEqualToString: TODAY_SECTION_TITLE ] &&
               NO == [ entry[ @"timetablePath" ] localizedCaseInsensitiveContainsString: @"?date" ]
           )
        {
            NSString * newPath =
            [
                NSString stringWithFormat: @"%@?date=%@",
                                           entry[ @"timetablePath" ],
                                           self.parsedSections[ section ][ @"title" ]
            ];

            newPath = [ newPath stringByAddingPercentEncodingWithAllowedCharacters: NSCharacterSet.URLQueryAllowedCharacterSet ];
            entry[ @"timetablePath" ] = newPath;
        }

        TimetableWebViewController * controller = ( TimetableWebViewController * ) [ segue destinationViewController ];
        [ controller setDetailItem: entry ];

        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

@end
