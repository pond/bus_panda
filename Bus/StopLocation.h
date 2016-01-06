//
//  StopLocation.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface StopLocation : NSObject <MKAnnotation>

- ( id ) initWithStopID: ( NSString               * ) stopID
            description: ( NSString               * ) stopDescription
             coordinate: ( CLLocationCoordinate2D   ) coordinate;

- ( MKMapItem * ) mapItem;

@end
