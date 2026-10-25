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
// All of this state is only ever read or written on the main thread. While
// the one-and-only fetch is in progress, further requests are queued in
// 'pendingRequests' and dealt with when the current request completes.
//
static NSArray        * previouslyFetchedStops = nil;
static NSMutableArray * pendingRequests        = nil;
static BOOL             fetchInProgress        = NO;

// See StopInfoFetch.h for documentation.
//
+ ( void ) getStopsWithinRadius: ( CLLocationDistance     ) radiusInMetres
                     ofLocation: ( CLLocationCoordinate2D ) coordinate
              completionHandler: ( void ( ^ ) ( NSMutableArray * allStops, NSError * error ) ) handler;
{
    if ( ! NSThread.isMainThread )
    {
        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                [ StopInfoFetcher getStopsWithinRadius: radiusInMetres
                                            ofLocation: coordinate
                                     completionHandler: handler ];
            }
        );

        return;
    }

    NSLog( @"Get stops sorted by proximity to lat. %f, lon. %f", coordinate.latitude, coordinate.longitude );

    // Answer from the cache if possible.
    //
    if ( previouslyFetchedStops != nil )
    {
        [ StopInfoFetcher getSortedStopsFromCacheWithinRadius: radiusInMetres
                                                   ofLocation: coordinate
                                     andCallCompletionHandler: handler ];
        return;
    }

    // Otherwise queue this request until the fetch completes, starting the
    // fetch if it isn't already running.
    //
    if ( pendingRequests == nil ) pendingRequests = [ [ NSMutableArray alloc ] init ];

    [
        pendingRequests addObject: ^ ( NSError * error )
        {
            if ( error == nil )
            {
                [ StopInfoFetcher getSortedStopsFromCacheWithinRadius: radiusInMetres
                                                           ofLocation: coordinate
                                             andCallCompletionHandler: handler ];
            }
            else
            {
                handler( nil, error );
            }
        }
    ];

    if ( fetchInProgress ) return;

    fetchInProgress = YES;

    // This is the completion handler for the API call fetch made below. It
    // parses into a private array on whatever thread NSURLSession uses, then
    // publishes the result and answers all queued requests on the main
    // thread.
    //
    URLRequestCompletionHandler completionHandler = ^ ( NSData        * data,
                                                        NSURLResponse * response,
                                                        NSError       * error )
    {
        NSArray        * stops        = nil;
        NSMutableArray * fetchedStops = nil;

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
                stops = nil;
            }

            if ( ! [ stops isKindOfClass: [ NSArray class ] ] )
            {
                NSDictionary * details = @{
                    NSLocalizedDescriptionKey: @"The bus stop list was sent in a way that Bus Panda does not understand."
                };

                error = [ NSError errorWithDomain: @"bus_panda_stops" code: 200 userInfo: details ];
            }
        }
        else if ( error == nil )
        {
            NSDictionary * details = @{
                NSLocalizedDescriptionKey: @"The bus stop list could not be retrieved."
            };

            error = [ NSError errorWithDomain: @"bus_panda_stops" code: 201 userInfo: details ];
        }

        if ( error == nil )
        {
            // Process the JSON results into a higher level array of objects.

            fetchedStops = [ [ NSMutableArray alloc ] init ];

            for ( NSDictionary * stop in stops )
            {
                if ( ! [ stop isKindOfClass: [ NSDictionary class ] ] ) continue;

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

                [
                    fetchedStops addObject:
                    @{
                        @"stopID":          stopID,
                        @"stopDescription": stopDescription,
                        @"stopLocation":    stopLocation
                    }
                ];
            }
        }

        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                if ( error == nil ) previouslyFetchedStops = [ fetchedStops copy ];

                fetchInProgress = NO;

                NSArray * requests = [ pendingRequests copy ];
                [ pendingRequests removeAllObjects ];

                for ( void ( ^ request )( NSError * ) in requests )
                {
                    request( error );
                }
            }
        );
    };

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

// See StopInfoFetch.h for documentation.
//
+ ( BOOL ) hasCachedStops
{
    return previouslyFetchedStops != nil ? YES : NO;
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
