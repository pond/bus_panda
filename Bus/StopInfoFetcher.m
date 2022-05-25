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

#import "Constants.h"
#import "UsefulTypes.h"

@implementation StopInfoFetcher

// Internal (very) simple cache of previously fetched stops. Since the 2021
// Metlink API is only capable of returning *all* stops, we may as well store
// them and only make the heavyweight API call once per application run.
//
static NSMutableArray * previouslyFetchedStops = nil;

// See StopInfoFetch.h for documentation.
//
+ ( void ) getStopsWithinRadius: ( CLLocationDistance     ) radiusInMetres
                     ofLocation: ( CLLocationCoordinate2D ) coordinate
              completionHandler: ( void ( ^ ) ( NSMutableArray * allStops, NSError * error ) ) handler;
{
    NSLog( @"Get stops sorted by proximity to lat. %f, lon. %f", coordinate.latitude, coordinate.longitude );

    // This is an internal completion handler for the API call fetch made at
    // the very end of this overall method.
    //
    URLRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        NSArray * stops = nil;

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
                NSString * stopID = stop[ @"stop_id" ];

                if ( stopID == nil ) continue;

                NSString * stopDescription = stop[ @"stop_name" ];

                if ( stopDescription == nil ) stopDescription = @"";

                CLLocationDegrees latitude  = [ ( NSString * ) stop[ @"stop_lat" ] doubleValue ];
                CLLocationDegrees longitude = [ ( NSString * ) stop[ @"stop_lon" ] doubleValue ];

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

                if ( previouslyFetchedStops == nil ) previouslyFetchedStops = [ [ NSMutableArray alloc ] init ];
                [ previouslyFetchedStops addObject: stopInfo ];
            }

            [ StopInfoFetcher getSortedStopsFromCacheWithinRadius: radiusInMetres
                                                       ofLocation: coordinate
                                         andCallCompletionHandler: handler ];
        }
        else
        {
            dispatch_async
            (
                dispatch_get_main_queue(),
                ^ ( void )
                {
                    handler( nil, error );
                }
            );
        }
    };

    if ( previouslyFetchedStops != nil )
    {
        [ StopInfoFetcher getSortedStopsFromCacheWithinRadius: radiusInMetres
                                                   ofLocation: coordinate
                                     andCallCompletionHandler: handler ];
    }
    else
    {
        NSURLSessionConfiguration * sessionConfiguration = [ NSURLSessionConfiguration defaultSessionConfiguration ];

        sessionConfiguration.HTTPAdditionalHeaders = @{
            @"Accept": @"application/json",
            @"x-api-key": MAGIC
        };

        NSURL            * URL     = [ NSURL URLWithString: @"https://api.opendata.metlink.org.nz/v1/gtfs/stops" ];
        NSURLSession     * session = [ NSURLSession sessionWithConfiguration: sessionConfiguration ];
        NSURLSessionTask * task    = [ session dataTaskWithURL: URL
                                             completionHandler: completionHandler ];

        [ task resume ];
    }
}

// This is really a private, internal thing used to de-dupe code in the
// main public 'fetch stops within radius of location' class method.
//
+ ( void ) getSortedStopsFromCacheWithinRadius: ( CLLocationDistance     ) radiusInMetres
                                    ofLocation: ( CLLocationCoordinate2D ) coordinate
                      andCallCompletionHandler: ( void ( ^ ) ( NSMutableArray * allStops, NSError * error ) ) handler;
{

    // Sort and filter the array based on distance from the centre coordinate.

    NSMutableArray * sortedStops    = [ [ NSMutableArray alloc ] init ];
    CLLocation     * centreLocation =
    [
        [ CLLocation alloc ] initWithLatitude: coordinate.latitude
                                    longitude: coordinate.longitude
    ];

    for ( NSDictionary * stopInfo in previouslyFetchedStops )
    {
        CLLocation * stopLocation = stopInfo[ @"stopLocation" ];

        if ( [ stopLocation distanceFromLocation: centreLocation ] <= radiusInMetres )
        {
            [ sortedStops addObject: stopInfo ];
        }
    }

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

    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ ( void )
        {
            handler( sortedStops, nil );
        }
    );
}

@end
