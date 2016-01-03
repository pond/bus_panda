//
//  AddStopAbstractViewController.h
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

#import <UIKit/UIKit.h>

#import "MasterViewController.h"

@interface AddStopAbstractViewController : UIViewController

// Subclasses should call here to add a new stop. Proxies to a presenting MVC
// via view controller hierarchy introspection.
//
- ( void ) addFavourite: ( NSString * ) stopID
        withDescription: ( NSString * ) stopDescription;

// Subclasses should call this method when they want to be closed. It ensures
// consistent dismissal behaviour across addition views.
//
- ( void ) dismissAdditionView;

@end
