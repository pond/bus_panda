//
//  MasterViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"
#import "DataManager.h"
#import "ErrorPresenter.h"

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "EnterStopIDViewController.h"
#import "EditStopDescriptionViewController.h"
#import "StopMapViewController.h"
#import "FavouritesCell.h"

// Titles and symbols for the per-stop actions, shared by the swipe actions
// and the context menu so they stay consistent.
//
#define DELETE_TITLE  NSLocalizedString( @"Delete",           "Title of action for a bus stop, which deletes that stop" )
#define PREFER_TITLE  NSLocalizedString( @"Pin",              "Title of action for a bus stop, which pins it (flags it as 'preferred')" )
#define DEMOTE_TITLE  NSLocalizedString( @"Unpin",            "Title of action for a bus stop, which unpins it (flags it as normal / not 'preferred')" )
#define EDIT_TITLE    NSLocalizedString( @"Edit Description", "Title of action for a bus stop, which edits that stop's description" )

#define DELETE_SYMBOL @"trash.fill"
#define PREFER_SYMBOL @"pin.fill"
#define DEMOTE_SYMBOL @"pin.slash.fill"
#define EDIT_SYMBOL   @"pencil"

@interface MasterViewController ()

    // Pull-to-refresh to force full CloudKit resync.
    //
    @property ( strong, nonatomic ) UIRefreshControl * refreshControl;

@end

@implementation MasterViewController

    @synthesize refreshControl = _refreshControl;

#pragma mark - View lifecycle

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    //
    self.clearsSelectionOnViewWillAppear = NO;

    // The "+" button shows a menu of ways to add a stop as soon as it's
    // tapped (it has a menu but no action of its own).
    //
    UIBarButtonItem * addButton =
    [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd
                                                       target: nil
                                                       action: nil
    ];

    addButton.menu = [ self addStopMenu ];

    self.navigationItem.leftBarButtonItem  = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = addButton;

    // Add a custom notification handler to refresh data. This is triggered
    // when, for example, data changes in iCloud.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( reloadFetchedResults: )
                                                    name: DATA_CHANGED_NOTIFICATION_NAME
                                                  object: nil ];

    // Update "no favourites" messages when checking iCloud starts or stops.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( iCloudCheckDidChange: )
                                                    name: ICLOUD_CHECK_CHANGED_NOTIFICATION_NAME
                                                  object: nil ];

    // Add an observer triggered whenever the Core Data list of favourite
    // stops changes; this is used to update the Watch.
    //
    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( updateWatch: )
                                                    name: NSManagedObjectContextObjectsDidChangeNotification
                                                  object: nil ];

    // Watch for user defaults changes as we'll need to reload the table data
    // to reflect a 'shorten names to fit' settings change.
    //
    NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;

    [ defaults addObserver: self
                forKeyPath: SHORTEN_DISPLAYED_NAMES
                   options: NSKeyValueObservingOptionNew
                   context: nil ];

    // Pull-to-refresh for CloudKit resync.
    //
    self.refreshControl = [ [ UIRefreshControl alloc ] init ];

    [ self.refreshControl addTarget: self
                             action: @selector( resyncFromCloudKit )
                   forControlEvents: UIControlEventValueChanged ];

    [ self.tableView addSubview: self.refreshControl ];

    // We don't try an update the Apple Watch app here because we don't
    // necessarily have full access to Core Data yet. Instead, let the App
    // Delegate deal with at-wakeup updates by calling through to our
    // "-updateWatch:" method once it's set the 'managedObjectContext'
    // property in this instance.
}

// When collapsed (iPhone), clear the selection on return from a stop's
// schedule - see:
//
//   http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
//
// When expanded (iPad), keep it. The selected row shows which stop's
// schedule is on screen alongside the list.
//
- ( void ) viewWillAppear: ( BOOL ) animated
{
    [ super viewWillAppear: animated ];

    if ( self.splitViewController.isCollapsed )
    {
        [ self.tableView deselectRowAtIndexPath: [ self.tableView indexPathForSelectedRow ]
                                       animated: animated ];
    }
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self updateForCurrentFavourites ];
}

// The split view may collapse or expand (rotation, window resizing, an
// iPhone Duo folding), which changes what should be shown where.
//
- ( void ) viewWillTransitionToSize: ( CGSize ) size
          withTransitionCoordinator: ( id <UIViewControllerTransitionCoordinator> ) coordinator
{
    [ super viewWillTransitionToSize: size withTransitionCoordinator: coordinator ];

    [
        coordinator animateAlongsideTransition: nil
                                    completion: ^ ( id <UIViewControllerTransitionCoordinatorContext> context )
        {
            [ self updateForCurrentFavourites ];
        }
    ];
}

// Keep what's on screen consistent with the current favourites. Called when
// the view appears, whenever the list's data changes (including deletions,
// local or via iCloud) and after size changes.
//
// When the split view is expanded (e.g. iPad or unfolded iPhone Duo), there
// is always something sensible in the detail column:
//
// * If it is showing a stop that still exists, leave it alone - that's the
//   user's choice.
//
// * Otherwise, if there are any favourites, show the first. The list puts
//   preferred stops first, so that's the first pinned stop if there are any,
//   else the first other stop. This covers launch, and deletion of the stop
//   being shown.
//
// * Otherwise show a "no favourites yet" message there.
//
// When collapsed (iPhone), if a stop that has been deleted is showing, go
// back to the list; the list itself shows "no favourites yet" when empty.
//
// Notification handler; see -viewDidLoad.
//
- ( void ) iCloudCheckDidChange: ( NSNotification * ) notification
{
    [ self updateForCurrentFavourites ];
}

- ( void ) updateForCurrentFavourites
{
    UISplitViewController * split = self.splitViewController;

    if ( split == nil || self.view.window == nil ) return; // Not ready yet

    NSUInteger favouriteCount = DataManager.dataManager.fetchedResultsControllerLocal.fetchedObjects.count;

    // Empty-list message, only when collapsed; when expanded, the detail
    // column shows it instead.

    if ( favouriteCount == 0 && split.isCollapsed )
    {
        self.tableView.backgroundView = [ DetailViewController noFavouritesView ];
    }
    else
    {
        self.tableView.backgroundView = nil;
    }

    if ( split.isCollapsed )
    {
        for ( UIViewController * controller in self.navigationController.viewControllers )
        {
            if ( [ controller isKindOfClass: [ DetailViewController class ] ] &&
                 [ ( DetailViewController * ) controller hasStop ] == NO &&
                 [ ( DetailViewController * ) controller detailItem ] != nil )
            {
                [ self.navigationController popToRootViewControllerAnimated: YES ];
                break;
            }
        }

        return;
    }

    UIViewController * secondary = [ split viewControllerForColumn: UISplitViewControllerColumnSecondary ];

    if ( [ secondary isKindOfClass: [ UINavigationController class ] ] )
    {
        secondary = ( ( UINavigationController * ) secondary ).viewControllers.firstObject;
    }

    DetailViewController * detail = [ secondary isKindOfClass: [ DetailViewController class ] ]
                                  ? ( DetailViewController * ) secondary
                                  : nil;

    if ( [ detail hasStop ] ) return;

    if ( favouriteCount > 0 )
    {
        NSIndexPath * first = [ NSIndexPath indexPathForRow: 0 inSection: 0 ];

        [ self.tableView selectRowAtIndexPath: first
                                     animated: NO
                               scrollPosition: UITableViewScrollPositionNone ];

        [ self tableView: self.tableView didSelectRowAtIndexPath: first ];
    }
    else if ( detail != nil && detail.detailItem == nil )
    {
        [ detail showPlaceholder ]; // Already a placeholder; update its message
    }
    else
    {
        DetailViewController * placeholder = [ self.storyboard instantiateViewControllerWithIdentifier: @"ListOfServices" ];

        [ split setViewController: [ [ UINavigationController alloc ] initWithRootViewController: placeholder ]
                        forColumn: UISplitViewControllerColumnSecondary ];
    }
}

- ( void ) dealloc
{
    NSUserDefaults * defaults = NSUserDefaults.standardUserDefaults;
    [ defaults removeObserver: self forKeyPath: SHORTEN_DISPLAYED_NAMES ];

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

// Return the menu for the "+" button - the ways of adding a stop.
//
- ( UIMenu * ) addStopMenu
{
    UIAction * stopMapAction =
    [
        UIAction actionWithTitle: NSLocalizedString( @"Add Using Map", "Menu item for adding a bus stop by choosing it on a map" )
                           image: nil
                      identifier: nil
                         handler: ^ ( __kindof UIAction * action )
        {
            UINavigationController * stopMapNavigationController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"StopMap"
            ];

            // On iPad (regular width and height), the default sheet is far
            // too small for a map on a large screen, so use a form sheet sized
            // in proportion to the window instead. The map view keeps it in
            // proportion if the window changes size. Use the window's traits,
            // since this list is in a split view column with its own. Not done
            // on a Mac, where sheets are separate windows that macOS sizes.
            //
            UIWindow          * window = self.view.window;
            UITraitCollection * traits = window.traitCollection;

            if ( NSProcessInfo.processInfo.isMacCatalystApp == NO              &&
                 traits.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
                 traits.verticalSizeClass   == UIUserInterfaceSizeClassRegular )
            {
                stopMapNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                stopMapNavigationController.preferredContentSize   = [ StopMapViewController sheetSizeForWindowSize: window.bounds.size ];
            }

            [ self openSpecificModal: stopMapNavigationController ];
        }
    ];

    UIAction * enterStopIDAction =
    [
        UIAction actionWithTitle: NSLocalizedString( @"Add by Stop ID", "Menu item for adding a bus stop by typing in its ID" )
                           image: nil
                      identifier: nil
                         handler: ^ ( __kindof UIAction * action )
        {
            UINavigationController * enterStopIDNavigationController =
            [
                self.storyboard instantiateViewControllerWithIdentifier: @"EnterStopID"
            ];

            [ self openSpecificModal: enterStopIDNavigationController ];
        }
    ];

    return [ UIMenu menuWithTitle: @"" children: @[ stopMapAction, enterStopIDAction ] ];
}

// Open the modal editor for the given favourite stop's description.
//
- ( void ) openDescriptionEditorForObject: ( NSManagedObject * ) object
{
    UINavigationController * editStopDescriptionNavigationController =
    [
        self.storyboard instantiateViewControllerWithIdentifier: @"EditStopDescription"
    ];

    EditStopDescriptionViewController * editStopDescriptionController = editStopDescriptionNavigationController.childViewControllers.firstObject;
    editStopDescriptionController.sourceObject = object;

    [ self openSpecificModal: editStopDescriptionNavigationController ];
}

#pragma mark - Selection

// Show the chosen stop in the split view's secondary column. When collapsed,
// -showColumn: pushes it onto the single navigation stack. When expanded, it
// replaces whatever was shown before.
//
// The detail view is given its own new navigation controller. Passing a bare
// view controller instead works on iOS 26+, but on earlier versions (at least
// iOS 18) UIKit pushes it onto the column's *existing* navigation controller
// - the storyboard's placeholder "Services" view, then every previously
// chosen stop - corrupting the collapsed navigation stack on iPhone. A new
// navigation controller replaces the column's contents outright everywhere.
//
- ( void )      tableView: ( UITableView * ) tableView
  didSelectRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    NSManagedObject        * object     = [ DataManager.dataManager.fetchedResultsControllerLocal objectAtIndexPath: indexPath ];
    DetailViewController   * controller = [ self.storyboard instantiateViewControllerWithIdentifier: @"ListOfServices" ];
    UINavigationController * navigation = [ [ UINavigationController alloc ] initWithRootViewController: controller ];
    UISplitViewController  * split      = self.splitViewController;

    [ controller setDetailItem: object ];

    [ split setViewController: navigation forColumn: UISplitViewControllerColumnSecondary ];
    [ split showColumn: UISplitViewControllerColumnSecondary ];
}

#pragma mark - Table View

- ( NSInteger ) numberOfSectionsInTableView: ( UITableView * ) tableView
{
    ( void ) tableView;
    return DataManager.dataManager.numberOfSections;
}

- ( NSInteger ) tableView: ( UITableView * ) tableView
    numberOfRowsInSection: ( NSInteger     ) section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = DataManager.dataManager.fetchedResultsControllerLocal.sections[ section ];
    return [ sectionInfo numberOfObjects ];
}

- ( NSString * ) tableView: ( UITableView * ) tableView
   titleForHeaderInSection: ( NSInteger     ) section
{
    if ( DataManager.dataManager.shouldShowSectionHeader == NO ) return @"";

    switch( section )
    {
        case 0:
            return NSLocalizedString( @"Pinned", @"Pinned (preferred) stops section title" );

        default:
            return NSLocalizedString( @"Others", @"Unpinned (non-preferred) stops section title" );
    }
}

- ( CGFloat )    tableView: ( UITableView * ) tableView
  heightForHeaderInSection: ( NSInteger     ) section
{
    // Show no section title unless there are at least two sections. On iOS
    // 26+, let the system size headers (including for Dynamic Type).

    if ( DataManager.dataManager.shouldShowSectionHeader == NO ) return 0;

    if (@available(iOS 26, *))
    {
        return UITableViewAutomaticDimension;
    }

    return 32;
}

- ( void )    tableView: ( UITableView * ) tableView
  willDisplayHeaderView: ( UIView      * ) view
             forSection: ( NSInteger     ) section
{
    // On iOS 26+, leave headers in the system style.
    //
    if (@available(iOS 26, *)) return;

    // Otherwise, increase contrast of the section header background colour.
    // The default is almost invisible.
    //
    UITableViewHeaderFooterView * hfView = ( UITableViewHeaderFooterView * ) view;
    hfView.backgroundView.backgroundColor = [ UIColor systemGray6Color ];
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
    DataManager * dataManager = DataManager.dataManager;

    if ( editingStyle == UITableViewCellEditingStyleDelete )
    {
        NSManagedObject * object = [ dataManager.fetchedResultsControllerLocal objectAtIndexPath: indexPath ];
        NSString        * stopID = [ object valueForKey: @"stopID" ];

        if ( stopID != nil )
        {
            [ dataManager deleteFavourite: stopID
                        includingCloudKit: YES ];
        }
    }
}

- ( void ) configureCell: ( FavouritesCell * ) cell atIndexPath: ( NSIndexPath * ) indexPath
{
    DataManager     * dataManager     = DataManager.dataManager;
    NSManagedObject * object          = [ dataManager.fetchedResultsControllerLocal objectAtIndexPath: indexPath ];
    NSString        * _Nonnull stopID          = [ object valueForKey: @"stopID"          ];
    NSString        * stopDescription = [ object valueForKey: @"stopDescription" ];
    
    cell.stopID.text          = stopID;
    cell.stopDescription.text = stopDescription;
}

// Return an SF Symbol image carrying an accessibility label, for icon-only
// swipe actions (which then still make sense to VoiceOver).
//
- ( UIImage * ) symbolNamed: ( NSString * ) name
         accessibilityLabel: ( NSString * ) label
{
    UIImage * image = [ UIImage systemImageNamed: name ];
    image.accessibilityLabel = label;
    return image;
}

// Ask the user to confirm deletion of the given favourite stop. If they
// confirm, delete it (locally and from iCloud). The optional completion
// block is called with YES if the stop was deleted, NO if it was kept.
//
- ( void ) confirmDeletionOfStop: ( NSString * ) stopID
                 withDescription: ( NSString * ) stopDescription
                      completion: ( void ( ^ )( BOOL deleted ) ) completion
{
    NSString * name  = stopDescription.length > 0 ? stopDescription : stopID;
    NSString * title =
    [
        NSString stringWithFormat: NSLocalizedString( @"Delete “%@”?", "Title of confirmation alert for deleting a favourite bus stop; parameter is the stop's description" ),
                                   name
    ];

    UIAlertController * alert =
    [
        UIAlertController alertControllerWithTitle: title
                                           message: NSLocalizedString( @"This stop will be removed from your favourites on all of your devices.", "Message in confirmation alert for deleting a favourite bus stop" )
                                    preferredStyle: UIAlertControllerStyleAlert
    ];

    [
        alert addAction:
        [
            UIAlertAction actionWithTitle: NSLocalizedString( @"Delete", "Button in confirmation alert which deletes a favourite bus stop" )
                                    style: UIAlertActionStyleDestructive
                                  handler: ^ ( UIAlertAction * action )
            {
                [ DataManager.dataManager deleteFavourite: stopID
                                        includingCloudKit: YES ];

                if ( completion ) completion( YES );
            }
        ]
    ];

    [
        alert addAction:
        [
            UIAlertAction actionWithTitle: NSLocalizedString( @"Keep", "Button in confirmation alert which cancels deletion of a favourite bus stop" )
                                    style: UIAlertActionStyleCancel
                                  handler: ^ ( UIAlertAction * action )
            {
                if ( completion ) completion( NO );
            }
        ]
    ];

    [ self presentViewController: alert animated: YES completion: nil ];
}

// Swipe-left actions for a stop, icon only: Delete (red), Prefer/Demote AKA
// Pin/Unpin (green) and Edit (blue). Delete is nearest the trailing edge. Full
// swipe does nothing so a long swipe can't delete a stop by accident!
//
// Less common actions, now and in future, belong in the context menu (see
// -tableView:contextMenuConfigurationForRowAtIndexPath:point:) rather than
// in more swipe buttons.
//
- ( UISwipeActionsConfiguration * )            tableView: ( UITableView * ) tableView
  trailingSwipeActionsConfigurationForRowAtIndexPath: ( NSIndexPath * ) indexPath
{
    DataManager     * dataManager = DataManager.dataManager;
    NSManagedObject * object      = [ dataManager.fetchedResultsControllerLocal objectAtIndexPath: indexPath ];
    NSString        * stopID      = [ object valueForKey: @"stopID" ];
    BOOL              isPreferred = [ [ object valueForKey: @"preferred" ] isEqual: STOP_IS_PREFERRED_VALUE ];

    if ( stopID == nil ) return nil;

    UIContextualAction * delete =
    [
        UIContextualAction contextualActionWithStyle: UIContextualActionStyleDestructive
                                               title: nil
                                             handler: ^ ( UIContextualAction * action, UIView * sourceView, void ( ^ completionHandler )( BOOL ) )
        {
            // The swipe stays open while the alert is shown; telling UIKit
            // the outcome afterwards either removes the row or slides it back.
            //
            [ self confirmDeletionOfStop: stopID
                         withDescription: [ object valueForKey: @"stopDescription" ]
                              completion: completionHandler ];
        }
    ];

    delete.image           = [ self symbolNamed: DELETE_SYMBOL accessibilityLabel: DELETE_TITLE ];
    delete.backgroundColor = UIColor.systemRedColor;

    UIContextualAction * preference =
    [
        UIContextualAction contextualActionWithStyle: UIContextualActionStyleNormal
                                               title: nil
                                             handler: ^ ( UIContextualAction * action, UIView * sourceView, void ( ^ completionHandler )( BOOL ) )
        {
            [ dataManager addOrEditFavourite: stopID
                          settingDescription: nil
                            andPreferredFlag: isPreferred ? STOP_IS_NOT_PREFERRED_VALUE : STOP_IS_PREFERRED_VALUE
                           includingCloudKit: YES ];

            completionHandler( YES );
        }
    ];

    preference.image           = isPreferred
                               ? [ self symbolNamed: DEMOTE_SYMBOL accessibilityLabel: DEMOTE_TITLE ]
                               : [ self symbolNamed: PREFER_SYMBOL accessibilityLabel: PREFER_TITLE ];
    preference.backgroundColor = UIColor.systemGreenColor;

    UIContextualAction * edit =
    [
        UIContextualAction contextualActionWithStyle: UIContextualActionStyleNormal
                                               title: nil
                                             handler: ^ ( UIContextualAction * action, UIView * sourceView, void ( ^ completionHandler )( BOOL ) )
        {
            completionHandler( YES );
            [ self openDescriptionEditorForObject: object ];
        }
    ];

    edit.image           = [ self symbolNamed: EDIT_SYMBOL accessibilityLabel: EDIT_TITLE ];
    edit.backgroundColor = UIColor.systemBlueColor;

    UISwipeActionsConfiguration * configuration =
    [
        UISwipeActionsConfiguration configurationWithActions: @[ delete, preference, edit ]
    ];

    configuration.performsFirstActionWithFullSwipe = NO;

    return configuration;
}

// Long-press context menu for a stop. This is the place for every per-stop
// action, including any future ones that don't merit a swipe button. The
// destructive Delete is kept apart, at the end, as the HIG recommends.
//
- ( UIContextMenuConfiguration * ) tableView: ( UITableView * ) tableView
   contextMenuConfigurationForRowAtIndexPath: ( NSIndexPath * ) indexPath
                                       point: ( CGPoint       ) point
{
    DataManager     * dataManager = DataManager.dataManager;
    NSManagedObject * object      = [ dataManager.fetchedResultsControllerLocal objectAtIndexPath: indexPath ];
    NSString        * stopID      = [ object valueForKey: @"stopID" ];
    BOOL              isPreferred = [ [ object valueForKey: @"preferred" ] isEqual: STOP_IS_PREFERRED_VALUE ];

    if ( stopID == nil ) return nil;

    return
    [
        UIContextMenuConfiguration configurationWithIdentifier: nil
                                               previewProvider: nil
                                                actionProvider: ^ UIMenu * ( NSArray < UIMenuElement * > * suggestedActions )
        {
            UIAction * edit =
            [
                UIAction actionWithTitle: EDIT_TITLE
                                   image: [ UIImage systemImageNamed: EDIT_SYMBOL ]
                              identifier: nil
                                 handler: ^ ( __kindof UIAction * action )
                {
                    [ self openDescriptionEditorForObject: object ];
                }
            ];

            UIAction * preference =
            [
                UIAction actionWithTitle: isPreferred ? DEMOTE_TITLE : PREFER_TITLE
                                   image: [ UIImage systemImageNamed: isPreferred ? DEMOTE_SYMBOL : PREFER_SYMBOL ]
                              identifier: nil
                                 handler: ^ ( __kindof UIAction * action )
                {
                    [ dataManager addOrEditFavourite: stopID
                                  settingDescription: nil
                                    andPreferredFlag: isPreferred ? STOP_IS_NOT_PREFERRED_VALUE : STOP_IS_PREFERRED_VALUE
                                   includingCloudKit: YES ];
                }
            ];

            UIAction * delete =
            [
                UIAction actionWithTitle: DELETE_TITLE
                                   image: [ UIImage systemImageNamed: DELETE_SYMBOL ]
                              identifier: nil
                                 handler: ^ ( __kindof UIAction * action )
                {
                    [ self confirmDeletionOfStop: stopID
                                 withDescription: [ object valueForKey: @"stopDescription" ]
                                      completion: nil ];
                }
            ];

            delete.attributes = UIMenuElementAttributesDestructive;

            UIMenu * destructive =
            [
                UIMenu menuWithTitle: @""
                               image: nil
                          identifier: nil
                             options: UIMenuOptionsDisplayInline
                            children: @[ delete ]
            ];

            return [ UIMenu menuWithTitle: @"" children: @[ edit, preference, destructive ] ];
        }
    ];
}

#pragma mark - Observers (NSNotificationCentre and KVO)

// Reload results (i.e. favourites) from iCloud / local storage; "notification"
// parameter is ignored.
//
// If it is running, the WatchKit application is told about the new data too.
//
- ( void ) reloadFetchedResults: ( NSNotification * ) ignoredNotification
{
    ( void ) ignoredNotification;

    NSLog( @"MasterViewController: Reloading data due to notification" );

    // Deal with the local changes first

    NSError * error = nil;

    if ( ! [ DataManager.dataManager.fetchedResultsControllerLocal performFetch: &error ] )
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

    [ self performSelectorOnMainThread: @selector( updateForCurrentFavourites )
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
    ( void ) ignoredNotification;

    // Reads the main-queue Core Data context, so must run on the main thread;
    // but WatchConnectivity calls in here (via the App Delegate) on a
    // background queue, and the context-changed notification can arrive from
    // other contexts' threads.
    //
    if ( ! NSThread.isMainThread )
    {
        dispatch_async
        (
            dispatch_get_main_queue(),
            ^ ( void )
            {
                [ self updateWatch: nil ];
            }
        );

        return;
    }

    if ( ! WCSession.isSupported ) return;

    WCSession * session = [ WCSession defaultSession ];

    // The "application context" is delivered in the background, whenever the
    // watch next connects, so it only needs a paired watch with the app
    // installed - not one that's currently reachable.
    //
    if ( session.activationState   != WCSessionActivationStateActivated ||
         session.paired            == NO                                ||
         session.watchAppInstalled == NO )
    {
        return;
    }

    NSError * error = nil;

    [ session updateApplicationContext: [ DataManager.dataManager watchPayload ] error: &error ];

    if ( error != nil )
    {
        NSLog( @"Error updating watch: %@", error );
    }
}

// Called via KVO when the user defaults change.
//
- ( void ) observeValueForKeyPath: ( NSString     * ) keyPath
                         ofObject: ( id             ) object
                           change: ( NSDictionary * ) change
                          context: ( void         * ) context
{
    ( void ) object;
    ( void ) change;
    ( void ) context;

    if ( [ keyPath isEqualToString: SHORTEN_DISPLAYED_NAMES ] )
    {
        [ self performSelector: @selector( forceRedrawTable ) // (See below)
                    withObject: nil ];
    }
}

// From around iOS 11 and later, UITableView -reloadData seems to be optimised
// to not want to redraw things if the data hasn't changed. This means a change
// of the "shorten names" setting isn't always reflected at run time by just a
// simple reload. Instead, we need to take more drastic steps.
//
// MUST BE CALLED ON MAIN THREAD ONLY.
//
- ( void ) forceRedrawTable
{
    NSMutableArray * indexArray = [ NSMutableArray array ];
    NSInteger        sections   = [ self numberOfSectionsInTableView: self.tableView ];

    for ( NSInteger section = 0; section < sections; section ++ )
    {
        NSInteger rows = [ self tableView: self.tableView numberOfRowsInSection: section ];

        for ( NSInteger row = 0; row < rows; row ++ )
        {
            NSIndexPath * indexPath = [ NSIndexPath indexPathForRow: row inSection: section ];
            [ indexArray addObject: indexPath ];
        }
    }

    [ self.tableView beginUpdates ];

    [ self.tableView reloadRowsAtIndexPaths: indexArray
                           withRowAnimation: UITableViewRowAnimationNone ];

    [ self.tableView endUpdates ];
}

#pragma mark - Refresh control handling

- ( void ) resyncFromCloudKit
{
    id completionHandler = ^ ( NSError * _Nullable error )
    {
        [ self.refreshControl performSelectorOnMainThread: @selector( endRefreshing )
                                               withObject: nil
                                            waitUntilDone: NO ];
    };

    [ DataManager.dataManager fetchRecentChangesWithCompletionBlock: completionHandler
                                           ignoringPriorChangeToken: YES ];
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
    [ self updateForCurrentFavourites ];
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
