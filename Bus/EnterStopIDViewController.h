//
//  EnterStopIDViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 29/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AddStopAbstractViewController.h"

@interface EnterStopIDViewController : AddStopAbstractViewController <UITextFieldDelegate>

@property ( weak,   nonatomic ) IBOutlet UITextField * numberField;
@property ( weak,   nonatomic ) IBOutlet UITextField * descriptionField;

@property ( retain, nonatomic )          UIToolbar   * numberToolbar;
@property ( retain, nonatomic )          UIToolbar   * descriptionToolbar;

@end
