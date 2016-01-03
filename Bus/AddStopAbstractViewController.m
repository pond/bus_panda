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

@implementation AddStopAbstractViewController

// Subclasses should call here to add a new stop. Proxies to a presenting MVC
// via view controller hierarchy introspection.
//
- ( void ) addFavourite: ( NSString * ) stopID
        withDescription: ( NSString * ) stopDescription;
{
    MasterViewController  * masterController;
    UISplitViewController * underlyingPresenter = ( UISplitViewController * ) self.presentingViewController;
    id                      splitViewFirst      = [ underlyingPresenter.viewControllers firstObject ];

    // Under the split view is either another navigation controller leading to
    // the master view, or the master view directly.

    if ( [ splitViewFirst isKindOfClass: [ MasterViewController class ] ] )
    {
        masterController = splitViewFirst;
    }
    else
    {
        masterController = [ [ splitViewFirst viewControllers ] firstObject ];
    }

    [ masterController addFavourite: stopID
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
