//
//  BusInfoFetcher.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 27/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  Fetch information about bus arrivals/departures based on a Stop ID.
//

#import "HTMLReader.h"

#import "BusInfoFetcher.h"

#import "UsefulTypes.h"
#import <Foundation/Foundation.h>

#import "Bus_Panda-Swift.h"

@interface BusInfoFetcher()

+ ( NSString * ) sectionTitleForDateTime: ( NSDate * ) serviceDateTime;

+ ( NSURLSessionTask * ) getAllBusesForStopUsingAPI: ( NSString * ) stopID
                                  completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler;

+ ( NSURLSessionTask * ) getAllBusesForStopUsingScraper: ( NSString * ) stopID
                                      completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler;

@end

@implementation BusInfoFetcher

// This does what its name suggests. The given handler is always called, even
// if errors are generated; bus info representations will describe the problem.
//
// There are two possible ways to retrieve bus stop information. MetService
// have a JSON API that responds quickly but does not allow for extended lists
// of bus information at stops. It returns up to around 20 results. The other
// way is via a web scraper, that reads a bus stop info web page which does
// not use MetService's API behind the scenes and has a "more" view which
// pulls extra stops. This is slower and will break if MetService change their
// web page structure, but does ultimately provide more information. Select
// one via the second boolean parameter.
//
// The handler is called with an Array of table sections representing today,
// tomorrow and so-on via Dictionaries with string keys "title" (section title)
// and "services". The "services" key tields an Array of one or more bus info
// descriptions (service entries), each itself as a Dictionary with string
// keys as follows:
//
//   "colour"        - Suggested 6-hex-digit RGB colour for the route
//   "number"        - Bus number as a string, e.g. "1", "N/A"
//   "name"          - Service name, e.g. "Island Bay", "No Network Access"
//   "when"          - Due time as a string, e.g. "12:23", "5 mins", "-"
//   "timetablePath" - Path to the MetLink web site timetable for that service,
//                     where known, as a relative path to the stop info URI
//                     base of "https://www.metlink.org.nz/stop/<id>/...".
//
// The handler method is always called from the main thread and is mandatory.
//
// Returns the instance of NSURLSessionTask (or subclass) that is handling the
// request. This allows you to call "cancel" on the instance if you no longer
// want the result (e.g. because a view is calling, intending to display the
// results, but the view is being told it's about to disappear).
//

+ ( NSURLSessionTask * ) getAllBusesForStop: ( NSString * ) stopID
                usingWebScraperInsteadOfAPI: ( BOOL ) useWebScraper
                          completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler
{
    if ( useWebScraper == YES )
    {
        return [ self getAllBusesForStopUsingScraper: stopID
                                   completionHandler: handler ];
    }
    else
    {
        return [ self getAllBusesForStopUsingAPI: stopID
                               completionHandler: handler ];
    }
}

// For +getAllBusesForStop:usingWebScraperInsteadOfAPI:completionHandler: -
// implements the API fetch option.
//
+ ( NSURLSessionTask * ) getAllBusesForStopUsingAPI: ( NSString * ) stopID
                                  completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler
{
    // Use the ~2016 API to pull stop data. Fork of repo with more information:
    //
    //   https://github.com/pond/metlink-api-maybe
    //
    NSString * stopInfoURL =
    [
        NSString stringWithFormat: @"https://www.metlink.org.nz/api/v1/StopDepartures/%@",
                                   stopID
    ];

    URLRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        NSDictionary   * servicesOverview   = nil;
        NSArray        * services           = nil;
        NSMutableArray * parsedSections     = [ [ NSMutableArray alloc ] init ];
        NSMutableArray * currentServiceList = [ [ NSMutableArray alloc ] init ];

        if ( error == nil && [ response isKindOfClass: [ NSHTTPURLResponse class ] ] == YES )
        {
            // Try to parse what *should* be a JSON5 array, but might be
            // something else (the server doesn't necessarily respond with
            // useful content types or status codes).

            @try
            {
                servicesOverview = [ NSJSONSerialization JSONObjectWithData: data
                                                                    options: 0
                                                                      error: nil ];

                services = servicesOverview[ @"Services" ];
            }
            @catch ( NSException * exception ) // Assumed JSON processing error
            {
                NSDictionary * details = @{
                    NSLocalizedDescriptionKey: @"The service list retrieved from the Internet was sent in a way that Bus Panda does not understand."
                };

                error = [ NSError errorWithDomain: @"bus_panda_services" code: 200 userInfo: details ];
            }
        }

        if ( error == nil && services != nil )
        {
            NSCharacterSet * whitespace              = [ NSCharacterSet whitespaceAndNewlineCharacterSet ];
            NSDate         * previousServiceDateTime = nil;

            // Process the JSON results into a higher level array of objects.
            // Example of a service entry in the dictionary, noting the entry
            // "Service" inside the service structure:
            //
            // {
            //   "ServiceID":"1",
            //   "IsRealtime":true,
            //   "VehicleRef":"2097",
            //   "Direction":"Inbound",
            //   "OperatorRef":"NZBS",
            //   "OriginStopID":"7135",
            //   "OriginStopName":"IslandBay-ThePde",
            //   "DestinationStopID":"5016",
            //   "DestinationStopName":"Wgtn Station",
            //   "AimedArrival":"2018-05-05T19:30:00+12:00",
            //   "AimedDeparture":"2018-05-05T19:30:00+12:00",
            //   "VehicleFeature":"lowFloor",
            //   "DepartureStatus":"onTime",
            //   "ExpectedDeparture":"2018-05-05T19:31:48+12:00",
            //   "DisplayDeparture": "2018-05-05T19:31:48+12:00",
            //   "DisplayDepartureSeconds":351,
            //   "Service":{
            //     "Code":"1",
            //     "TrimmedCode":"1",
            //     "Name":"Island Bay - Wellington",
            //     "Mode":"Bus",
            //     "Link":"\/timetables\/bus\/1"
            //   }
            // }

            for ( NSDictionary * service in services )
            {
                // Try really hard to get a date-time for this service as we
                // need it for the "Today"/"Tomorrow" etc. section headings.

                NSString * time            = [ service[ @"DisplayDeparture" ] stringByTrimmingCharactersInSet: whitespace ];
                NSDate   * serviceDateTime = nil;

                if ( time.length == 0 ) time = [ service[ @"ExpectedDeparture" ] stringByTrimmingCharactersInSet: whitespace ];
                if ( time.length == 0 ) time = [ service[ @"AimedDeparture"    ] stringByTrimmingCharactersInSet: whitespace ];
                if ( time.length == 0 ) time = [ service[ @"AimedArrival"      ] stringByTrimmingCharactersInSet: whitespace ];

                if ( time.length > 0 )
                {
                    // https://stackoverflow.com/questions/16254575/how-do-i-get-an-iso-8601-date-on-ios

                    NSDateFormatter * formatter       = [ [ NSDateFormatter alloc ] init ];
                    NSLocale        * enUSPOSIXLocale = [ NSLocale localeWithLocaleIdentifier: @"en_US_POSIX" ];

                    formatter.locale     = enUSPOSIXLocale;
                    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
                    formatter.timeZone   = [ NSTimeZone timeZoneWithName: @"Pacific/Auckland" ];

                    serviceDateTime      = [ formatter dateFromString: time ];

                    // If this is the first service we've encountered, we must
                    // add a new section. Is it for today, or tomorrow?
                    //
                    if ( previousServiceDateTime == nil )
                    {
                        [
                            parsedSections addObject:
                            @{
                                @"title":    [ self sectionTitleForDateTime: serviceDateTime ],
                                @"services": currentServiceList
                            }
                        ];
                    }
                    else if ( NO == [ [ NSCalendar currentCalendar] isDate: serviceDateTime
                                                           inSameDayAsDate: previousServiceDateTime ] )
                    {
                        currentServiceList = [ [ NSMutableArray alloc ] init ];

                        [
                            parsedSections addObject:
                            @{
                                @"title":    [ self sectionTitleForDateTime: serviceDateTime ],
                                @"services": currentServiceList
                            }
                        ];
                    }

                    previousServiceDateTime = serviceDateTime;
                }

                // If we just couldn't find any date-time and we have not yet
                // defined any sections, we're forced to assume "Today".
                //
                else if ( [ parsedSections count ] == 0 )
                {
                    [
                        parsedSections addObject:
                        @{
                            @"title":    TODAY_SECTION_TITLE,
                            @"services": currentServiceList
                        }
                    ];
                }

                NSNumber * isRealtime    = service[ @"IsRealtime" ];
                NSString * name          = service[ @"DestinationStopName" ];
                NSString * number        = service[ @"Service" ][ @"TrimmedCode" ];
                NSString * timetablePath = service[ @"Service" ][ @"Link" ];

                name          = [ name          stringByTrimmingCharactersInSet: whitespace ];
                number        = [ number        stringByTrimmingCharactersInSet: whitespace ];
                timetablePath = [ timetablePath stringByTrimmingCharactersInSet: whitespace ];

                if ( name.length == 0 )
                {
                    name = service[ @"Service" ][ @"Name" ];
                    name = [ name stringByTrimmingCharactersInSet: whitespace ];
                }

                if ( number.length == 0 )
                {
                    number = service[ @"Service" ][ @"Code" ];
                    number = [ number stringByTrimmingCharactersInSet: whitespace ];
                }

                NSDictionary * routeColours = [ RouteColours colours ];
                NSString     * foundColour  = number ? [ routeColours objectForKey: [ number uppercaseString ] ] : nil;
                NSString     * colour       = foundColour ? foundColour : PLACEHOLDER_COLOUR;

                // Sometimes the service name is missing, which looks odd. Use
                // the route number as the name if so.
                //
                if ( name.length == 0 )
                {
                    name = [ NSString stringWithFormat: @"Route %@", number ];
                }

                // Timetable path has "\/" instead of "/" in the API.
                //
                timetablePath = [ timetablePath stringByReplacingOccurrencesOfString: ( NSString * ) @"\\/"
                                                                          withString: ( NSString * ) @"/" ];

                // If there's no ETA, parse the ISO time instead.

                NSNumber * eta  = service[ @"DisplayDepartureSeconds" ];
                NSString * when = nil;

                if ( eta == nil || isRealtime.boolValue == NO )
                {
                    if ( serviceDateTime == nil )
                    {
                        when = PLACEHOLDER_WHEN;
                    }
                    else
                    {
                        NSDateFormatter * formatter       = [ [ NSDateFormatter alloc ] init ];
                        NSLocale        * enUSPOSIXLocale = [ NSLocale localeWithLocaleIdentifier: @"en_US_POSIX" ];

                        formatter.locale     = enUSPOSIXLocale;
                        formatter.dateFormat = @"h:mma";
                        formatter.AMSymbol   = @"am";
                        formatter.PMSymbol   = @"pm";

                        when = [ formatter stringFromDate: serviceDateTime ];
                    }
                }
                else
                {
                    // By observation - MetService round down the number of
                    // seconds to minutes and less than 2 minutes is shown as
                    // "due". Since it is safer to err on the side of optimism
                    // for ETA (encouraging people to be at the stop definitely
                    // before their target bus arrives), we found down too.

                    NSUInteger etaMinutes = eta.integerValue / 60;

                    when = etaMinutes < 2 ?
                           @"Due"         :
                           [ NSString stringWithFormat: @"%lu mins", etaMinutes ];
                }

                if ( number && name && when )
                {
                    [
                        currentServiceList addObject:
                        @{
                            @"colour":        colour,
                            @"number":        number,
                            @"name":          name,
                            @"when":          when,
                            @"timetablePath": timetablePath ? timetablePath : @""
                        }
                    ];
                }
            }
        }

        // If anything failed then e.g. the "home" document would've been nil,
        // or other such cascaded failures would have resulted ultimately in an
        // empty services list.

        if ( [ services count ] == 0 )
        {
            NSString * message = ( error == nil )
                               ? @"No live info available"
                               : [ error localizedDescription ];

            [
                currentServiceList addObject:
                @{
                    @"error":         @( YES ),
                    @"colour":        PLACEHOLDER_COLOUR,
                    @"number":        PLACEHOLDER_SERVICE,
                    @"name":          message,
                    @"when":          PLACEHOLDER_WHEN,
                    @"timetablePath": @""
                }
            ];

            [
                parsedSections addObject:
                @{
                    @"title":    TODAY_SECTION_TITLE,
                    @"services": currentServiceList
                }
            ];
        }

        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                handler( parsedSections );
            }
        );
    };

    NSURL            * URL     = [ NSURL URLWithString: stopInfoURL ];
    NSURLSession     * session = [ NSURLSession sharedSession ];
    NSURLSessionTask * task    = [ session dataTaskWithURL: URL
                                         completionHandler: completionHandler ];

    [ task resume ];

    return task;
}

// For +getAllBusesForStop:usingWebScraperInsteadOfAPI:completionHandler: -
// implements the web scraper option.
//
+ ( NSURLSessionTask * ) getAllBusesForStopUsingScraper: ( NSString * ) stopID
                                      completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler
{
    // We will make a request to fetch the JSON at 'centreEnumerationURI' from
    // above, declaring the below block as the code to run upon completion
    // (success or failure).
    //
    // After this chunk of code, at the end of this overall method, is the
    // place where the request is actually made.
    //
    NSString * stopInfoURL =
    [
        NSString stringWithFormat: @"https://www.metlink.org.nz/stop/%@/departures?more=1",
                                   stopID
    ];

    // We will make a request to fetch the HTML at 'stopInfoURL' from above,
    // declearing the below block as the code to run upon completion (success
    // or failure).
    //
    // After this big chunk of code, at the end of this overall method, is the
    // place where the request is actually made.
    //
    URLRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        HTMLDocument * home;
        NSString     * contentType = nil;

        if ( [ response isKindOfClass: [ NSHTTPURLResponse class ] ] )
        {
            NSDictionary *headers = [ ( NSHTTPURLResponse * ) response allHeaderFields ];
            contentType = headers[ @"Content-Type" ];
        }

        if ( error != nil || contentType == nil )
        {
            home = nil;
        }
        else
        {
            home = [ HTMLDocument documentWithData: data
                                 contentTypeHeader: contentType];
        }

        // The services are in an HTML table with each row representing an
        // individual service, or a section title with a date in it.

        HTMLElement * list     = [ home firstNodeMatchingSelector: @"div.rt-info-content table" ];
        NSArray     * services = [ list     nodesMatchingSelector: @"tr" ];

        NSMutableArray * parsedSections     = [ [ NSMutableArray alloc ] init ];
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

            if ( [ rowClass isEqualToString: @"rowDivider" ] )
            {
                HTMLElement * cell         = [ service firstNodeMatchingSelector: @"td" ];
                NSString    * sectionTitle = [ cell.textContent stringByTrimmingCharactersInSet: whitespace ];

                if ( [ sectionTitle length ] )
                {
                    currentServiceList = [ [ NSMutableArray alloc ] init ];

                    [
                        parsedSections addObject:
                        @{
                            @"title":    sectionTitle,
                            @"services": currentServiceList
                        }
                    ];
                }

                continue; // Note early exit to next loop iteration
            }
            else if ( [ parsedSections count ] == 0 )
            {
                [
                    parsedSections addObject:
                    @{
                        @"title":    TODAY_SECTION_TITLE,
                        @"services": currentServiceList
                    }
                ];
            }

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
            //     colour = PLACEHOLDER_COLOUR;
            // }

            NSDictionary * routeColours = [ RouteColours colours ];
            NSString     * foundColour  = number ? [ routeColours objectForKey: [ number uppercaseString ] ] : nil;
            NSString     * colour       = foundColour ? foundColour : PLACEHOLDER_COLOUR;

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

            // 2016-04-04 (ADH): A recent MetLink fault on their end was to
            // omit names. This looks really odd. So if there's no name, just
            // set the name to the route number. It looks less strange!
            //
            if ( name.length == 0 )
            {
                name = [ NSString stringWithFormat: @"Route %@", number ];
            }

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

        // If anything failed then e.g. the "home" document would've been nil,
        // or other such cascaded failures would have resulted ultimately in an
        // empty services list.

        if ( [ services count ] == 0 )
        {
            NSString * message = ( error == nil )
                               ? @"No live info available"
                               : [ error localizedDescription ];

            [
                currentServiceList addObject:
                @{
                    @"error":         @( YES ),
                    @"colour":        PLACEHOLDER_COLOUR,
                    @"number":        PLACEHOLDER_SERVICE,
                    @"name":          message,
                    @"when":          PLACEHOLDER_WHEN,
                    @"timetablePath": @""
                }
            ];

            [
                parsedSections addObject:
                @{
                    @"title":    TODAY_SECTION_TITLE,
                    @"services": currentServiceList
                }
            ];
        }

        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                handler( parsedSections );
            }
        );
    };

    NSURL            * URL     = [ NSURL URLWithString: stopInfoURL ];
    NSURLSession     * session = [ NSURLSession sharedSession ];
    NSURLSessionTask * task    = [ session dataTaskWithURL: URL
                                         completionHandler: completionHandler ];

    [ task resume ];

    return task;
}

// Given a (typically, bus service departure) date/time, return a string
// suitable for a section header above that service. This will be "today",
// "tomorrow" or the day name (e.g. "Monday") for further away dates, on
// the assumption that even "2 days from now" is extremely unlikely and
// things more than a week away will never be encountered here; simple day
// names will therefore be unambiugous.
//
// Adapted from:
//
//   https://stackoverflow.com/questions/4739483/number-of-days-between-two-nsdates
//
+ ( NSString * ) sectionTitleForDateTime: ( NSDate * ) serviceDateTime
{
    NSDate * today = [ NSDate date ];
    NSDate * fromDate;
    NSDate * toDate;

    NSCalendar * calendar = [NSCalendar currentCalendar];

    [ calendar rangeOfUnit: NSCalendarUnitDay
                 startDate: &fromDate
                  interval: NULL
                   forDate: today ];

    [ calendar rangeOfUnit: NSCalendarUnitDay
                 startDate: &toDate
                  interval: NULL
                   forDate: serviceDateTime ];

    NSDateComponents * difference = [
        calendar components: NSCalendarUnitDay
                   fromDate: fromDate
                     toDate: toDate
                    options: 0
    ];

    if ( difference.day == 0 )
    {
        return TODAY_SECTION_TITLE;
    }
    else if ( difference.day == 1 )
    {
        return TOMORROW_SECTION_TITLE;
    }
    else
    {
        // http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
        // http://nsdateformatter.com

        NSDateFormatter * formatter = [ [ NSDateFormatter alloc ] init ];

        [ formatter setDateFormat: @"eeee" ];

        return [ formatter stringFromDate: serviceDateTime ];
    }
}

@end
