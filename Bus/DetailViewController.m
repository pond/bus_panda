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
@property ( strong, nonatomic ) NSTimer          * autoRefresh;

- ( void ) showActivityViewer;
- ( void ) hideActivityViewer;

- ( void ) handleApiTaskResults:    ( NSMutableArray * ) sections;
- ( void ) handleScrapeTaskResults: ( NSMutableArray * ) sections;
- ( void ) mergeResults:            ( NSMutableArray * ) sections
           isScrapeResult:          ( BOOL             ) isScrapeResult;

@end

@implementation DetailViewController

// Back-end to -showActivityViewer; call on main thread only. The specific
// dance done here between threads, waiting and timers is necessary to get
// the right balance of the refresh control actually showing up, and hiding
// properly with a smooth animation later.
//
// After much experimentation, I was unable to get a delayed appearance of
// the refresh control, which I was doing in the hope that rapid-arriving
// results (e.g. from a cache) would cause the table view to populate more
// or less instantly and no distracting refresh control animations. In the
// end, this just didn't work, so the refresh control is always seen.
//
- ( void ) showActivityViewerBackend
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
    [ self.refreshControl beginRefreshing ];
}

// Show activity during a URL fetch.
//
// See also: -hideActivityViewer
//
- ( void ) showActivityViewer
{
    [ self performSelectorOnMainThread: @selector( showActivityViewerBackend )
                            withObject: nil
                         waitUntilDone: YES ];
}

// Back-end to -hideActivityViewer; call from main thread only. As with
// -showActivityViewerBackend, the specifics here are all related to always
// seeing the refresh control even for rapidly-arriving results. The small
// delay for hiding it makes things look less stupid than the table contents
// appearing to just jump down and up a little, with no time for the user to
// see the refresh control which caused it.
//
-( void ) hideActivityViewerBackend
{
    [ self.refreshControl performSelector: @selector( endRefreshing )
                               withObject: nil
                               afterDelay: 0.25 ];

    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
}

// Hide the activity indications shown by -showActivityViewer.
//
-( void ) hideActivityViewer
{
    [ self performSelectorOnMainThread: @selector( hideActivityViewerBackend )
                            withObject: nil
                         waitUntilDone: YES ];
}

#pragma mark - Managing the detail item

- ( void ) setDetailItem: ( id ) newDetailItem
{
    _detailItem = newDetailItem;
}

- ( void ) configureView
{
    if ( ! self.detailItem ) return;

    NSString * stopID          = [ self.detailItem valueForKey: @"stopID"          ];
    NSString * stopDescription = [ self.detailItem valueForKey: @"stopDescription" ];

    self.title = stopDescription;
    [ self showActivityViewer ];

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
    [ self mergeResults: sections isScrapeResult: NO ];
}

- ( void ) handleScrapeTaskResults: ( NSMutableArray * ) sections
{
    self.scrapeTask = nil;
    [ self mergeResults: sections isScrapeResult: YES ];
}

- ( void ) mergeResults: ( NSMutableArray * ) sections
         isScrapeResult: ( BOOL             ) isScrapeResult
{
    // The web scraper result will be more detailed and usually - but not
    // always - contain more entries than the API result. The scraper is
    // also used for auto-refresh, which may mean gradually less entries
    // at the end of a day if the next day doesn't have data (e.g. due to
    // looking at a weekday-only express listing on a Friday), so we have
    // to use this in preference to the API.
    //
    // So - if we have no data right now anyway, take whatever arrived.
    // Otherwise, assuming no error, use the data in full.

    NSLog( @"Handle results (is scrape - %d)", isScrapeResult );

    NSArray * thisServiceList = ( NSArray * ) sections.lastObject[ @"services" ];
    BOOL      thisIsAnError   = [ ( NSNumber * ) thisServiceList.firstObject[ @"error" ] boolValue ];

    if ( thisIsAnError )
    {
        NSLog( @"Bus information (is scrape - %d) error: %@", isScrapeResult, sections );
    }

    if ( self.parsedSections.count == 0 || ( isScrapeResult && thisIsAnError == NO ) )
    {
        // The API result might come in anyway as a race condition but try to
        // at least save a bit of CPU / network time by cancelling it if this
        // is the web scrape result.
        //
        if ( isScrapeResult )
        {
            NSURLSessionTask * task = self.apiTask;
            self.apiTask = nil;
            [ task cancel ];
        }
   
        self.parsedSections = sections;

        // For the refresh control hiding to work properly with smooth
        // animation, the table data MUST be reloaded *before* we hide
        // the activity viewer.
        //
        [ self.tableView reloadData ];
        [ self hideActivityViewer ];
    }
}

#pragma mark - View lifecycle

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    self.refreshControl = [ [ UIRefreshControl alloc ] init ];

    [ self.refreshControl addTarget: self
                             action: @selector( configureView )
                   forControlEvents: UIControlEventValueChanged ];

    [ self.tableView addSubview: self.refreshControl ];

    self.autoRefresh = [ NSTimer timerWithTimeInterval: 60.0
                                                target: self
                                              selector: @selector( doAutoRefresh )
                                              userInfo: nil
                                               repeats: YES ];

    [ [ NSRunLoop mainRunLoop ] addTimer: self.autoRefresh
                                 forMode: NSDefaultRunLoopMode ];

    [ self configureView ];
}

- ( void ) doAutoRefresh
{
    if ( self.scrapeTask != nil ) return;

    NSString * stopID = [ self.detailItem valueForKey: @"stopID" ];
    if ( stopID == nil ) return;

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

    [ [ NSOperationQueue mainQueue ] addOperationWithBlock: ^ { [ self.autoRefresh invalidate ]; } ];

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
