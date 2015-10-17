//
//  ServiceDescriptionCell.h
//  Bus
//
//  Created by Andrew Hodgkinson on 29/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ServiceDescriptionCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *number;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *when;

@end
