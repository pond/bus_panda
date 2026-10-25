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

// Return YES if there is a Stop to show. Return NO if there is no item, or the
// item has since been deleted.
//
- ( BOOL ) hasStop;

// With no stop to show, show a message - that either there are no favourites,
// or that one should be chosen. If the number of favourites changes, call
// again to update the message.
//
- ( void ) showPlaceholder;

// Return a view showing a standard "empty state" - an SF Symbol, title text
// and a related hint - suitable for a table view's background view.
//
+ ( UIView * ) emptyStateViewWithSymbol: ( NSString * ) symbolName
                                  title: ( NSString * ) title
                                   hint: ( NSString * ) hint;

@end

