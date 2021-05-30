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
#import "BackgroundColourCalculator.h"

#import "UsefulTypes.h"

#import "Bus_Panda-Swift.h"

@interface DetailViewController ()

@property ( strong, nonatomic ) NSURLSessionTask * apiTask;
@property ( strong, nonatomic ) NSMutableArray   * parsedSections;
@property ( strong, nonatomic ) UIRefreshControl * refreshControl;
@property ( strong, nonatomic ) NSTimer          * autoRefresh;

- ( void ) showActivityViewer;
- ( void ) hideActivityViewer;

- ( void ) handleApiTaskResults:    ( NSMutableArray * ) sections;
- ( void ) mergeResults:            ( NSMutableArray * ) sections;

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

    // Kick off fetcher tasks for the API.
    //
    self.parsedSections = nil;
    self.apiTask        =
    [
        BusInfoFetcher getAllBusesForStop: stopID
                        completionHandler: ^ ( NSMutableArray * sections )
        {
            [ self handleApiTaskResults: sections ];
        }
    ];
}

- ( void ) handleApiTaskResults: ( NSMutableArray * ) sections
{
    self.apiTask = nil;
    [ self mergeResults: sections ];
}

- ( void ) mergeResults: ( NSMutableArray * ) sections
{
    NSArray * thisServiceList = ( NSArray * ) sections.lastObject[ @"services" ];
    BOOL      thisIsAnError   = [ ( NSNumber * ) thisServiceList.firstObject[ @"error" ] boolValue ];

    if ( thisIsAnError )
    {
        NSLog( @"Bus information error: %@", sections );
        return;
    }

    self.parsedSections = sections;

    // For the refresh control hiding to work properly with smooth
    // animation, the table data MUST be reloaded *before* we hide
    // the activity viewer.
    //
    [ self.tableView reloadData ];
    [ self hideActivityViewer ];
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
    NSString * stopID = [ self.detailItem valueForKey: @"stopID" ];
    if ( stopID == nil ) return;

    self.apiTask =
    [
        BusInfoFetcher getAllBusesForStop: stopID
                        completionHandler: ^ ( NSMutableArray * sections )
        {
            [ self handleApiTaskResults: sections ];
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

    [ self.apiTask cancel ];

    self.apiTask = nil;
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

        UIColor * backgroundColor;

        if (@available(iOS 13, *))
        {
            backgroundColor = [ UIColor systemBackgroundColor ];
        }
        else
        {
            backgroundColor = [ UIColor whiteColor ];
        }

        sdc.number.backgroundColor = backgroundColor;
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

    // Dark mode - if the background is pure black, invert it to white in dark
    // mode by using semantic colour 'labelColor'.
    //
    if (@available(iOS 13, *))
    {
        if ( [ colour isEqualToString: @"000000" ] )
        {
            background = [ UIColor labelColor ];
        }
    }

    sdc.number.backgroundColor = background;
    sdc.number.textColor       = [ BackgroundColourCalculator foregroundFromBackground: background ];
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
