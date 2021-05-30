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

// Placeholder definitions used for cases where information is not available.
//
#define PLACEHOLDER_WHEN    @"—"
#define PLACEHOLDER_COLOUR  @"888888"
#define PLACEHOLDER_SERVICE @"ℹ︎"

@interface BusInfoFetcher : NSObject

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
//   "error"         - If present with any value, this is an error placeholder
//                     item (other fields are filled in with defaults)
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
                          completionHandler: ( void ( ^ ) ( NSMutableArray * allBuses ) ) handler;

@end
