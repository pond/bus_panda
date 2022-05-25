//
//  StopMapViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#import "StopMapViewController.h"

#import "DataManager.h"
#import "ErrorPresenter.h"
#import "StopInfoFetcher.h"
#import "StopLocation.h"
#import "DetailViewController.h"
#import "UsefulTypes.h"

@interface StopMapViewController ()

@property ( strong            ) NSMutableDictionary * stopsAddedToMap;
@property ( weak              ) NSTimer             * stopLocationUpdateTimer;
@property ( nonatomic, assign ) BOOL                  showNearbyStops;
@property ( nonatomic, assign ) BOOL                  mapLocationHasBeenUpdated;

- ( void ) updateMapWithOrWithoutLocation;
- ( void ) spinnerOn;
- ( void ) spinnerOff;
- ( void ) cancelStopLocationUpdate;
- ( void ) scheduleStopLocationUpdate;
- ( void ) getStopsForCurrentMapRange;
- ( void ) addStopsToMap: ( NSArray * ) stops;
- ( void ) addCachedStopsToMap;

@end

// Delay before a request is sent to MetLink to get stops for the current
// map view, in seconds.
//
#define STOP_LOCATION_UPDATE_TIMER_DELAY ( double ) 0.5

// Radius (m) for the typical starting view of the map view, for far out and
// nearby views respectively.
//
#define DEFAULT_FAR_RADIUS  2000
#define DEFAULT_NEAR_RADIUS 350

@implementation StopMapViewController

///////////////////////////////////////////////////////////////////////////////
#pragma mark Standard view lifecycle
///////////////////////////////////////////////////////////////////////////////

// Set up the map and start a (delayed) bus stop location update when the view
// first loads, but not every time it appears; that happens when another view
// controller is pushed on top of it in the stack, but subsequently closes. It
// would be wrong to reset the map position and reload stops in such cases.
// Likewise only request location updates and update the map view according to
// user location on that first load, not subsequent appearances.
//
- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    self.locationManager          = [ [ CLLocationManager alloc ] init ];
    self.locationManager.delegate = self;

    [ self.locationManager requestWhenInUseAuthorization ];

    [ self updateMapWithOrWithoutLocation ];
    [ self scheduleStopLocationUpdate     ];
}

// The detail view used for showing schedules when previewing a stop for
// addition includes a toolbar that's normally hidden, though we use it
// when pushed onto the stack in this context for an 'Add stop' button.
// When the map is visible, though, the stack's toolbar should be hidden.
//
// This is also a good time to ask Location Services to start updates.
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];

    [ self.navigationController setToolbarHidden: YES animated: NO ];

    if ( [ CLLocationManager authorizationStatus ] == kCLAuthorizationStatusAuthorizedWhenInUse )
    {
        [ self.locationManager startUpdatingLocation ];
    }
}

// As a precaution, make sure the network spinner is definitely cancelled
// when the application is closed.
//
// This is also a good time to ask Location Services to stop updates.
//
- ( void ) viewWillDisappear: ( BOOL ) animated
{
    [ super viewWillDisappear: animated ];

    [ self cancelStopLocationUpdate ];
    [ self spinnerOff               ];

    if ( [ CLLocationManager authorizationStatus ] == kCLAuthorizationStatusAuthorizedWhenInUse )
    {
        [ self.locationManager stopUpdatingLocation ];
    }
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark Custom behaviour
///////////////////////////////////////////////////////////////////////////////

// Override base class - if we're in "nearby stops" mode, then this view is
// in its own tab and we should switch back to the "favourites" tab to show
// the user that addition happened.
//
- ( void ) dismissAdditionView
{
    [ super dismissAdditionView ];

    if ( self.showNearbyStops == YES )
    {
        [ self.navigationController popToRootViewControllerAnimated: YES ];
    }
}

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

// Permanently set this instance up so that its initial map view state will
// be for a close zoomed-in "nearby stops" view.
//
- ( void ) configureForNearbyStops
{
    self.showNearbyStops = YES;
    [ self updateMapWithOrWithoutLocation ];
}

// In STOP_LOCATION_UPDATE_TIMER_DELAY seconds, call method
// -getStopsForCurrentMapRange. Cancels any prior scheduled calls first.
//
// In passing, any cached stops within the map's visible range are added
// immediately. This gives the user near-instant feedback if prior data is
// available but does not prevent the (time-delayed) background update which
// might add in additional coverage, or update the location of any stops that
// turn out to have moved.
//
- ( void ) scheduleStopLocationUpdate
{
    [ self cancelStopLocationUpdate ];
    [ self addCachedStopsToMap      ];

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

// Ask StopInfoFetcher to retrieve stop information for the map's current
// centre location and visible radius based on the view's diagonal measurement.
//
// Either add/update the map accordingly or report an error to the user.
//
- ( void ) getStopsForCurrentMapRange
{
    CLLocationCoordinate2D centerLocation = self.mapView.region.center;
    CLLocationDistance     radius;

    MKMapRect  mRect     = self.mapView.visibleMapRect;
    MKMapPoint minCorner = MKMapPointMake( MKMapRectGetMinX( mRect ), MKMapRectGetMinY( mRect ) );
    MKMapPoint maxCorner = MKMapPointMake( MKMapRectGetMaxX( mRect ), MKMapRectGetMaxY( mRect ) );

    radius = MKMetersBetweenMapPoints( minCorner, maxCorner ) / 2;

    [ self spinnerOn ];

    [
        StopInfoFetcher getStopsWithinRadius: radius
                                  ofLocation: centerLocation
                           completionHandler:

        ^ ( NSMutableArray * allStops, NSError * error )
        {
            if ( error != nil )
            {
                [ self spinnerOff ];

                [
                    ErrorPresenter showModalAlertFor: self
                                           withError: error
                                               title: @"Cannot show stops"
                                          andHandler: ^( UIAlertAction *action )
                    {
                        [ self dismissAdditionView ];
                    }
                ];
            }
            else
            {
                [ self addStopsToMap: allStops ];
            }
        }
    ];

}

// Given a collection of stops from the StopInfoFetcher class, add any new
// related map annotations or update any which seem to be incorrect.
//
- ( void ) addStopsToMap: ( NSArray * ) stops
{
    BOOL anyAdded = NO;

    // Lazy-initialise the local stop-added-to-map flag store and get hold of
    // the AppDelegate's full stop information cache.

    if ( self.stopsAddedToMap == nil )
    {
        self.stopsAddedToMap = [ [ NSMutableDictionary alloc ] init ];
    }

    NSMutableDictionary * stopLocations =
    [
        DataManager.dataManager getCachedStopLocationDictionary
    ];

    // Now processes all the (possibly) new stops from the parsed JSON data.

    for ( NSDictionary * stop in stops )
    {
        NSString   * stopID          = stop[ @"stopID"          ];
        NSString   * stopDescription = stop[ @"stopDescription" ];
        CLLocation * stopLocation    = stop[ @"stopLocation"    ];

        // Examine any existing annotation info for this stop ID.

        NSDictionary * existingAnnotationInfo = stopLocations[ stopID ];

        // If there seems to be an existing annotation for this stop, make
        // sure that it hasn't either moved or changed description. If it has,
        // remove that existing annotation, delete it from the dictionary of
        // known stops and clear the local variable recording the old one.
        //
        if ( existingAnnotationInfo )
        {
            CLLocation * existingLocation    = existingAnnotationInfo[ @"location"    ];
            NSString   * existingDescription = existingAnnotationInfo[ @"description" ];

            if ( [ existingLocation distanceFromLocation: stopLocation ] != 0 ||
                 [ stopDescription isEqualToString: existingDescription ] == NO )
            {
                StopLocation * existingAnnotation = existingAnnotationInfo[ @"annotation" ];

                [ stopLocations removeObjectForKey: stopID ];

                [ self.mapView removeAnnotation: existingAnnotation ];
                [ self.stopsAddedToMap removeObjectForKey: stopID ];

                existingAnnotationInfo = nil;
            }
        }

        // If there is no existing annotation for this stop, or if an outdated
        // existing annotation was removed by the code above, add it to the
        // cache now.
        //
        if ( existingAnnotationInfo == nil )
        {
            StopLocation * annotation =
            [
                [ StopLocation alloc ] initWithStopID: stopID
                                          description: stopDescription
                                           coordinate: stopLocation.coordinate
            ];

            if ( annotation )
            {
                NSDictionary * stopInfo =
                @{
                    @"location":    stopLocation,
                    @"description": stopDescription,
                    @"annotation":  annotation
                };

                stopLocations[ stopID ] = existingAnnotationInfo = stopInfo;
            }
        }

        // Hopefully we've either a previously cached or new set of full stop
        // and annotation information available. If this hasn't been added to
        // this local map view yet, add it now.
        //
        if ( existingAnnotationInfo != nil && self.stopsAddedToMap[ stopID ] == nil )
        {
            [ self.mapView addAnnotation: existingAnnotationInfo[ @"annotation" ] ];
            self.stopsAddedToMap[ stopID ] = @( YES );

            anyAdded = YES;
        }
    }

    // If no stops were ultimately added, the 'stop network activity spinner
    // when the views-were-all-added call happens' thing won't work, obviously.
    // So stop it here instead.
    //
    if ( anyAdded == NO ) [ self spinnerOff ];
}

// Add any stops cached in the AppDelegate's storage via a prior call to
// "-addStopsToMapUsingData:" to the current map view, for any stops that have
// not yet been added. Only stops in the map's visible range are added, only
// stops in the cache will be considered and only stops that aren't internally
// marked as already added to 'this' map view instance will be processed.
//
- ( void ) addCachedStopsToMap
{
    if ( self.stopsAddedToMap == nil )
    {
        self.stopsAddedToMap = [ [ NSMutableDictionary alloc ] init ];
    }

    NSMutableDictionary * stopLocations =
    [
        DataManager.dataManager getCachedStopLocationDictionary
    ];

    for ( id stopID in stopLocations )
    {
        if ( self.stopsAddedToMap[ stopID ] != nil ) continue;

        NSDictionary           * stopInfo = stopLocations[ stopID ];
        CLLocationCoordinate2D   stopCoordinate;

        stopCoordinate.latitude  = [ stopInfo[ @"latitude"  ] doubleValue ];
        stopCoordinate.longitude = [ stopInfo[ @"longitude" ] doubleValue ];

        // 2016-04-03 (ADH): Although this seems a reasonable optimisation,
        // in most cases having the full circle around the current location
        // populated is useful and saves time if the user pans around at all
        // away from that. It's also wasteful, given the number of times that
        // this "add cached stops" method gets called in practice due to
        // location-updated callbacks triggering so often, to have to keep
        // asking over and over if the map contains a stopped cache location
        // and only add it if so. Better to add it so "stopsAddedToMap" lets
        // us loop early and avoid a lot of repeated calculation.

//        if (
//               MKMapRectContainsPoint
//               (
//                   self.mapView.visibleMapRect,
//                   MKMapPointForCoordinate( stopCoordinate )
//               )
//           )
//        {
            [ self.mapView addAnnotation: stopLocations[ stopID ][ @"annotation" ] ];
            self.stopsAddedToMap[ stopID ] = @( YES );
//        }
    }
}

// Update the map view to show a default radius region either centred around
// a map that's expecting location updates and shows the user's location or,
// if authorisation for that is not available, has a default location around
// the Wellington CBD and does not show the user's position. Call any time
// you think that location information authorisation might have changed.
//
- ( void ) updateMapWithOrWithoutLocation
{
    CLLocationCoordinate2D zoomLocation;

    if ( [ CLLocationManager authorizationStatus ] == kCLAuthorizationStatusAuthorizedWhenInUse )
    {
        [ self.mapView setShowsUserLocation: YES ];

        self.locationManager.distanceFilter  = kCLDistanceFilterNone;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;

        zoomLocation.latitude  = self.locationManager.location.coordinate.latitude;
        zoomLocation.longitude = self.locationManager.location.coordinate.longitude;
    }
    else
    {
        [ self.mapView setShowsUserLocation: NO ];

        zoomLocation.latitude  = -41.294649;
        zoomLocation.longitude = 174.772871;
    }

    // If configured to show nearby stops (see '-configureForNearbyStops') then the
    // map view diagonal measurement is ignored and a fixed 250m radius is used.
    //
    CLLocationDistance radius = self.showNearbyStops ? DEFAULT_NEAR_RADIUS : DEFAULT_FAR_RADIUS;

    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(
        zoomLocation,
        radius,
        radius
    );
    
    [ self.mapView setRegion: [ self.mapView regionThatFits: viewRegion ] animated: YES ];
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark MKMapViewDelegate protocol
///////////////////////////////////////////////////////////////////////////////

// MKMapViewDelegate protocol. Called when annotations have been added. This is
// in theory going to happen possibly a while after the stop location URI fetch
// completes, while iOS's map engine crunches through the additions; so we use
// this as a last-possible time to stop the network indicator.
//
- ( void )      mapView: ( MKMapView                            * ) mapView
  didAddAnnotationViews: ( nonnull NSArray <MKAnnotationView *> * ) views
{
    [ self spinnerOff ];
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

// MKMapViewDelegate protocol. Called if user location data is available and
// that user's location has changed; we update the view to keep the location
// roughly central.
//
// This is only done once, to catch any initial location updates that might
// have happened since the map was last shown. We don't subsequently track
// the user's movement, either here (location updates would "argue with" any
// manual scroll/zoom set by the user and keep resetting the map; infruiating)
// or via MKUserTrackingModeFollow, even for 'stops nearby'. We expect the map
// to be used as a bus stop browser, not as a route tracker.
//
- ( void )      mapView: ( MKMapView      * ) mapView
  didUpdateUserLocation: ( MKUserLocation * ) userLocation
{
    if ( self.mapLocationHasBeenUpdated == NO )
    {
        self.mapLocationHasBeenUpdated = YES;

        [ self.mapView setCenterCoordinate: userLocation.coordinate
                                  animated: YES ];
    }
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark CLLocationManagerDelegate protocol
///////////////////////////////////////////////////////////////////////////////

// CLLocationManagerDelegate protocol. Called if authorisation to use the
// user's location changes. We update the map to either show that location,
// or reset it to the default 'centre of wellington' coordinates.
//
- ( void )     locationManager: ( CLLocationManager     * ) manager
  didChangeAuthorizationStatus: ( CLAuthorizationStatus   ) status
{
    [ self updateMapWithOrWithoutLocation ];
}

///////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
///////////////////////////////////////////////////////////////////////////////

// Add a new favourite stop based on the assumption that a DetailViewController
// is at the top of the navigation stack and its detail item has information on
// the Stop ID and Stop Description.
//
- ( IBAction ) addStop: ( id ) sender
{
    DetailViewController * controller = [ [ self.navigationController viewControllers ] lastObject ];
    id                     detailItem = controller.detailItem;

    [ self addFavourite: [ detailItem valueForKey: @"stopID" ]
        withDescription: [ detailItem valueForKey: @"stopDescription" ] ];

    [ self dismissAdditionView ];
}

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

    [ self.mapView removeAnnotations: self.mapView.annotations ];
    self.stopsAddedToMap = nil;

    [ DataManager.dataManager clearCachedStops ];

    [ self getStopsForCurrentMapRange ];
}

@end
