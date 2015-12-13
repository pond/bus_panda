//
//  StopMapViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import "StopMapViewController.h"

@interface StopMapViewController ()

@end

@implementation StopMapViewController

//- (void)viewDidLoad {
//    [super viewDidLoad];
//    // Do any additional setup after loading the view.
//}
//
//- (void)didReceiveMemoryWarning {
//    [super didReceiveMemoryWarning];
//    // Dispose of any resources that can be recreated.
//}

- ( void ) viewWillAppear: ( BOOL ) animated
{
    CLLocationCoordinate2D zoomLocation;

    zoomLocation.latitude  = -41.275;
    zoomLocation.longitude = 174.795;

    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(
      zoomLocation,
      20000,
      20000
    );

    [ self.mapView setRegion: viewRegion animated: YES ];
}

// As a precaution, make sure the network spinner is definitely cancelled
// when the application is closed.
//
- (void ) viewWillDisappear: ( BOOL ) animated
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = false;
}

- ( IBAction ) toolbarCancelPressed: ( id ) sender
{
    [ self dismissAdditionView ];
}

/*
So when I am about to be shown, I need to start an HTTP fetch for the
bus stops around the coordinates in the middle of the view.
 
 I'm going to have to work out how 'wide' an area the "stops nearby" stuff
 from MetLink is based on the initial test population.
 
 Architecturally speaking I just - I guess:
 
 * Stop the system activity indicator on view-to-be-hidden as a precaution
 * Start the system activity indicator
 * Start an HTTP fetch for
https://www.metlink.org.nz/stop/nearbystopdata?lat=-41.289731314547936&lng=174.77500218126283
 * This seems to return a JSON5 top-level array of stop information that
I need to parse into a dictionary per tutorial. Seems pretty close match. Can I find
 the current map view centre anywhere?
 
 * If I have a current HTTP fetch for stops underway I should probably
   cancel it
 * I should probably permanently store stop data and somehow "know" if the
   region I'm viewing has no data in it, but for now could just re-fetch every
   time and repopulate.

 
 */

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
