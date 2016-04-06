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

#import "Bus_Panda-Swift.h"

@implementation BusInfoFetcher

// This does what its name suggests. The given handler is always called, even
// if errors are generated; bus info representations will describe the problem.
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
+ ( void ) getAllBusesForStop: ( NSString * ) stopID
            completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler
{
    // Create the URL we'll use to retrieve the realtime information.
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

            NSLog(@"Service %@", service);

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

            NSDictionary * routeColours = [ RouteColours colours ];
            NSString     * foundColour  = number ? [ routeColours objectForKey: number ] : nil;
            NSString     * colour       = foundColour ? foundColour : @"888888";

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

        // If anything failed then e.g. the "home" document would've been nil,
        // or other such cascaded failures would have resulted ultimately in an
        // empty services list.

        if ( [ services count ] == 0 )
        {
            NSString * message = ( error == nil )
                               ? @"No live info available"
                               : @"Network access failure";

            [
                currentServiceList addObject:
                @{
                    @"colour":        @"888888",
                    @"number":        @"N/A",
                    @"name":          message,
                    @"when":          @"—",
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

    NSURL        * URL     = [ NSURL URLWithString: stopInfoURL ];
    NSURLSession * session = [ NSURLSession sharedSession ];

    [ [ session dataTaskWithURL: URL completionHandler: completionHandler ] resume ];
}

@end
