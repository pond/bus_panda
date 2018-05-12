//
//  BusInfoFetcher.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 27/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  Fetch information about bus arrivals/departures based on a Stop ID.
//

#import <Foundation/Foundation.h>

// Title text for the 'Today' section, if present; likewise 'Tomorrow'.
//
#define TODAY_SECTION_TITLE    @"Today"
#define TOMORROW_SECTION_TITLE @"Tomorrow"

@interface BusInfoFetcher : NSObject

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
                          completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler;

@end
