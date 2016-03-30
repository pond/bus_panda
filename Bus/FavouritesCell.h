//
//  FavouritesCell.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 1/04/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MGSwipeTableCell.h"

// For MGSwipeTableCell, see:
//
// https://github.com/MortimerGoro/MGSwipeTableCell
//
@interface FavouritesCell : MGSwipeTableCell

@property ( weak, nonatomic ) IBOutlet UILabel * stopID;
@property ( weak, nonatomic ) IBOutlet UILabel * stopDescription;

@end
