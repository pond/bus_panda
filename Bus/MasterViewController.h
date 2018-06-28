//
//  MasterViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>
#import <CoreData/CoreData.h>

@class DetailViewController;

#define STOP_IS_NOT_PREFERRED_VALUE @0
#define STOP_IS_PREFERRED_VALUE     @1

@interface MasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property ( strong, nonatomic ) DetailViewController       * detailViewController;

@property ( strong, nonatomic ) NSFetchedResultsController * fetchedResultsController;
@property ( strong, nonatomic ) NSManagedObjectContext     * managedObjectContext;

- ( void ) addOrEditFavourite: ( NSString * ) stopID
           settingDescription: ( NSString * ) stopDescription
             andPreferredFlag: ( NSNumber * ) preferred;

- ( void ) updateWatch: ( NSNotification * ) ignoredNotification;

@end
