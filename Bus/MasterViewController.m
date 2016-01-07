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
#import "StopMapViewController.h"
#import "FavouritesCell.h"

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

    // Force an initial fetch of the results (initialising the fetched results
    // controller and populating it); add a notification handler to refresh the
    // data whenever it changes in iCloud.
    //
    [ self reloadFetchedResults: nil ];
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( reloadFetchedResults: )
                                                    name: DATA_CHANGED_NOTIFICATION_NAME // AppDelegate.h
                                                  object: [ [ UIApplication sharedApplication ] delegate ] ];
}

- ( void ) viewDidUnload
{
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self ];
}

// http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];
    [ self.tableView deselectRowAtIndexPath: [ self.tableView indexPathForSelectedRow ]
                                   animated: animated ];
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
        UIAlertAction actionWithTitle: @"Add Using Map of Stops"
                                style: UIAlertActionStyleDefault
                              handler: ^ ( UIAlertAction * action )
        {
            StopMapViewController * stopMapController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"StopMap"
            ];

            [ self openSpecificModal: stopMapController ];
        }
    ];

    UIAlertAction * enterStopIDAction =
    [
        UIAlertAction actionWithTitle: @"Add by Stop ID"
                                style: UIAlertActionStyleDefault
                              handler: ^ ( UIAlertAction * action )
        {
            EnterStopIDViewController * enterStopIDController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"EnterStopID"
            ];

            [ self openSpecificModal: enterStopIDController ];
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

    [ actions addAction: stopMapAction     ];
    [ actions addAction: enterStopIDAction ];
    [ actions addAction: cancel            ];

    // On the iPhone (at the time of writing) modal action sheets implicitly
    // always pop up over the whole screen. On an iPad, you need to tell the
    // system where to ground the popover - in this case the "+" button that
    // caused the action method here to be run in the first place.
    //
    actions.popoverPresentationController.barButtonItem = sender;

    [ self presentViewController: actions animated: YES completion: nil ];
}

#pragma mark - Adding favourites

- ( void ) addFavourite: ( NSString * ) stopID
        withDescription: ( NSString * ) stopDescription
{
    NSManagedObjectContext * context          = self.fetchedResultsController.managedObjectContext;
    NSEntityDescription    * entity           = self.fetchedResultsController.fetchRequest.entity;
    NSManagedObject        * newManagedObject =
    [
        NSEntityDescription insertNewObjectForEntityForName: entity.name
                                     inManagedObjectContext: context
    ];

    // If appropriate, configure the new managed object.
    //
    // Normally you should use accessor methods, but using KVC here avoids
    // the need to add a custom class to the template.

    [ newManagedObject setValue: stopID          forKey: @"stopID"          ];
    [ newManagedObject setValue: stopDescription forKey: @"stopDescription" ];

    // Save the context.

    NSError * error = nil;

    if ( ! [ context save: &error ] )
    {
        [
            ErrorPresenter showModalAlertFor: self
                                   withError: error
                                       title: @"Could not save favourites"
                                  andHandler: ^( UIAlertAction *action ) {}
        ];
    }
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

- ( NSInteger ) numberOfSectionsInTableView: ( UITableView * ) tableView
{
    return [ [ self.fetchedResultsController sections ] count ];
}

- ( NSInteger ) tableView: ( UITableView * ) tableView
    numberOfRowsInSection: ( NSInteger ) section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [ self.fetchedResultsController sections ][ section ];
    return [ sectionInfo numberOfObjects ];
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
        NSManagedObjectContext * context = [ self.fetchedResultsController managedObjectContext ];
        [ context deleteObject: [ self.fetchedResultsController objectAtIndexPath: indexPath ] ];

        NSError * error = nil;

        if ( ! [ context save: &error ] )
        {
            [
                ErrorPresenter showModalAlertFor: self
                                       withError: error
                                           title: @"Could not delete favourite"
                                      andHandler: ^( UIAlertAction *action ) {}
            ];
        }
    }
}

- ( void ) configureCell: ( FavouritesCell * ) cell atIndexPath: ( NSIndexPath * ) indexPath
{
    NSManagedObject *object = [ self.fetchedResultsController objectAtIndexPath: indexPath ];

    cell.stopID.text          = [ [ object valueForKey: @"stopID"          ] description ];
    cell.stopDescription.text = [ [ object valueForKey: @"stopDescription" ] description ];
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

    NSFetchRequest      * fetchRequest = [ [ NSFetchRequest alloc] init];
    NSEntityDescription * entity       = [ NSEntityDescription entityForName: @"BusStop"
                                                      inManagedObjectContext: self.managedObjectContext ];

    [ fetchRequest setEntity:         entity ];
    [ fetchRequest setFetchBatchSize: 50     ];

    NSSortDescriptor * sortDescriptor  = [ [ NSSortDescriptor alloc] initWithKey: @"stopDescription"
                                                                       ascending: YES ];
    [ fetchRequest setSortDescriptors: @[ sortDescriptor ] ];

    // "nil" for section name key path means "no sections".
    //
    NSFetchedResultsController * frc = [ [ NSFetchedResultsController alloc ] initWithFetchRequest: fetchRequest
                                                                              managedObjectContext: self.managedObjectContext
                                                                                sectionNameKeyPath: nil
                                                                                         cacheName: @"BusStops" ];
    frc.delegate = self;
    self.fetchedResultsController = frc;

    return _fetchedResultsController;
}

// Reload results (i.e. favourites) from iCloud / local storage; "notification"
// parameter is ignored.
//
- ( void ) reloadFetchedResults: ( NSNotification * ) notification
{
    NSLog( @"Underlying data changed... Refreshing" );

    NSError *error = nil;

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

        default:
        {
            return;
        }
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
    }
}

- ( void ) controllerDidChangeContent: ( NSFetchedResultsController * ) controller
{
    [ self.tableView endUpdates ];
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
