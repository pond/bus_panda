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

+ ( NSURLSessionTask * ) getAllBusesForStopUsingAPI: ( NSString * ) stopID
                                  completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler;

+ ( NSString * ) sectionTitleForDateTime: ( NSDate * ) serviceDateTime;
+ ( NSString * ) safeTrim:                ( id       ) object;

@end

@implementation BusInfoFetcher

// This does what its name suggests. The given handler is always called, even
// if errors are generated; bus info representations will describe the problem.
//
// There were two possible ways to retrieve bus stop information. MetLink have
// a JSON API that responds quickly but does not allow for extended lists of
// bus information at stops. It returns up to around 20 results. The other way
// was via a web scraper, which used to yield better results with more entries
// but seemed to be shut down in 2020. Their own site now always uses the
// inferior API.
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
                          completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler
{
    NSLog( @"Fetching bus information for %@ by API", stopID );
    return [ self getAllBusesForStopUsingAPI: stopID
                           completionHandler: handler ];
}

// For +getAllBusesForStop:completionHandler: -
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
        NSString stringWithFormat: @"https://backend.metlink.org.nz/api/v1/stopdepartures/%@",
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

                services = servicesOverview[ @"departures" ];
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
            NSDate * previousServiceDateTime = nil;

            // Process the JSON results into a higher level structure. Example
            // of a service entry in the dictionary, from the entry
            // "departures" inside the service structure:
            //
            // {
            //   "stop_id": "5516",
            //   "service_id": "24",
            //   "direction": "inbound",
            //   "operator": "TZM",
            //   "origin": {
            //       "stop_id": "3081",
            //       "name": "Johnsonville-B"
            //   },
            //   "destination": {
            //       "stop_id": "6224",
            //       "name": "Kilbirnie"
            //   },
            //   "delay": "PT7M31S",
            //   "vehicle_id": "3842",
            //   "name": "CourtenayPl-C",
            //   "arrival": {
            //       "aimed": "2021-05-11T08:02:00+12:00",
            //       "expected": "2021-05-11T08:09:31+12:00"
            //   },
            //   "departure": {
            //       "aimed": "2021-05-11T08:02:00+12:00",
            //       "expected": "2021-05-11T08:09:31+12:00"
            //   },
            //   "status": "delayed",
            //   "wheelchair_accessible": true
            // }
            //
            for ( NSDictionary * service in services )
            {
                BOOL           adjustForCaution = NO;
                BOOL           isRealTime       = YES;
                NSDictionary * arrival          = service[ @"arrival"   ];
                NSDictionary * departure        = service[ @"departure" ];
                NSDate       * serviceDateTime  = nil;
                NSString     * time;

                // Try really hard to get a date-time for this service as we
                // need it for the "Today"/"Tomorrow" etc. section headings.
                //
                // * Try the arrival real-time expectation first.
                // * Try the arrival timetable value next.
                // * Try the departure real-time expectation as we're getting
                //   more desparate, but flag that we should show a slightly
                //   earlier time to the user to avoid the risk of them maybe
                //   missing the bus because it is *leaving* at this time.
                // * Finally, try the departure timetable value.
                //
                time = [ BusInfoFetcher safeTrim: arrival[ @"expected" ] ];

                if ( time.length == 0 )
                {
                    time = [ BusInfoFetcher safeTrim: departure[ @"expected" ] ];

                    if ( time.length == 0 )
                    {
                        time             = [ BusInfoFetcher safeTrim: arrival[ @"aimed" ] ];
                        isRealTime       = NO;
                        adjustForCaution = YES;

                        if ( time.length == 0 )
                        {
                            time = [ BusInfoFetcher safeTrim: departure[ @"aimed" ] ];
                        }
                    }
                }

                // The API used to have a flag saying whether or not the value
                // should be considered realtime, but this got removed. Instead
                // we guess based on a missing status, since that's what the
                // MetLink web site also does. There are other times it seems
                // to show as if not-realtime too, but I can't work out what
                // the heuristic is.
                //
                NSString * status = service[ @"status" ];
                if ( [ status isEqualToString: @"" ] ) isRealTime = NO;

                if ( time.length > 0 )
                {
                    // https://stackoverflow.com/questions/16254575/how-do-i-get-an-iso-8601-date-on-ios

                    NSDateFormatter * formatter       = [ [ NSDateFormatter alloc ] init ];
                    NSLocale        * enUSPOSIXLocale = [ NSLocale localeWithLocaleIdentifier: @"en_US_POSIX" ];

                    formatter.locale     = enUSPOSIXLocale;
                    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
                    formatter.timeZone   = [ NSTimeZone timeZoneWithName: @"Pacific/Auckland" ];

                    serviceDateTime      = [ formatter dateFromString: time ];

                    if ( serviceDateTime != nil && adjustForCaution == YES )
                    {
                        serviceDateTime = [ serviceDateTime dateByAddingTimeInterval: -60.0 ];
                    }

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

                NSString * departureStatus = [ BusInfoFetcher safeTrim: service[ @"status" ] ];
                NSString * name            = [ BusInfoFetcher safeTrim: service[ @"destination" ][ @"name" ] ];
                NSString * number          = [ BusInfoFetcher safeTrim: service[ @"service_id" ] ];
                NSString * timetablePath   = [ @"/timetables/bus/" stringByAppendingString: number ];

                if ( [ departureStatus isEqualToString: @"cancelled" ] )
                {
                    name = @"CANCELLED";
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

                // Show an expected date-time, or use the real-time expected
                // arrival instead as an offset from "now" (an older API
                // version from MetLink was much more useful than this and had
                // the exact ETA in seconds with an "is realtime" flag; we are
                // left guessing on a newer update which decimated features).
                //
                NSString * when = nil;

                if ( serviceDateTime == nil )
                {
                    when = PLACEHOLDER_WHEN;
                }
                else if ( isRealTime == NO )
                {
                    NSDateFormatter * formatter       = [ [ NSDateFormatter alloc ] init ];
                    NSLocale        * enUSPOSIXLocale = [ NSLocale localeWithLocaleIdentifier: @"en_US_POSIX" ];

                    formatter.locale     = enUSPOSIXLocale;
                    formatter.dateFormat = @"h:mma";
                    formatter.AMSymbol   = @"am";
                    formatter.PMSymbol   = @"pm";

                    when = [ formatter stringFromDate: serviceDateTime ];
                }
                else
                {
                    NSTimeInterval eta = [ serviceDateTime timeIntervalSinceNow ];

                    if ( eta < 0 ) eta = -eta;

                    // By observation - MetLink used toround down the number of
                    // seconds to minutes and less than 2 minutes is shown as
                    // "due". Since it is safer to err on the side of optimism
                    // for ETA (encouraging people to be at the stop definitely
                    // before their target bus arrives), we round down too.
                    //
                    NSUInteger etaMinutes = floor(eta / 60.0);

                    when = etaMinutes < 2 ?
                           @"Due"         :
                           [ NSString stringWithFormat: @"%lu mins", ( long ) etaMinutes ];
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

// If reading something that might return either an NSString or "nil",
// calling methods such as -stringByTrimmingCharactersInSet: on the
// object is safe. If however you might get NSNull rather than true
// "nil", you'd be sending an unrecognised selector, resulting in a
// crash. The JSON parser can do this; the HTML parser might.
//
// Call here to trim white space off a string that might otherwise be
// "nil" or "NSNull". Always returns the trimmed string or "nil".
//
+ ( NSString * ) safeTrim: ( id ) object
{
    if ( [ object isEqual: [ NSNull null ] ] )
    {
        return nil;
    }
    else
    {
        NSString       * string     = ( NSString * ) object;
        NSCharacterSet * whitespace = [ NSCharacterSet whitespaceAndNewlineCharacterSet ];

        return [ string stringByTrimmingCharactersInSet: whitespace ];
    }
}

@end
