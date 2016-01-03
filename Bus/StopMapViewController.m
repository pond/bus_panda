//
//  StopMapViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import "StopMapViewController.h"

#import "StopLocation.h"
#import "DetailViewController.h"
#import "UsefulTypes.h"

@interface StopMapViewController ()

@property ( weak   ) NSTimer             * stopLocationUpdateTimer;
@property ( strong ) NSMutableDictionary * stopLocations;

- ( void ) spinnerOn;
- ( void ) spinnerOff;
- ( void ) cancelStopLocationUpdate;
- ( void ) scheduleStopLocationUpdate;
- ( void ) getStopsForCurrentMapRange;
- ( void ) addStopsToMapUsingData: ( NSData * ) data;

@end

// Delay before a request is sent to MetLink to get stops for the current
// map view, in seconds.
//
#define STOP_LOCATION_UPDATE_TIMER_DELAY ( double ) 0.5

@implementation StopMapViewController

///////////////////////////////////////////////////////////////////////////////
#pragma mark Standard view lifecycle
///////////////////////////////////////////////////////////////////////////////

// Set up the map and start a (delayed) bus stop location update when the view
// first loads, but not every time it appears; that happens when another view
// controller is pushed on top of it in the stack, but subsequently closes. It
// would be wrong to reset the map position and reload stops in such cases.
//
- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    CLLocationCoordinate2D zoomLocation;

    zoomLocation.latitude  = -41.294649;
    zoomLocation.longitude = 174.772871;

    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(
      zoomLocation,
      5000,
      5000
    );

    [ self.mapView setRegion: viewRegion animated: YES ];
    [ self scheduleStopLocationUpdate ];
}

// The detail view used for showing schedules when previewing a stop for
// addition includes a toolbar that's normally hidden, though we use it
// when pushed onto the stack in this context for an 'Add stop' button.
// When the map is visible, though, the stack's toolbar should be hidden.
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];
    [ self.navigationController setToolbarHidden: YES animated: NO ];
}

// As a precaution, make sure the network spinner is definitely cancelled
// when the application is closed.
//
- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ super viewWillDisappear: animated ];

    [ self cancelStopLocationUpdate ];
    [ self spinnerOff ];
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark Custom behaviour
///////////////////////////////////////////////////////////////////////////////

// Turn on an activity indicator of some sort. At the time of writing this
// comment, the network activity indicator in the status bar is used. See
// also -spinnerOff.
//
- ( void ) spinnerOn
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
}

// Turn off the activity indicator started with -spinnerOn.
//
- ( void ) spinnerOff
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
}

// In STOP_LOCATION_UPDATE_TIMER_DELAY seconds, call method
// -getStopsForCurrentMapRange. Cancels any prior scheduled calls first.
//
- ( void ) scheduleStopLocationUpdate
{
    [ self cancelStopLocationUpdate ];

    self.stopLocationUpdateTimer =
    [
        NSTimer scheduledTimerWithTimeInterval: STOP_LOCATION_UPDATE_TIMER_DELAY
                                        target: self
                                      selector: @selector( getStopsForCurrentMapRange )
                                      userInfo: nil
                                       repeats: NO
    ];
}

// Cancel a scheduled bus stop location update timer and clear the reference to
// it, for good measure. Safe to call if none is scheduled anyway.
//
- ( void ) cancelStopLocationUpdate
{
    [ self.stopLocationUpdateTimer invalidate ];
    self.stopLocationUpdateTimer = nil;
}

// Retrieve the stops for the map centre coordinates using the only currently
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
- ( void ) getStopsForCurrentMapRange
{
    MKMapRect  mRect         = self.mapView.visibleMapRect;
    MKMapPoint minCorner     = MKMapPointMake( MKMapRectGetMinX( mRect ), MKMapRectGetMinY( mRect ) );
    MKMapPoint maxCorner     = MKMapPointMake( MKMapRectGetMaxX( mRect ), MKMapRectGetMaxY( mRect ) );

    CLLocationDistance     viewDiagonal   = MKMetersBetweenMapPoints( minCorner, maxCorner );
    CLLocationCoordinate2D centerLocation = self.mapView.region.center;

    NSString * centreEnumerationURI =
    [
        NSString stringWithFormat: @"https://www.metlink.org.nz/stop/nearbystopdata?lat=%f&lng=%f&radius=%f",
        centerLocation.latitude,
        centerLocation.longitude,
        viewDiagonal / 2
    ];

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
        if ( error != nil || [ response isKindOfClass: [ NSHTTPURLResponse class ] ] == NO )
        {
            // TODO: Error handling
            //
            [ self spinnerOff ];
        }
        else
        {
            // Conceptually we should check for e.g. application/json, but all
            // responses from MetLink at the time of writing are served up as
            // text/html, be they a real HTML 404 response, or raw JSON. Doh.
            //
            // NSDictionary * headers     = [ ( NSHTTPURLResponse * ) response allHeaderFields ];
            // NSString     * contentType = headers[ @"Content-Type" ];

            [ self performSelectorOnMainThread: @selector( addStopsToMapUsingData: )
                                    withObject: data
                                 waitUntilDone: YES ];
        }
    };

    NSURL        * URL     = [ NSURL URLWithString: centreEnumerationURI ];
    NSURLSession * session = [ NSURLSession sharedSession ];

    [ self spinnerOn ];

    [ [ session dataTaskWithURL: URL completionHandler: completionHandler ] resume ];
}

// Given a collection of stops in a JSON array encoded into the given
// NSData object (as JSON5 - a root-level array), addding any new map
// annotations as required or updating any which seem to be incorrect.
//
- ( void ) addStopsToMapUsingData: ( NSData * ) data
{
    NSDictionary * stops;
    BOOL           anyAdded = NO;

    // Try to parse what *should* be a JSON5 array.

    @try
    {
        stops = [ NSJSONSerialization JSONObjectWithData: data options: 0 error: nil ];

    }
    @catch ( NSException * exception ) // Assumed JSON processing error
    {
        // TODO: Error handling

        return [ self spinnerOff ];
    }

    // Lazy-initialise the local stop location store, then process the new
    // array of items.

    if ( self.stopLocations == nil )
    {
        self.stopLocations = [ [ NSMutableDictionary alloc ] init ];
    }

    for ( NSDictionary * stop in stops )
    {
        // First extract information from the JSON dictionary. Bail out if the
        // public stop ID string cannot be found (under the "Sms" key (!)).

        NSString * stopID = stop[ @"Sms" ];

        if ( stopID == nil ) continue;

        NSString * stopDescription = stop[ @"Name" ];

        if ( stopDescription == nil ) stopDescription = @"";

        double latitude  = [ ( NSString * ) stop[ @"Lat"  ] doubleValue ];
        double longitude = [ ( NSString * ) stop[ @"Long" ] doubleValue ];

        CLLocationCoordinate2D stopCoordinate;

        stopCoordinate.latitude  = latitude;
        stopCoordinate.longitude = longitude;

        // Examine any existing annotation info for this stop ID.

        NSDictionary * existingAnnotationInfo = self.stopLocations[ stopID ];

        // If there seems to be an existing annotation for this stop, make
        // sure that it hasn't either moved or changed description. If it has,
        // remove that existing annotation, delete it from the dictionary of
        // known stops and clear the local variable recording the old one.

        if ( existingAnnotationInfo )
        {
            NSNumber * existingLatitude    = existingAnnotationInfo[ @"latitude"    ];
            NSNumber * existingLongitude   = existingAnnotationInfo[ @"longitude"   ];
            NSString * existingDescription = existingAnnotationInfo[ @"description" ];

            if ( [ existingLatitude  doubleValue ] != latitude  ||
                 [ existingLongitude doubleValue ] != longitude ||
                 [ stopDescription isEqualToString: existingDescription ] == NO )
            {
                StopLocation * existingAnnotation = existingAnnotationInfo[ @"annotation" ];

                [ self.mapView removeAnnotation: existingAnnotation ];
                [ self.stopLocations removeObjectForKey: stopID ];

                existingAnnotationInfo = nil;
            }
        }

        // If there is no existing annotation for this stop, or if an outdated
        // existing annotation was removed by the code above, add it now.

        if ( existingAnnotationInfo == nil )
        {
            StopLocation * annotation =
            [
                [ StopLocation alloc ] initWithStopID: stopID
                                          description: stopDescription
                                           coordinate: stopCoordinate
            ];

            if ( stopDescription && annotation )
            {
                NSDictionary * stopInfo = @{
                    @"latitude":    @( latitude  ),
                    @"longitude":   @( longitude ),
                    @"description": stopDescription,
                    @"annotation":  annotation
                };

                self.stopLocations[ stopID ] = stopInfo;

                [ self.mapView addAnnotation: annotation ];
            }

            anyAdded = YES;
        }
    }

    // If no stops were ultimately added, the 'stop network activity spinner
    // when the views-were-all-added call happens' thing won't work, obviously.
    // So stop it here instead.

    if ( anyAdded == NO )
    {
        UIApplication.sharedApplication.networkActivityIndicatorVisible = false;
    };
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark MKMapViewDelegate protocol
///////////////////////////////////////////////////////////////////////////////

// MKMapViewDelegate protocol. Called when annotations have been added. This is
// in theory going to happen possibly a while after the stop location URI fetch
// completes, while iOS's map engine crunches through the additions; so we use
// this as a last-possible time to stop the network indicator.
//
- ( void )    mapView: ( MKMapView                            * ) mapView
didAddAnnotationViews: ( nonnull NSArray <MKAnnotationView *> * ) views
{
    UIApplication.sharedApplication.networkActivityIndicatorVisible = false;
}

// MKMapViewDelegate protocol. Called when the map changes position / zoom.
//
- ( void )        mapView: ( MKMapView * ) mapView
  regionDidChangeAnimated: ( BOOL        ) animated
{
    [ self scheduleStopLocationUpdate ];
}

// MKMapViewDelegate protocol. Called when the map wants to get a new view for
// an annotation, or wants to recycle one.
//
- ( MKAnnotationView * ) mapView: ( MKMapView         * ) mapView
               viewForAnnotation: ( id <MKAnnotation>   ) annotation
{
    static NSString * identifier = @"StopLocation";

    if ( [ annotation isKindOfClass: [ StopLocation class ] ] )
    {
        MKPinAnnotationView * annotationView = ( MKPinAnnotationView * )
        [
            _mapView dequeueReusableAnnotationViewWithIdentifier: identifier
        ];

        if ( annotationView == nil )
        {
            annotationView = [ [ MKPinAnnotationView alloc ] initWithAnnotation: annotation
                                                                reuseIdentifier: identifier ];

            annotationView.enabled                   = YES;
            annotationView.canShowCallout            = YES;
            annotationView.rightCalloutAccessoryView =
            [
                UIButton buttonWithType: UIButtonTypeDetailDisclosure
            ];
        }
        else
        {
            annotationView.annotation = annotation;
        }

        return annotationView;
    }

    return nil;
}

// MKMapViewDelegate protocol. Called when any part of the 'callout' view
// shown once a pin is tapped, is itself tapped upon. We don't care what part
// of the view was tapped.
//
- ( void )            mapView: ( MKMapView        * ) mapView
               annotationView: ( MKAnnotationView * ) view
calloutAccessoryControlTapped: ( UIControl        * ) control
{
    DetailViewController * controller =
    [
        self.storyboard instantiateViewControllerWithIdentifier: @"ListOfServices"
    ];

    NSDictionary * detailItem =
    @{
        @"stopID":          view.annotation.title,
        @"stopDescription": view.annotation.subtitle
    };

    [ controller setDetailItem: detailItem ];

    UIBarButtonItem * additionButton =
    [
       [ UIBarButtonItem alloc ] initWithTitle: @"Add"
                                         style: UIBarButtonItemStylePlain
                                        target: self
                                        action: @selector( addStop: )
    ];

    controller.navigationItem.rightBarButtonItem = additionButton;

    [ self.navigationController pushViewController: controller animated: YES ];
}

- ( IBAction ) addStop: ( id ) sender
{
    DetailViewController * controller = [ [ self.navigationController viewControllers ] lastObject ];
    id                     detailItem = controller.detailItem;

    [ self addFavourite: [ detailItem valueForKey: @"stopID" ]
        withDescription: [ detailItem valueForKey: @"stopDescription" ] ];

    [ self dismissAdditionView ];
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
///////////////////////////////////////////////////////////////////////////////

// Via the superclass, cancel this view.
//
- ( IBAction ) toolbarCancelPressed: ( id ) sender
{
    [ self dismissAdditionView ];
}

// Dump the local stop location cache, empty all map pins and reload.
//
- ( IBAction ) toolbarReloadPressed: ( id ) sender
{
    [ self cancelStopLocationUpdate ];

    self.stopLocations = nil;
    [ self.mapView removeAnnotations: self.mapView.annotations ];

    [ self getStopsForCurrentMapRange ];
}

@end
