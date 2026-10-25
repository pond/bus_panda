//
//  StopMapViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

#import "AddStopAbstractViewController.h"

@interface StopMapViewController : AddStopAbstractViewController < MKMapViewDelegate,
                                                                   CLLocationManagerDelegate >

@property ( weak, nonatomic         ) IBOutlet MKMapView         * mapView;
@property (       nonatomic, retain )          CLLocationManager * locationManager;

- ( void ) configureForNearbyStops;

// Size for the "Add Using Map" sheet in a regular-width, regular-height
// environment (e.g. iPad), given the size of the window it appears in. The
// default iPad sheet size is far too small for a map on a large screen.
//
+ ( CGSize ) sheetSizeForWindowSize: ( CGSize ) windowSize;

@end
