//
//  FavouritesCell.h
//  Bus
//
//  Created by Andrew Hodgkinson on 1/04/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FavouritesCell : UITableViewCell

@property ( weak, nonatomic ) IBOutlet UILabel * stopID;
@property ( weak, nonatomic ) IBOutlet UILabel * stopDescription;

@end
