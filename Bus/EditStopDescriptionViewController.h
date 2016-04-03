//
//  EditStopDescriptionViewController.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 2/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AddStopAbstractViewController.h"

@interface EditStopDescriptionViewController : AddStopAbstractViewController <UITextFieldDelegate>

@property ( weak, nonatomic ) IBOutlet UITextField     * descriptionField;
@property ( weak, nonatomic )          NSManagedObject * sourceObject;

@end
