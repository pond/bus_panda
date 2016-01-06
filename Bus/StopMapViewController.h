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

@interface StopMapViewController : AddStopAbstractViewController <MKMapViewDelegate>

@property ( weak, nonatomic ) IBOutlet MKMapView * mapView;

@end
