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
@property ( weak,   nonatomic ) IBOutlet UILabel     * detailDescriptionLabel;

@end

