//
//  AddStopAbstractViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//
//  Subclassed by controllers which want to add a stop, one way
//  or another. When those controllers are ready, they call
//  -addStop:withDescription and this base class does the rest.
//
//  Not intended to be instantiated directly; only subclassed.
//

#import "AddStopAbstractViewController.h"

@interface AddStopAbstractViewController ()
@property ( weak, nonatomic ) MasterViewController * presentingMVC;
@end

@implementation AddStopAbstractViewController

// Remember the presenting MVC, for -addFavourite:withDescription. When an
// MVC shows one of the subclasses of this class, it must call this method
// to let the instance know from whence it came.
//
- ( void ) rememberPresentingMVC: ( MasterViewController * ) mvc
{
    self.presentingMVC = mvc;
}

// Subclasses should call here to add a new stop. Proxies to a presenting MVC
// via -rememberPresentingMVC:.
//
- ( void ) addFavourite: ( NSString * ) stopID
        withDescription: ( NSString * ) stopDescription;
{
    [ self.presentingMVC addFavourite: stopID
                      withDescription: stopDescription ];
}

// Subclasses should call this method when they want to be closed. It ensures
// consistent dismissal behaviour across addition views.
//
- ( void ) dismissAdditionView
{
    [ self dismissViewControllerAnimated: YES completion: nil ];
}

@end
