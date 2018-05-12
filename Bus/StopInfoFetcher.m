//
//  StopInfoFetcher.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 30/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  Fetch information about stops within a given radius of a given location.
//

#import "StopInfoFetcher.h"

#import "UsefulTypes.h"

@implementation StopInfoFetcher

// Retrieve the stops for the given centre coordinates using the only currently
// known interface into the MetLink web site via inspection of the public site
// JavaScript behaviour. This is just a simple GET request with a query string
// giving the centre point latitude and longitude and the rough radius of the
// returned results determined by observation. A top-level JSON (i.e. JSON5)
// Array is returned with an example entry as follows:
//
// {
//     "ID":   "17929",
//     "Name": "Manners Street at Willis Street",
//     "Lat":  "-41.2895508",
//     "Long": "174.7749028",
//     "Sms":  "5006"
// }
//
// The public stop ID is therefore given by the "Sms" field.
//
+ ( void ) getStopsWithinRadius: ( CLLocationDistance       ) radiusInMetres
                     ofLocation: ( CLLocationCoordinate2D   ) coordinate
              completionHandler: ( void ( ^ ) ( NSMutableArray * allStops, NSError * error ) ) handler
{
    // MetLink in around 2016 started using what looks like a formal internal
    // API, which was perhaps going to be made public but never was. We can
    // see that it fetches 'StopNearby' for its map of stops. This returns a
    // fixed number of results, without taking a radius parameter. An exact
    // number can be asked for, but only up to 99 and MetLink's own site does
    // not do this. Fork of repo with more information:
    //
    //   https://github.com/pond/metlink-api-maybe
    //
    // As a result if you zoom out of the map and drag it a distance, you'll
    // only get a small cluster of stops showing at the centre with nothing
    // between this and the previous map centre. Due to the API limitations,
    // both Bus Panda's map and MetLink's own website map behave this way.
    //
    NSString * centreEnumerationURI =
    [
        NSString stringWithFormat: @"https://www.metlink.org.nz/api/v1/StopNearby/%f/%f",
        coordinate.latitude,
        coordinate.longitude
        // radiusInMetres - for future expansion one day maybe?
    ];

    NSLog( @"Retrieve stops via: %@", centreEnumerationURI );

    // We will make a request to fetch the JSON at 'centreEnumerationURI' from
    // above, declaring the below block as the code to run upon completion
    // (success or failure).
    //
    // After this chunk of code, at the end of this overall method, is the
    // place where the request is actually made.
    //
    URLRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        NSArray        * stops       = nil;
        NSMutableArray * sortedStops = nil;

        if ( error == nil && [ response isKindOfClass: [ NSHTTPURLResponse class ] ] == YES )
        {
            // Conceptually we should check for e.g. application/json, but all
            // responses from MetLink at the time of writing are served up as
            // text/html, be they a real HTML 404 response, or raw JSON. Doh.
            //
            // NSDictionary * headers     = [ ( NSHTTPURLResponse * ) response allHeaderFields ];
            // NSString     * contentType = headers[ @"Content-Type" ];
            //
            // So - try to parse what *should* be a JSON5 array.

            @try
            {
                stops = [ NSJSONSerialization JSONObjectWithData: data
                                                         options: 0
                                                           error: nil ];

            }
            @catch ( NSException * exception ) // Assumed JSON processing error
            {
                NSDictionary * details = @{
                    NSLocalizedDescriptionKey: @"Bus stops retrieved from the Internet were sent in a way that Bus Panda does not understand."
                };

                error = [ NSError errorWithDomain: @"bus_panda_stops" code: 200 userInfo: details ];
            }
        }

        if ( error == nil && stops != nil )
        {
            // Process the JSON results into a higher level array of objects.

            for ( NSDictionary * stop in stops )
            {
                NSString * stopID = stop[ @"Sms" ];

                if ( stopID == nil ) continue;

                NSString * stopDescription = stop[ @"Name" ];

                if ( stopDescription == nil ) stopDescription = @"";

                CLLocationDegrees latitude  = [ ( NSString * ) stop[ @"Lat"  ] doubleValue ];
                CLLocationDegrees longitude = [ ( NSString * ) stop[ @"Long" ] doubleValue ];

                CLLocation * stopLocation =
                [
                    [ CLLocation alloc ] initWithLatitude: latitude
                                                longitude: longitude
                ];

                NSDictionary * stopInfo =
                @{
                    @"stopID":          stopID,
                    @"stopDescription": stopDescription,
                    @"stopLocation":    stopLocation
                };

                if ( sortedStops == nil ) sortedStops = [ [ NSMutableArray alloc ] init ];

                [ sortedStops addObject: stopInfo ];
            }

            // Sort the array based on distance from the centre coordinate.

            CLLocation * centreLocation =
            [
                [ CLLocation alloc ] initWithLatitude: coordinate.latitude
                                            longitude: coordinate.longitude
            ];

            [
                sortedStops sortUsingComparator:

                ^ NSComparisonResult( NSDictionary * stopInfo1, NSDictionary * stopInfo2 )
                {
                    CLLocation * location1 = stopInfo1[ @"stopLocation" ];
                    CLLocation * location2 = stopInfo2[ @"stopLocation" ];

                    CLLocationDistance distance1 = [ centreLocation distanceFromLocation: location1 ];
                    CLLocationDistance distance2 = [ centreLocation distanceFromLocation: location2 ];

                    if ( distance1 < distance2 )
                    {
                        return NSOrderedAscending;
                    }
                    else if ( distance1 > distance2 )
                    {
                        return NSOrderedDescending;
                    }
                    else
                    {
                        return NSOrderedSame;
                    }
                }
            ];
        }

        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                handler( sortedStops, error );
            }
        );
    };

    NSURL        * URL     = [ NSURL URLWithString: centreEnumerationURI ];
    NSURLSession * session = [ NSURLSession sharedSession ];

    [ [ session dataTaskWithURL: URL completionHandler: completionHandler ] resume ];
}

@end
