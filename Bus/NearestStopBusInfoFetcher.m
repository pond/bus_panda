//
//  NearestStopBusInfoFetcher.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 1/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  For the Watch app, find nearby bus stops and service information.
//  Tries to use stops marked as "preferred" in favour of other stops,
//  even if they're a bit further away.
//

#import "NearestStopBusInfoFetcher.h"

#import "StopInfoFetcher.h"
#import "BusInfoFetcher.h"
#import "AppDelegate.h"
#import "MasterViewController.h"

#import "INTULocationManager.h"

@implementation NearestStopBusInfoFetcher

- ( void ) beginWithWatchOSReplyHandler: ( nonnull void (^)( NSDictionary <NSString *, id> * _Nonnull ) ) replyHandler
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ ( void )
        {
            INTULocationManager *locMgr = [ INTULocationManager sharedInstance ];

            [
                locMgr requestLocationWithDesiredAccuracy: INTULocationAccuracyBlock
                                                  timeout: 10.0
                                     delayUntilAuthorized: NO
                                                    block:

                ^ ( CLLocation           * currentLocation,
                    INTULocationAccuracy   achievedAccuracy,
                    INTULocationStatus     status )
                {
                    if ( status == INTULocationStatusSuccess )
                    {
                        [ self getStopsAtLocation: currentLocation
                                 withReplyHandler: replyHandler ];
                    }
                    else if ( status == INTULocationStatusTimedOut )
                    {
                        NSString * message = @"Bus Panda cannot get a sufficiently accurate fix on your location.";
                        replyHandler( @{ @"error": message } );
                    }
                    else
                    {
                        NSString * message = @"Bus Panda cannot determine your location. Is it allowed to access location services?";
                        replyHandler( @{ @"error": message } );
                    }
                }
            ];
        }
    );
}

- ( void ) getStopsAtLocation: ( CLLocation * ) location
             withReplyHandler: ( nonnull void (^)( NSDictionary <NSString *, id> * _Nonnull ) ) replyHandler
{
    [
        StopInfoFetcher getStopsWithinRadius: 500
                                  ofLocation: location.coordinate
                           completionHandler:

        ^ ( NSMutableArray * allStops, NSError * error )
        {
            if ( error != nil || allStops == nil || allStops.count == 0 )
            {
                NSString * message = @"Bus Panda could not find any nearby stops.";
                replyHandler( @{ @"error": message } );
            }
            else
            {
                [ self getBusesFromBestStopIn: allStops
                             withReplyHandler: replyHandler ];
            }
        }
    ];
}

- ( NSManagedObject * ) findFavouriteStopByID: ( NSString * ) stopID
{
    AppDelegate            * appDelegate = ( AppDelegate * ) [ [ UIApplication sharedApplication ] delegate ];
    NSError                * error       = nil;
    NSManagedObjectContext * moc         = [ appDelegate managedObjectContextLocal ];
    NSManagedObjectModel   * mom         = [ appDelegate managedObjectModel ];
    NSEntityDescription    * styleEntity = [ mom entitiesByName ][ ENTITY_AND_RECORD_NAME ];
    NSFetchRequest         * request     = [ [ NSFetchRequest alloc ] init ];
    NSPredicate            * predicate   =
    [
        NSPredicate predicateWithFormat: @"(stopID == %@)",
        stopID
    ];

    [ request setEntity:              styleEntity ];
    [ request setIncludesSubentities: NO          ];
    [ request setPredicate:           predicate   ];

    NSArray * results = [ moc executeFetchRequest: request error: &error ];

    if ( error != nil || [ results count ] < 1 )
    {
        return nil;
    }

    return results[ 0 ];
}

- ( void ) getBusesFromBestStopIn: ( NSMutableArray * ) allStops
                 withReplyHandler: ( nonnull void (^)( NSDictionary <NSString *, id> * _Nonnull ) ) replyHandler
{
    // The array in allStops contains dictionaries with key "stopID" yielding
    // the ID, with the stops ordered closest first, furthest away last. Walk
    // this array, asking Core Data for a match in the user's favourites.
    //
    // If we find a match that's Preferred then, given the full Watch app would
    // only show those, use that one even if it's further away.
    //
    // If we find another match keep going anyway in case any preferred stops
    // are found.
    //
    // If at the end we have a preferred match, use it; else if a non-preferred
    // match use that; else if no match, just use the first stop in the array
    // as it's closest.

    NSDictionary * normalMatch;
    NSDictionary * preferredMatch;

    for ( NSDictionary * stop in allStops )
    {
        NSString        * stopID = stop[ @"stopID" ]; if ( stopID == nil ) continue;
        NSManagedObject * obj    =[ self findFavouriteStopByID: stopID ];

        if ( obj != nil )
        {
            if ( [ [ obj valueForKey: @"preferred" ] integerValue ] > 0 )
            {
                preferredMatch = stop;
                break;
            }
            else if ( normalMatch == nil )
            {
                normalMatch = stop;
            }
        }
    }

    NSDictionary * stop;

    if ( preferredMatch )
    {
        stop = preferredMatch;
    }
    else if ( normalMatch )
    {
        stop = normalMatch;
    }
    else
    {
        stop = allStops[ 0 ];
    }

    NSString * stopID          = stop[ @"stopID"          ];
    NSString * stopDescription = stop[ @"stopDescription" ];

    [
        BusInfoFetcher getAllBusesForStop: stopID
              usingWebScraperInsteadOfAPI: NO
                        completionHandler:

        ^ ( NSMutableArray * allBuses )
        {
            // allBuses is an array of one or more dictionaries each describing
            // a section of the master view; e.g. today's departures and the
            // next day's departures. We coalesce these into a single array of
            // up to only four actual bus entries, to reduce the reply size.

            NSMutableArray * buses = [ [ NSMutableArray alloc ] init ];

            for ( NSDictionary * section in allBuses )
            {
                // Wrinkle - "-subArrayWithRange:" causes an exception of the
                // range spans beyond the count of array items, so we must make
                // sure it cannot.

                NSArray    * sectionBuses = section[ @"services" ];
                NSUInteger   limit        = sectionBuses.count;

                if ( limit == 0 ) continue;

                NSUInteger   rangeLength  = MIN( 4 - buses.count, limit );
                NSArray    * lessBuses    = [
                    sectionBuses subarrayWithRange: NSMakeRange( 0, rangeLength )
                ];

                [ buses addObjectsFromArray: lessBuses ];

                if ( buses.count >= 4 ) break;
            }

            NSDictionary * reply =
            @{
                @"stopDescription": stopDescription,
                @"stopID":          stopID,
                @"buses":           buses
            };

            replyHandler( reply );
        }
    ];
}

@end
