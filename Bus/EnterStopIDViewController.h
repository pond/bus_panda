//
//  EnterStopIDViewController.h
//  Bus
//
//  Created by Andrew Hodgkinson on 29/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AddStopAbstractViewController.h"

@interface EnterStopIDViewController : AddStopAbstractViewController

@property ( weak, nonatomic ) IBOutlet UITextField * numberField;
@property ( weak, nonatomic ) IBOutlet UITextField * descriptionField;

@end
