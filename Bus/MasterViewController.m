//
//  MasterViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"
#import "ErrorPresenter.h"
#import "MasterViewController.h"
#import "DetailViewController.h"
#import "EnterStopIDViewController.h"
#import "EditStopDescriptionViewController.h"
#import "StopMapViewController.h"
#import "FavouritesCell.h"

#define CLOUDKIT

@implementation MasterViewController

#pragma mark - View lifecycle

- ( void ) awakeFromNib
{
    [ super awakeFromNib ];

    if ( [ [ UIDevice currentDevice ] userInterfaceIdiom ] == UIUserInterfaceIdiomPad )
    {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize            = CGSizeMake( 320.0, 600.0 );
    }
}

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    //
    self.clearsSelectionOnViewWillAppear = NO;

    UIBarButtonItem * addButton =
    [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd
                                                       target: self
                                                       action: @selector( openAddStopModal: )
    ];

    self.navigationItem.leftBarButtonItem  = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = addButton;

    self.detailViewController = ( DetailViewController * )
    [
        [ self.splitViewController.viewControllers lastObject ] topViewController
    ];

    // Add a custom notification handler to refresh data. This is triggered
    // when, for example, data changes in iCloud.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( reloadFetchedResults: )
                                                    name: DATA_CHANGED_NOTIFICATION_NAME // AppDelegate.h
                                                  object: [ [ UIApplication sharedApplication ] delegate ] ];

    // Add an observer triggered whenever the Core Data list of favourite
    // stops changes; this is used to update the Watch.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( updateWatch: )
                                                    name: NSManagedObjectContextObjectsDidChangeNotification
                                                  object: [ [ UIApplication sharedApplication ] delegate ] ];

    // Watch for user defaults changes as we'll need to reload the table data
    // to reflect things like a 'shorten names to fit' settings change.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( defaultsDidChange: )
                                                    name: NSUserDefaultsDidChangeNotification
                                                  object: nil ];

    // We don't try an update the Apple Watch app here because we don't
    // necessarily have full access to Core Data yet. Instead, let the App
    // Delegate deal with at-wakeup updates by calling through to our
    // "-updateWatch:" method once it's set the 'managedObjectContext'
    // property in this instance.
}

// http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];
    [ self.tableView deselectRowAtIndexPath: [ self.tableView indexPathForSelectedRow ]
                                   animated: animated ];
}

- ( void ) dealloc
{
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self ];
}

#pragma mark - Modal handling

- ( void ) openSpecificModal: ( id ) modal
{
    [
        self presentViewController: modal
                          animated: YES
                        completion: nil
    ];
}

- ( void ) openAddStopModal: ( id ) sender
{
    UIAlertController * actions =
    [
        UIAlertController alertControllerWithTitle: nil
                                           message: nil
                                    preferredStyle: UIAlertControllerStyleActionSheet
    ];

    UIAlertAction * stopMapAction =
    [
        UIAlertAction actionWithTitle: @"Add Using Map"
                                style: UIAlertActionStyleDefault
                              handler: ^ ( UIAlertAction * action )
        {
            UINavigationController * stopMapNavigationController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"StopMap"
            ];

            [ self openSpecificModal: stopMapNavigationController ];
        }
    ];

    UIAlertAction * enterStopIDAction =
    [
        UIAlertAction actionWithTitle: @"Add by Stop ID"
                                style: UIAlertActionStyleDefault
                              handler: ^ ( UIAlertAction * action )
        {
            UINavigationController * enterStopIDNavigationController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"EnterStopID"
            ];

            [ self openSpecificModal: enterStopIDNavigationController ];
        }
    ];

//  UIAlertAction * nearbyStopsAction =
//  [
//      UIAlertAction actionWithTitle: @"Nearby Stops"
//                              style: UIAlertActionStyleDefault
//                            handler: ^ ( UIAlertAction * action )
//      {
//          UINavigationController * stopMapNavigationController =
//          [
//              self.storyboard instantiateViewControllerWithIdentifier: @"StopMap"
//          ];
//
//          StopMapViewController * stopMapController = ( StopMapViewController * ) stopMapNavigationController.topViewController;
//
//          [ stopMapController configureForNearbyStops   ];
//          [ stopMapController setTitle: @"Nearby Stops" ];
//
//          [ self openSpecificModal: stopMapNavigationController ];
//      }
//  ];

    UIAlertAction * cancel =
    [
        UIAlertAction actionWithTitle: @"Cancel"
                                style: UIAlertActionStyleCancel
                              handler: ^ ( UIAlertAction * action )
        {
            [ actions dismissViewControllerAnimated: ( YES ) completion: nil ];
        }
    ];

    [ actions addAction: stopMapAction     ];
    [ actions addAction: enterStopIDAction ];
//  [ actions addAction: nearbyStopsAction ];
    [ actions addAction: cancel            ];

    // On the iPhone (at the time of writing) modal action sheets implicitly
    // always pop up over the whole screen. On an iPad, you need to tell the
    // system where to ground the popover - in this case the "+" button that
    // caused the action method here to be run in the first place.
    //
    actions.popoverPresentationController.barButtonItem = sender;

    [ self presentViewController: actions animated: YES completion: nil ];
}

- ( void ) openMoreOptionsModalFrom: ( id ) sender
                          forObject: ( NSManagedObject * ) object
{
    UIAlertController * actions =
    [
        UIAlertController alertControllerWithTitle: nil
                                           message: nil
                                    preferredStyle: UIAlertControllerStyleActionSheet
    ];

    UIAlertAction * editAction =
    [
        UIAlertAction actionWithTitle: @"Edit Description"
                                style: UIAlertActionStyleDefault
                              handler: ^ ( UIAlertAction * action )
        {
            UINavigationController * editStopDescriptionNavigationController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"EditStopDescription"
            ];

            EditStopDescriptionViewController * editStopDescriptionController = editStopDescriptionNavigationController.childViewControllers.firstObject;
            editStopDescriptionController.sourceObject = object;

            [ self openSpecificModal: editStopDescriptionNavigationController ];
        }
    ];

    UIAlertAction * cancel =
    [
        UIAlertAction actionWithTitle: @"Cancel"
                                style: UIAlertActionStyleCancel
                              handler: ^ ( UIAlertAction * action )
        {
            [ actions dismissViewControllerAnimated: ( YES ) completion: nil ];
        }
    ];

    [ actions addAction: editAction ];
    [ actions addAction: cancel     ];

    // On the iPhone (at the time of writing) modal action sheets implicitly
    // always pop up over the whole screen. On an iPad, you need to tell the
    // system where to ground the popover - in this case the "+" button that
    // caused the action method here to be run in the first place.
    //
    actions.popoverPresentationController.barButtonItem = sender;

    [ self presentViewController: actions animated: YES completion: nil ];
}

#pragma mark - Adding and modifying favourites

// Utility method - call with a pointer to an NSError instance, which may be
// "nil", and a pointer to a title NSString shown in the error report if the
// NSError pointer is not "nil".
//
// Ensures that the error dialogue is shown on the main thread, so can be
// called from other threads safely.
//
- ( void ) handleError: ( NSError  * ) error
             withTitle: ( NSString * ) title
{
    if ( error )
    {
        dispatch_async(
            dispatch_get_main_queue(),
            ^ {
                [
                    ErrorPresenter showModalAlertFor: self
                                           withError: error
                                               title: title
                                          andHandler: ^( UIAlertAction *action ) {}
                ];
            }
        );
    }
}

// Utility method - save the given CloudKit record into the given CloudKit
// database, reporting an error to the user if it fails but taking no other
// remedial action. The third parameter is the title string to use if there
// is an error to report.
//
- ( void ) saveRecord: ( CKRecord   * ) record
           inDatabase: ( CKDatabase * ) database
         onErrorTitle: ( NSString   * ) errorTitle
{
    [
        database saveRecord: record
          completionHandler: ^ ( CKRecord * _Nullable record, NSError * _Nullable error )
        {
            [ self handleError: error withTitle: errorTitle ];
        }
    ];
}

- ( NSManagedObject * ) findFavouriteStopByID: ( NSString * ) stopID
{
    AppDelegate            * appDelegate = ( AppDelegate * ) [ [ UIApplication sharedApplication ] delegate ];
    NSError                * error       = nil;
    NSManagedObjectContext * moc         = [ appDelegate managedObjectContextLocal ];
    NSManagedObjectModel   * mom         = [ appDelegate managedObjectModel ];
    NSEntityDescription    * styleEntity = [ mom entitiesByName ][ @"BusStop" ];
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

// Create-or-update a favourite stop. Pass the stop ID. If an existing record
// is found, it'll be updated with the given stop description and preferred
// flag; else a new record will be created. Pass 'nil' for stopDescription if
// you want to preserve an existing value; default is to match stopID string
// for new records. Similarly, pass 'nil' for preferred flag if you want to
// preserve that; default is 'not preferred' for new records.
//
// Modifies the local table view first, then iCloud next, so that the UI is
// updated quickly rather than lagging as iCloud updates happen.
//
- ( void ) addOrEditFavourite: ( NSString * ) stopID
           settingDescription: ( NSString * ) stopDescription
             andPreferredFlag: ( NSNumber * ) preferred
{
    // First update local records.

    NSLog(@"ADD OR EDIT FAVOURITE");
    NSLog(@"StopID %@",          stopID);
    NSLog(@"stopDescription %@", stopDescription);
    NSLog(@"preferred %@",       preferred);

    BOOL                     oldShowSectionFlag = [ self shouldShowSectionHeaderFor: self.tableView ];
    NSNumber               * oldPreferred       = @( ! preferred.boolValue );
    NSManagedObject        * object             = [ self findFavouriteStopByID: stopID ];
    NSManagedObjectContext * context            = self.fetchedResultsController.managedObjectContext;
    NSError                * error              = nil;

    if ( object == nil )
    {
        object =
        [
            NSEntityDescription insertNewObjectForEntityForName: self.fetchedResultsController.fetchRequest.entity.name
                                         inManagedObjectContext: context
        ];

        [ object setValue: stopID forKey: @"stopID" ];

        if ( stopDescription == nil ) stopDescription = [ stopID copy ];
        if ( preferred       == nil ) preferred       = STOP_IS_NOT_PREFERRED_VALUE;
    }
    else
    {
        oldPreferred = [ object valueForKey: @"preferred" ];
    }

    if ( stopDescription != nil ) [ object setValue: stopDescription forKey: @"stopDescription" ];
    if ( preferred       != nil ) [ object setValue: preferred       forKey: @"preferred"       ];

    if ( ! [ context save: &error ] )
    {
        [
            ErrorPresenter showModalAlertFor: self
                                   withError: error
                                       title: NSLocalizedString( @"Could not change 'preferred' stop setting", "Error message shown when changing the 'preferred' setting fails" )
                                  andHandler: ^( UIAlertAction *action ) {}
        ];

        return;
    }

    // Avoid animation issues if the section headers appear or dispppear.
    //
    BOOL newShowSectionFlag = [ self shouldShowSectionHeaderFor: self.tableView ];
    if ( oldShowSectionFlag != newShowSectionFlag ) [ self.tableView reloadData ];

    if ( preferred.boolValue != oldPreferred.boolValue )
    {
        // If there's no section header than (A) is there only one favourite
        // stop, (B) is that stop now preferred and (C) have we detected this
        // condition before? If not, tell the user what's going on.
        //
        NSUserDefaults * defaults = [ NSUserDefaults standardUserDefaults ];

        if (
               newShowSectionFlag == NO &&
               self.fetchedResultsController.fetchedObjects.count == 1 &&
               [ [ self.fetchedResultsController.fetchedObjects[ 0 ] valueForKey: @"preferred" ] isEqual: STOP_IS_PREFERRED_VALUE ] &&
               [ defaults boolForKey: @"haveShownSingleSectionWarning" ] != YES
           )
        {
            [ defaults setBool: YES forKey: @"haveShownSingleSectionWarning" ];
            [ defaults synchronize ];

            UIAlertController * warning = [ UIAlertController alertControllerWithTitle: @"You have only one preferred and favourite stop"
                                                                               message: @"When you have a mixture of preferred and normal stops, they show up in different sections.\n\nOtherwise, you only see one list."
                                                                        preferredStyle: UIAlertControllerStyleAlert ];

            UIAlertAction * action = [ UIAlertAction actionWithTitle: @"Got it!"
                                                               style: UIAlertActionStyleDefault
                                                             handler: nil ];

            [ warning addAction: action ];
            [ self presentViewController: warning animated: YES completion: nil ];
        }
    }

    // Now update iCloud.

    CKContainer    * container  = [ CKContainer defaultContainer ];
    CKDatabase     * database   = [ container privateCloudDatabase ];
    CKRecordZoneID * zoneID     = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_ID ownerName: CKCurrentUserDefaultName ];
    CKRecordID     * recordID   = [ [ CKRecordID alloc ] initWithRecordName: stopID zoneID: zoneID ];
    NSString       * errorTitle = NSLocalizedString(
        @"Could not save changes in iCloud",
        @"Error message shown when trying to save favourite stop changes to iCloud"
    );

    [
        database fetchRecordWithID: recordID
                 completionHandler: ^ ( CKRecord * _Nullable record, NSError * _Nullable error )
        {
            if ( record == nil || error.code == CKErrorUnknownItem ) // (If 'error' is nil, dereference of code will be 'nil' and comparison will fail)
            {
                CKRecord * record = [ [ CKRecord alloc ] initWithRecordType: @"BusStop"
                                                                     zoneID: zoneID ];

                NSLog(@"NEW RECORD create %@", stopID);

                [ record setObject: stopID          forKey: @"recordName"      ];
                [ record setObject: stopDescription forKey: @"stopDescription" ];
                [ record setObject: preferred       forKey: @"preferred"       ];

                [ self saveRecord: record inDatabase: database onErrorTitle: errorTitle ];
            }
            else if ( error != nil )
            {
                NSLog(@"CLOUD KIT ERROR %@", error);
                [ self handleError: error withTitle: errorTitle ];
            }
            else
            {
                NSLog(@"EXISTING RECORD update %@", record);
                NSLog(@"(Record name %@)", [record valueForKey: @"recordName"]);

                if ( stopDescription != nil ) [ record setObject: stopDescription forKey: @"stopDescription" ];
                if ( preferred       != nil ) [ record setObject: preferred       forKey: @"preferred"       ];

                [ self saveRecord: record inDatabase: database onErrorTitle: errorTitle ];
            }
        }
    ];
}

- ( void ) deleteObject: ( NSString * ) stopID
{
    NSManagedObject * object = [ self findFavouriteStopByID: stopID ];
    if ( object == nil ) return; // Implies strange bug; don't trust data; bail out

    // First update local records.

    BOOL                     oldShowSectionFlag = [ self shouldShowSectionHeaderFor: self.tableView ];
    NSManagedObjectContext * context            = [ self.fetchedResultsController managedObjectContext ];
    NSError                * error              = nil;

    [ context deleteObject: object ];

    if ( ! [ context save: &error ] )
    {
        [
            ErrorPresenter showModalAlertFor: self
                                   withError: error
                                       title: NSLocalizedString( @"Could not delete favourite", "Error message shown when favourite stop deletion fails" )
                                  andHandler: ^( UIAlertAction *action ) {}
        ];
    }

    // Avoid animation issues if the section headers appear or dispppear.
    //
    BOOL newShowSectionFlag = [ self shouldShowSectionHeaderFor: self.tableView ];
    if ( oldShowSectionFlag != newShowSectionFlag ) [ self.tableView reloadData ];

    // Now update iCloud.

    CKContainer    * container  = [ CKContainer defaultContainer ];
    CKDatabase     * database   = [ container privateCloudDatabase ];
    CKRecordZoneID * zoneID     = [ [ CKRecordZoneID alloc ] initWithZoneName: CLOUDKIT_ZONE_ID ownerName: CKCurrentUserDefaultName ];
    CKRecordID     * recordID   = [ [ CKRecordID alloc ] initWithRecordName: stopID zoneID: zoneID ];
    NSString       * errorTitle = NSLocalizedString(
        @"Could not remove favourite from in iCloud",
        @"Error message shown when trying to remove favourite stop from iCloud"
    );

    [
        database fetchRecordWithID: recordID
                 completionHandler: ^ ( CKRecord * _Nullable record, NSError * _Nullable error )
        {
            if ( error != nil )
            {
                NSLog(@"CLOUD KIT ERROR %@", error);
                [ self handleError: error withTitle: errorTitle ];
            }
            else if ( record != nil )
            {
                NSLog(@"EXISTING RECORD delete %@", record);
                NSLog(@"(Record name %@)", [record valueForKey: @"recordName"]);

                [ self saveRecord: record inDatabase: database onErrorTitle: errorTitle ];
            }
        }
    ];

}

#pragma mark - Segues

- ( void ) prepareForSegue: ( UIStoryboardSegue * ) segue sender: ( id ) sender
{
    if ( [ [ segue identifier ] isEqualToString: @"showDetail" ] )
    {
        NSIndexPath          * indexPath  = [ self.tableView indexPathForSelectedRow ];
        NSManagedObject      * object     = [ [ self fetchedResultsController ] objectAtIndexPath: indexPath ];
        DetailViewController * controller = ( DetailViewController * ) [ [ segue destinationViewController ] topViewController ];

        [ controller setDetailItem: object ];

        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

#pragma mark - Table View

// Support method - returns YES if the section header should be shown for the
// table, else NO. The idea is to hide the section header when only one section
// is present, because all bus stops are either normal or preferred. Things go
// wrong in that case because we don't easily know e.g. the section title and
// it looks odd to just have a one-section table anyway.
//
// In the case where the user has just one new favourite stop and toggles it to
// a preferred state, it is a bit strange that no apparent change happens to
// the UI. To avoid that confusion, this specific special case is trapped with
// a one-time-only alert to let the user know what's happening.
//
- ( BOOL ) shouldShowSectionHeaderFor: ( UITableView * ) tableView
{
    NSInteger sectionCount = [ self numberOfSectionsInTableView: tableView ];
    return ( sectionCount < 2 ) ? NO : YES;
}

- ( NSInteger ) numberOfSectionsInTableView: ( UITableView * ) tableView
{
    return [ [ self.fetchedResultsController sections ] count ];
}

- ( NSInteger ) tableView: ( UITableView * ) tableView
    numberOfRowsInSection: ( NSInteger     ) section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [ self.fetchedResultsController sections ][ section ];
    return [ sectionInfo numberOfObjects ];
}

- ( NSString * ) tableView: ( UITableView * ) tableView
   titleForHeaderInSection: ( NSInteger     ) section
{
    // Show no section title unless there are at least two sections.

    if ( [ self shouldShowSectionHeaderFor: tableView ] == NO ) return @"";

    switch( section )
    {
        case 0:
            return NSLocalizedString( @"Preferred Stops", @"'Preferred' stops section title" );

        default:
            return NSLocalizedString( @"Other Stops", @"Non-'Preferred' stops section title" );
    }
}

- ( CGFloat )    tableView: ( UITableView * ) tableView
  heightForHeaderInSection: ( NSInteger     ) section
{
    // Show no section title unless there are at least two sections.

    if ( [ self shouldShowSectionHeaderFor: tableView ] == NO ) return 0;
    else                                                        return 32;
}

- ( void )    tableView: ( UITableView * ) tableView
  willDisplayHeaderView: ( UIView      * ) view
             forSection: ( NSInteger     ) section
{
    // Slightly darken the near-invisible section header background colour.

    UITableViewHeaderFooterView * hfView = ( UITableViewHeaderFooterView * ) view;
    hfView.backgroundView.backgroundColor = [ UIColor colorWithRed: 0.9 green: 0.9 blue: 0.9 alpha: 1 ];
}

- ( UITableViewCell * ) tableView: ( UITableView * ) tableView
            cellForRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    FavouritesCell * cell = [ tableView dequeueReusableCellWithIdentifier: @"Cell"
                                                             forIndexPath: indexPath ];

    [ self configureCell: cell atIndexPath: indexPath ];

    return cell;
}

- ( BOOL )    tableView: ( UITableView * ) tableView
  canEditRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    return YES;
}

- ( void ) tableView: ( UITableView                 * ) tableView
  commitEditingStyle: ( UITableViewCellEditingStyle   ) editingStyle
   forRowAtIndexPath: ( NSIndexPath                 * ) indexPath
{
    if ( editingStyle == UITableViewCellEditingStyleDelete )
    {
        NSManagedObject * object = [ self.fetchedResultsController objectAtIndexPath: indexPath ];

        if ( object != nil )
        {
            [ self deleteObject: object ];
        }
    }
}

- ( void ) configureCell: ( FavouritesCell * ) cell atIndexPath: ( NSIndexPath * ) indexPath
{
    NSManagedObject * object          = [ self.fetchedResultsController objectAtIndexPath: indexPath ];
    NSString        * stopID          = [ object valueForKey: @"stopID"          ];
    NSString        * stopDescription = [ object valueForKey: @"stopDescription" ];

    cell.stopID.text          = stopID;
    cell.stopDescription.text = stopDescription;

    // MGSwipeTableCell extensions - see:
    //
    // https://github.com/MortimerGoro/MGSwipeTableCell

    MGSwipeButton * delete =
    [
        MGSwipeButton buttonWithTitle: NSLocalizedString( @"Delete", "Title of button in a table row for a bus stop, which deletes that stop" )
                      backgroundColor: [ UIColor redColor ]
                             callback:  ^ BOOL ( MGSwipeTableCell * sender )
        {
            [ self deleteObject: object ];
            return YES; // Yes => do slide the table row back to normal position
        }
    ];

    MGSwipeButton * more =
    [
        MGSwipeButton buttonWithTitle: NSLocalizedString( @"More...", "Title of button in a table row for a bus stop, which shows extra options" )
                      backgroundColor: [ UIColor grayColor ]
                             callback: ^ BOOL ( MGSwipeTableCell * sender )
        {
            [ self openMoreOptionsModalFrom: self.navigationItem.rightBarButtonItem
                                  forObject: object ];

            return YES; // Yes => do slide the table row back to normal position
        }
    ];

    MGSwipeButton * prefer =
    [
        MGSwipeButton buttonWithTitle: NSLocalizedString( @"Prefer", "Title of button in a table row for a bus stop, which flags that stop as 'preferred'" )
                      backgroundColor: [ UIColor colorWithRed: 0 green: 0.8 blue: 0 alpha: 1 ]
                             callback: ^ BOOL ( MGSwipeTableCell * sender )
        {
            [ self addOrEditFavourite: stopID
                   settingDescription: nil
                     andPreferredFlag: STOP_IS_PREFERRED_VALUE ];

            return YES; // Yes => do slide the table row back to normal position
        }
    ];

    MGSwipeButton * unprefer =
    [
        MGSwipeButton buttonWithTitle: NSLocalizedString( @"Demote", "Title of button in a table row for a bus stop, which flags that stop as normal / not 'preferred'" )
                      backgroundColor: [ UIColor blueColor ]
                             callback: ^ BOOL ( MGSwipeTableCell * sender )
        {
            [ self addOrEditFavourite: stopID
                   settingDescription: nil
                     andPreferredFlag: STOP_IS_NOT_PREFERRED_VALUE ];

            return YES; // Yes => do slide the table row back to normal position
        }
    ];

    if ( [ [ object valueForKey: @"preferred" ] isEqual: STOP_IS_PREFERRED_VALUE ] )
    {
        cell.rightButtons = @[ delete, unprefer, more ];
    }
    else
    {
        cell.rightButtons = @[ delete, prefer, more ];
    }
}

#pragma mark - Fetched results management

// Returns an existing NSFetchedResultsController instance or generates a new
// one when called for the first time.
//
- ( NSFetchedResultsController * ) fetchedResultsController
{
    if ( _fetchedResultsController != nil )
    {
        return _fetchedResultsController;
    }

    NSFetchRequest      * fetchRequest = [ [ NSFetchRequest alloc] init ];
    NSEntityDescription * entity       = [ NSEntityDescription entityForName: @"BusStop"
                                                      inManagedObjectContext: self.managedObjectContext ];

    [ fetchRequest setEntity:         entity ];
    [ fetchRequest setFetchBatchSize: 50     ];

    NSSortDescriptor * sortDescriptor1 = [ [ NSSortDescriptor alloc] initWithKey: @"preferred"
                                                                       ascending: NO ];

    NSSortDescriptor * sortDescriptor2 = [ [ NSSortDescriptor alloc] initWithKey: @"stopDescription"
                                                                       ascending: YES ];

    [ fetchRequest setSortDescriptors: @[ sortDescriptor1, sortDescriptor2 ] ];

    NSString * cacheName = @"BusStops";

    // Problems were seen in development once the 'preferred stops' feature was
    // introduced that were solved by deleting the existing cache data when the
    // NSFetchedResultsController instance is first created. Just in case any
    // users in the field might see something similar, this code is retained.
    //
    [ NSFetchedResultsController deleteCacheWithName: cacheName ];

    NSFetchedResultsController * frc = [ [ NSFetchedResultsController alloc ] initWithFetchRequest: fetchRequest
                                                                              managedObjectContext: self.managedObjectContext
                                                                                sectionNameKeyPath: @"preferred"
                                                                                         cacheName: cacheName ];
    frc.delegate = self;

    self.fetchedResultsController = frc;
    return _fetchedResultsController;
}

#pragma mark - NSNotificationCenter observers

// Reload results (i.e. favourites) from iCloud / local storage; "notification"
// parameter is ignored.
//
// If it is running, the WatchKit application is told about the new data too.
//
- ( void ) reloadFetchedResults: ( NSNotification * ) ignoredNotification
{
    NSError *error = nil;

    NSLog( @"Underlying data changed... Refreshing" );

    // Deal with the local changes first

    if ( ! [ self.fetchedResultsController performFetch: &error ] )
    {
        [
            ErrorPresenter showModalAlertFor: self
                                   withError: error
                                       title: @"Could not load favourites"
                                  andHandler: ^( UIAlertAction *action ) {}
        ];
    }

    [ self.tableView performSelectorOnMainThread: @selector( reloadData )
                                      withObject: nil
                                   waitUntilDone: NO ];

    [ self performSelectorOnMainThread: @selector( updateWatch: )
                            withObject: [ WCSession defaultSession ]
                         waitUntilDone: NO ];
}

// An observer on NSManagedObjectContextObjectsDidChangeNotification which
// re-sends all favourite stops to the Watch; "notification" parameter is
// ignored.
//
- ( void ) updateWatch: ( NSNotification * ) ignoredNotification
{
    if ( WCSession.isSupported )
    {
        WCSession * session = [ WCSession defaultSession ];
        BOOL        proceed;

        // The actiationState property for multiple Apple Watch support exists
        // in iOS 9.3 or later only.
        //
        if ( [ session respondsToSelector: @selector( activationState ) ] )
        {
            proceed = ( session.activationState == WCSessionActivationStateActivated ) ? YES : NO;
        }
        else
        {
            proceed = YES;
        }

        if ( session.reachable && proceed )
        {
            NSError        * error;
            NSMutableArray * allStops = [ [ NSMutableArray alloc ] init ];
            NSDictionary   * dictionary;
            NSInteger        sections = [ self numberOfSectionsInTableView: self.tableView ];

            for ( NSManagedObject * object in self.fetchedResultsController.fetchedObjects )
            {
                // If the table view thinks it only has one section, send all
                // stops; they're either all normal, or all preferred. If there
                // is more than one section then there is a mixture of stop
                // types - only send the preferred stops to the watch.

                if ( sections == 1 || [ [ object valueForKey: @"preferred" ] integerValue ] > 0 )
                {
                    [
                        allStops addObject:
                        @{
                            @"stopID":          [ object valueForKey: @"stopID"          ],
                            @"stopDescription": [ object valueForKey: @"stopDescription" ]
                        }
                    ];
                }
            }

            dictionary = @{ @"allStops": allStops };

            [ session updateApplicationContext: dictionary error: &error ];

            if ( error != nil )
            {
                NSLog( @"Error updating watch: %p", error.localizedDescription );
            }
        }
    }
}

// Called via NSNotificationCenter when the user defaults change;
// "notification" parameter is ignored.
//
- ( void ) defaultsDidChange: ( NSNotification * ) ignoredNotification
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^ ( void )
        {
            [ self.tableView reloadData ];
        }
    );
}

#pragma mark - Table updates from the controller

- ( void ) controllerWillChangeContent: ( NSFetchedResultsController * ) controller
{
    [ self.tableView beginUpdates ];
}

- ( void ) controller: ( NSFetchedResultsController     * ) controller
     didChangeSection: ( id <NSFetchedResultsSectionInfo> ) sectionInfo
              atIndex: ( NSUInteger                       ) sectionIndex
        forChangeType: ( NSFetchedResultsChangeType       ) type
{
    switch ( type )
    {
        case NSFetchedResultsChangeInsert:
        {
            [ self.tableView insertSections: [ NSIndexSet indexSetWithIndex: sectionIndex ]
                           withRowAnimation: UITableViewRowAnimationFade ];
        }
        break;

        case NSFetchedResultsChangeDelete:
        {
            [ self.tableView deleteSections: [ NSIndexSet indexSetWithIndex: sectionIndex ]
                           withRowAnimation: UITableViewRowAnimationFade ];
        }
        break;

        default: return;
    }
}

- ( void ) controller: ( NSFetchedResultsController * ) controller
      didChangeObject: ( id                           ) anObject
          atIndexPath: ( NSIndexPath                * ) indexPath
        forChangeType: ( NSFetchedResultsChangeType   ) type
         newIndexPath: ( NSIndexPath                * ) newIndexPath
{
    UITableView * tableView = self.tableView;

    switch ( type )
    {
        case NSFetchedResultsChangeInsert:
        {
            [ tableView insertRowsAtIndexPaths: @[ newIndexPath ]
                              withRowAnimation: UITableViewRowAnimationFade ];
        }
        break;

        case NSFetchedResultsChangeDelete:
        {
            [ tableView deleteRowsAtIndexPaths: @[ indexPath ]
                              withRowAnimation: UITableViewRowAnimationFade ];
        }
        break;

        case NSFetchedResultsChangeUpdate:
        {
            [ self configureCell: ( FavouritesCell * ) [ tableView cellForRowAtIndexPath: indexPath ]
                     atIndexPath: indexPath ];
        }
        break;

        case NSFetchedResultsChangeMove:
        {
            [ tableView deleteRowsAtIndexPaths: @[ indexPath    ] withRowAnimation: UITableViewRowAnimationFade ];
            [ tableView insertRowsAtIndexPaths: @[ newIndexPath ] withRowAnimation: UITableViewRowAnimationFade ];
        }
        break;

        default: return;
    }
}

- ( void ) controllerDidChangeContent: ( NSFetchedResultsController * ) controller
{
    [ self.tableView endUpdates ];
    [ self updateWatch: nil ];
}

// TODO possibly:
//
// Implementing the above methods to update the table view in response to
// individual changes may have performance implications if a large number
// of changes are made simultaneously. If this proves to be an issue,
// notify the delegate that all section and object changes have been processed.
// by uncommenting the method below in place of the implementation above.
//
//- ( void ) controllerDidChangeContent: ( NSFetchedResultsController * ) controller
//{
//    // In the simplest, most efficient, case, reload the table view.
//    //
//    [ self.tableView reloadData ];
//}

@end
