//
//  DetailViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property ( strong, nonatomic ) id                     detailItem;
@property ( weak,   nonatomic ) IBOutlet UITableView * tableView;

// Return a view for the message shown when there are no favourite stops at
// all, here and in the list of favourites. While favourites might still be
// arriving from iCloud (see DataManager's "checkingICloud"), it says so.
//
+ ( UIView * ) noFavouritesView;

// YES if there is a stop to show. NO if there is no detail item, or if it is
// a favourite stop that has since been deleted (reading a deleted Core Data
// object's values raises an exception, so callers must check this first).
//
- ( BOOL ) hasStop;

// With no stop to show, show a message instead of a schedule: either that
// there are no favourites, or that one should be chosen. Call again if the
// number of favourites changes, to update the message.
//
- ( void ) showPlaceholder;

// Return a view showing a standard "empty state" - an SF Symbol, a prominent
// title and a quieter hint - suitable for a table view's background view.
//
+ ( UIView * ) emptyStateViewWithSymbol: ( NSString * ) symbolName
                                  title: ( NSString * ) title
                                   hint: ( NSString * ) hint;

@end

