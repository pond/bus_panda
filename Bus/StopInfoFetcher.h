//
//  StopInfoFetcher.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 30/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  Fetch information about stops within a given radius of a given location.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface StopInfoFetcher : NSObject

// This does what its name suggests.
//
// The handler method is always called from the main thread and is mandatory.
// Either its "allStops" parameter or the "error" parameter will be supplied,
// and the other will be "nil".
//
// For non-error cases, the handler is called with an Array of Dictionary
// objects sorted by nearest-stop first and keys as follows:
//
//   stopID           The familiar four character Stop ID (String)
//   stopDescription  MetLink's descriptive human-readable stop name (String)
//   stopLocation     The stop location (CLLocation)
//
+ ( void ) getStopsWithinRadius: ( CLLocationDistance     ) radiusInMetres
                     ofLocation: ( CLLocationCoordinate2D ) coordinate
              completionHandler: ( void ( ^ ) ( NSMutableArray * allStops, NSError * error ) ) handler;

@end
