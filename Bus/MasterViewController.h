//
//  MasterViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class DetailViewController;

@interface MasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property ( strong, nonatomic ) DetailViewController       * detailViewController;

@property ( strong, nonatomic ) NSFetchedResultsController * fetchedResultsController;
@property ( strong, nonatomic ) NSManagedObjectContext     * managedObjectContext;

- ( void )  addFavourite: ( NSString        * ) stopID
         withDescription: ( NSString        * ) stopDescription;

- ( void ) editFavourite: ( NSManagedObject * ) object
      settingDescription: ( NSString        * ) stopDescription;

- ( void )   updateWatch: ( NSNotification  * ) ignoredNotification;

@end
