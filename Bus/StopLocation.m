//
//  StopLocation.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import "StopLocation.h"

@interface StopLocation ()

@property ( nonatomic, copy   ) NSString               * stopID;
@property ( nonatomic, copy   ) NSString               * stopDescription;
@property ( nonatomic, assign ) CLLocationCoordinate2D   coordinate;

@end

@implementation StopLocation

- ( id ) initWithStopID: ( NSString               * ) stopID
            description: ( NSString               * ) stopDescription
             coordinate: ( CLLocationCoordinate2D   ) coordinate
{
    if ( ( self = [ super init ] ) )
    {
        self.stopID          = stopID;
        self.stopDescription = stopDescription;
        self.coordinate      = coordinate;
    }

    return self;
}
- ( NSString * ) title
{
    return _stopID;
}

- ( NSString * ) subtitle
{
    return _stopDescription;
}

- ( CLLocationCoordinate2D ) coordinate
{
    return _coordinate;
}

- ( MKMapItem * ) mapItem
{
    MKPlacemark * placemark =
    [
        [ MKPlacemark alloc ] initWithCoordinate: self.coordinate
                               addressDictionary: nil
    ];

    MKMapItem * mapItem = [ [ MKMapItem alloc ] initWithPlacemark: placemark ];

    mapItem.name =
    [
        NSString stringWithFormat: @"%@: %@",
                                   self.title,
                                   self.subtitle
    ];

    return mapItem;
}

@end

