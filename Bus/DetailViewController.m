//
//  DetailViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "HTMLReader.h"

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "ServiceDescriptionCell.h"
#import "TimetableWebViewController.h"

@interface DetailViewController ()
@property ( strong, nonatomic ) NSMutableArray   * parsedSections;
@property ( strong, nonatomic ) UIRefreshControl * refreshControl;
@property ( strong, nonatomic ) UIView           * activityView;
@end

// Text tile for the 'Today' section, if present.
//
#define TODAY_SECTION_TITLE @"Today"

@implementation DetailViewController

static NSDictionary * routeColours = nil;

// http://stackoverflow.com/questions/22534251/static-nsdictionary-const-lettervalues-in-a-method-does-not-compil
//
- ( void ) awakeFromNib
{
    [ super awakeFromNib ];

    static dispatch_once_t onceToken;

    // From October 2015: MetLink's revised web site is boring and grey!
    // It includes no colours in the realtime service tables, so we have
    // to store an internal hard-coded mapping instead. Deduced from:
    //
    // https://www.metlink.org.nz/getting-around/network-map/

    dispatch_once(
        &onceToken,
        ^{
            routeColours =
            @{
                // Wellington bus routes

                @"1":   @"942192",
                @"2":   @"DF2134",
                @"3":   @"7AC143",
                @"4":   @"532380",
                @"5":   @"F26531",
                @"6":   @"009B7A",
                @"7":   @"CE6E19",
                @"8":   @"CE6E19",
                @"9":   @"EE362A",
                @"10":  @"7C3420",
                @"11":  @"7C3420",
                @"13":  @"B15C12",
                @"14":  @"80A1B6",
                @"17":  @"79C043",
                @"18":  @"00BCE3",
                @"20":  @"00BCE3",
                @"21":  @"607118",
                @"22":  @"EE8B1A",
                @"23":  @"F5B50D",
                @"24":  @"0E3A2B",
                @"25":  @"00274B",
                @"28":  @"E7AC09",
                @"29":  @"047383",
                @"30":  @"722E1E",
                @"31":  @"DF2134",
                @"32":  @"971F85",
                @"43":  @"779AB0",
                @"44":  @"09B2E6",
                @"45":  @"00B1C7",
                @"46":  @"0073BB",
                @"47":  @"976114",
                @"50":  @"0C824D",
                @"52":  @"59922F",
                @"53":  @"DF6C1E",
                @"54":  @"C42168",
                @"55":  @"722F1E",
                @"56":  @"F07A23",
                @"57":  @"F0A96F",
                @"58":  @"C42168",
                @"91":  @"F29223",

                // Porirua bus routes

                @"97":  @"0096D6",
                @"210": @"7A1500",
                @"211": @"F37735",
                @"220": @"008952",
                @"226": @"0080B2",
                @"230": @"D31245",
                @"235": @"E7A614",
                @"236": @"872174",

                // Hutt Valley bus routes

                @"80":  @"092F56",
                @"81":  @"BF3119",
                @"83":  @"BA2D18",
                @"84":  @"BA2D18",
                @"85":  @"BA2D18",
                @"90":  @"A68977",
                @"92":  @"A68977",
                @"93":  @"A68977",
                @"110": @"9A4E9E",
                @"111": @"0065A3",
                @"112": @"72CDF3",
                @"114": @"B1BA1E",
                @"115": @"006F4A",
                @"120": @"54B948",
                @"121": @"0065A4",
                @"130": @"00ADEE",
                @"145": @"00788A",
                @"150": @"A20046",
                @"154": @"EF5091",
                @"160": @"E31837",
                @"170": @"878502",

                // Kapiti Coast bus routes

                @"250": @"00689E",
                @"260": @"570861",
                @"261": @"ED1D24",
                @"262": @"88AF65",
                @"270": @"F36F21",
                @"280": @"233E99",
                @"290": @"00A4E3",

                // Wairarapa bus routes

                @"200": @"EF5091",
                @"201": @"007B85",
                @"202": @"FDB913",
                @"203": @"7E81BE",
                @"204": @"B4CC95",
                @"205": @"72CDF4",
                @"206": @"DD0A61",

                // Just in case - train, cable car and ferry routes

                @"CCL": @"808285",
                @"WHF": @"13B6EA",
                @"HVL": @"000000",
                @"MEL": @"000000",
                @"JVL": @"000000",
                @"KPL": @"000000",
                @"WRL": @"000000",
            };
        }
    );
}

-(void)showActivityViewer
{
    if ( self.activityView ) return;

    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    UIWindow *window = delegate.window;
    self.activityView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height)];
    self.activityView.backgroundColor = [UIColor blackColor];
    self.activityView.alpha = 0.5;

    UIActivityIndicatorView *activityWheel = [[UIActivityIndicatorView alloc] initWithFrame: CGRectMake(window.bounds.size.width / 2 - 12, window.bounds.size.height / 2 - 12, 24, 24)];
    activityWheel.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    activityWheel.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleRightMargin |
                                      UIViewAutoresizingFlexibleTopMargin |
                                      UIViewAutoresizingFlexibleBottomMargin);
    [self.activityView addSubview:activityWheel];
    [window addSubview: self.activityView];

    [[[self.activityView subviews] objectAtIndex:0] startAnimating];
}

-(void)hideActivityViewer
{
    if ( ! self.activityView ) return;

    [[[self.activityView subviews] objectAtIndex:0] stopAnimating];
    [self.activityView removeFromSuperview];
    self.activityView = nil;
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem {
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
            
        // Update the view.
        [self configureView];
    }
}

// Clean up nesting in code inside method '-configureView' by assigning the
// URL competion handler block to a strongly typed variable.

typedef void ( ^ urlRequestCompletionHandler )( NSData        * data,
                                                NSURLResponse * response,
                                                NSError       * error);

- ( void ) configureView
{
    if ( ! self.detailItem ) return;
    if ( self.activityView != nil ) return;

    NSString * stopID = [ self.detailItem valueForKey: @"stopID" ];

    if ( self.refreshControl.refreshing == NO ) [ self showActivityViewer ];

    // Update the user interface for the detail item.
    //
    self.detailDescriptionLabel.text = stopID;

    // Create the URL we'll use to retrieve the realtime information.
    //
    NSString * stopInfoURL =
    [
        NSString stringWithFormat: @"https://www.metlink.org.nz/stop/%@/departures?more=1",
                                   stopID
    ];

    NSLog(@"STOP INFO: %@",stopInfoURL);

    // We will make a request to fetch the HTML at 'stopInfoURL' from above,
    // declearing the below block as the code to run upon completion (success
    // or failure).
    //
    // After this big chunk of code, at the end of this overall method, is the
    // place where the request is actually made.
    //
    urlRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        NSString * contentType = nil;

        if ( [ response isKindOfClass: [ NSHTTPURLResponse class ] ] )
        {
            NSDictionary *headers = [ ( NSHTTPURLResponse * )response allHeaderFields ];
            contentType = headers[ @"Content-Type" ];
        }

        HTMLDocument * home = [ HTMLDocument documentWithData: data
                                            contentTypeHeader: contentType];

        // The services are in an HTML table with each row representing an
        // individual service, or a section title with a date in it.

        HTMLElement * list     = [ home firstNodeMatchingSelector: @"div.rt-info-content table" ];
        NSArray     * services = [ list nodesMatchingSelector: @"tr" ];

        self.parsedSections = [ [ NSMutableArray alloc ] init ];

        NSMutableArray * currentServiceList = [ [ NSMutableArray alloc ] init ];

        for ( HTMLElement * service in services )
        {
            NSCharacterSet * whitespace = [ NSCharacterSet whitespaceAndNewlineCharacterSet ];

            // From October 2015:
            //
            // Added in the ability to define section tables by detecting the
            // row dividers. Table row of class 'rowDivider', with the sole
            // cell content containing what will become the section title.
            //
            // Info tables might start with a row divider for 'tomorrow', or
            // may have entries for 'today' without a divider first. To cope
            // with this, lazy-add a 'Today' row if we encounter a service
            // which is not a section divider, but our section array is still
            // empty. Otherwise, just add the new section.

            NSString * rowClass = [ service.attributes valueForKey: @"class" ];

            NSLog(@"Service %@", service);

            if ( [ rowClass isEqualToString: @"rowDivider" ] )
            {
                HTMLElement * cell         = [ service firstNodeMatchingSelector: @"td" ];
                NSString    * sectionTitle = [ cell.textContent stringByTrimmingCharactersInSet: whitespace ];

                if ( [ sectionTitle length ] )
                {
                    currentServiceList = [ [ NSMutableArray alloc ] init ];

                    [
                        self.parsedSections addObject:
                        @{
                            @"title":    sectionTitle,
                            @"services": currentServiceList
                        }
                    ];
                }

                continue; // Note early exit to next loop iteration
            }
            else if ( [ self.parsedSections count ] == 0 )
            {
                [
                    self.parsedSections addObject:
                    @{
                        @"title":    TODAY_SECTION_TITLE,
                        @"services": currentServiceList
                    }
                ];
            }

            NSLog(@"Service expected");

            // From October 2015:
            //
            // The service number is inside a link within a table cell that
            // has class "routeNumber". Notes are not available. Some icons
            // are used for e.g. wheelchair access, but they're SVG images
            // not Unicode glyphs.
            //
            // Before October 2015:
            //
            // The service number is in a "data-code" attribute on the TR.
            //
            // If the service has notes (e.g. 23-S, 54-G2) then those need
            // to be pulled from the "nb" class link.
            //
            // NSString    * number    = [ service.attributes valueForKey: @"data-code" ];
            // HTMLElement * notesLink = [ service firstNodeMatchingSelector: @"a.nb" ];
            // NSString    * notes     = nil;

            HTMLElement * numberLink = [ service firstNodeMatchingSelector: @"a.id-code-link" ];
            NSString    * number     = nil;

            if ( numberLink.textContent )
            {
                number = [ numberLink.textContent stringByTrimmingCharactersInSet: whitespace ];
            }

            // From October 2015:
            //
            // Services are not coloured. They're all grey. It's dreadful.
            //
            // Before October 2015:
            //
            // The service colour is set as an HTML inline style and we
            // assume that the 6 digit hex colour is the last thing in the
            // string, without even a semicolon. It's on a link inside the
            // first table cell, with class name "id" (confusingly).
            //
            // HTMLElement * link  = [ service firstNodeMatchingSelector: @"a.id" ];
            // NSString    * style = [ link.attributes valueForKey: @"style" ];
            // NSString    * colour;
            //
            // if ( style.length == 25 )
            // {
            //     colour = [ style substringFromIndex: 19 ];
            // }
            // else
            // {
            //     colour = @"888888";
            // }

            NSString * foundColour = number ? [ routeColours objectForKey: number ] : nil;
            NSString * colour      = foundColour ? foundColour : @"888888";

            // From October 2015:
            //
            // Unchanged.
            //
            // Before October 2015:
            //
            // The first cell has a class with the long class name you can
            // see below. This link (which goes to the full timetable)
            // contains the service name and indicators of things like low
            // floors (disabled support) via icons and spans.

            HTMLElement * infoElt       = [ service firstNodeMatchingSelector: @"a.rt-service-destination" ];
            NSString    * timetablePath = [ infoElt.attributes valueForKey: @"href" ]; // Relative path, not absolute URL
            NSString    * name          = [ infoElt.textContent stringByTrimmingCharactersInSet: whitespace ];

            // if ( notes )
            // {
            //     name = [ NSString stringWithFormat: @"%@ (%@)", name, notes ];
            // }

            // From October 2015:
            //
            // Time is on a span with class 'rt-service-time'. For an ETA,
            // there is also class 'real', else there is not.
            //
            // Before October 2015:
            //
            // ETA / Time is found based on a table cell class 'time', then
            // a span with class 'till' or 'actual' for "X mins" vs a time.

            HTMLElement * etaElt  = [ service firstNodeMatchingSelector: @"span.rt-service-time.real" ];
            HTMLElement * timeElt = [ service firstNodeMatchingSelector: @"span.rt-service-time"      ];

            // HTMLElement * etaElt  = [ service firstNodeMatchingSelector: @"td.time span.till"   ];
            // HTMLElement * timeElt = [ service firstNodeMatchingSelector: @"td.time span.actual" ];

            NSString * eta  = [  etaElt.textContent stringByTrimmingCharactersInSet: whitespace ];
            NSString * time = [ timeElt.textContent stringByTrimmingCharactersInSet: whitespace ];

            NSLog(@"Number %@, name %@, time/eta %@", number, name, eta ? eta : time);

            if ( number && name && ( time || eta ) )
            {
                [
                    currentServiceList addObject:
                    @{
                        @"colour":        colour,
                        @"number":        number,
                        @"name":          name,
                        @"when":          eta ? eta : time,
                        @"timetablePath": timetablePath ? timetablePath : @""
                    }
                ];
            }
        }

        [ self performSelectorOnMainThread: @selector( hideActivityViewer )
                                withObject: nil
                             waitUntilDone: YES ];

        [ self.refreshControl performSelectorOnMainThread: @selector( endRefreshing )
                                               withObject: nil
                                            waitUntilDone: YES ];

        [ self.tableView performSelectorOnMainThread: @selector( reloadData )
                                          withObject: nil
                                       waitUntilDone: NO ];

    };

    NSURL        * URL     = [ NSURL URLWithString: stopInfoURL ];
    NSURLSession * session = [ NSURLSession sharedSession ];

    [ [ session dataTaskWithURL: URL completionHandler: completionHandler ] resume ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureView];

    // Pull-to-refresh

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(configureView) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview: self.refreshControl];
}

// http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
//
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

// If there are only services for 'today', don't clutter up the view with
// a single, unnecessary section. This method makes it easy to detect the
// condition and, in so doing, clarifies calling code.
//
- ( BOOL ) containsATodaySectionOnly
{
    return [ self.parsedSections count ] == 1 &&
    [ self.parsedSections[ 0 ][ @"title" ] isEqualToString: TODAY_SECTION_TITLE ]
    ? YES : NO;
}

- ( UIView * ) tableView: ( UITableView * ) tableView
  viewForHeaderInSection: ( NSInteger     ) section
{
    if ( [ self containsATodaySectionOnly ] ) return nil;

    UIView  * cell  = [ tableView dequeueReusableCellWithIdentifier: @"SectionHeader" ];
    UILabel * label = ( UILabel * )[ cell viewWithTag: 1 ];

    [ label setText: self.parsedSections[ section ][ @"title" ] ];

    return cell;
}

- ( CGFloat )    tableView: ( UITableView * ) tableView
  heightForHeaderInSection: ( NSInteger     ) section
{
    if ( [ self containsATodaySectionOnly ] ) return 0.0;

    UIView * cell = [ tableView dequeueReusableCellWithIdentifier: @"SectionHeader" ];
    return [ cell bounds ].size.height;
}

// http://stackoverflow.com/questions/1560081/how-can-i-create-a-uicolor-from-a-hex-string

- ( UIColor * ) colourFromHexString: ( NSString * ) hexString
{
    unsigned    rgbValue = 0;
    NSScanner * scanner  = [ NSScanner scannerWithString: hexString ];

    [ scanner scanHexInt: &rgbValue ];

    return [ UIColor colorWithRed: ( ( rgbValue & 0xFF0000 ) >> 16 ) / 255.0
                            green: ( ( rgbValue &   0xFF00 ) >>  8 ) / 255.0
                             blue: (   rgbValue &     0xFF )         / 255.0
                            alpha: 1.0 ];
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

    UIColor * background = [ self colourFromHexString: colour ];

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
    if ( [ [ segue identifier ] isEqualToString:@"showTimetable" ] )
    {
        NSIndexPath  * indexPath = [ self.tableView indexPathForSelectedRow ];
        NSUInteger     section   = indexPath.section;
        NSUInteger     row       = indexPath.row;
        NSArray      * services  = self.parsedSections[ section ][ @"services" ];
        NSDictionary * entry     = services[ row ];

        TimetableWebViewController * controller = ( TimetableWebViewController * ) [ segue destinationViewController ];
        [ controller setDetailItem: entry ];

        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

@end
