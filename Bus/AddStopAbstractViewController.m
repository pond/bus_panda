//
//  AddStopAbstractViewController.m
//  Bus Panda
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

#import "DataManager.h"

@implementation AddStopAbstractViewController

// Subclasses should call here to add a new stop. Proxies to a presenting MVC
// via view controller hierarchy introspection.
//
- ( void ) addFavourite: ( NSString * _Nonnull ) stopID
        withDescription: ( NSString * _Nonnull ) stopDescription;
{
    [ DataManager.dataManager addOrEditFavourite: stopID
                              settingDescription: stopDescription
                                andPreferredFlag: nil
                               includingCloudKit: YES ];
}

// Subclasses should call this method when they want to be closed. It ensures
// consistent dismissal behaviour across addition views.
//
- ( void ) dismissAdditionView
{
    [ self dismissViewControllerAnimated: YES completion: nil ];
}

// See header for details.
//
- ( UIBarButtonItem * _Nonnull ) installCancelAction: ( SEL _Nonnull ) cancelAction
                                       andDoneAction: ( SEL _Nonnull ) doneAction
{
    UIBarButtonItem * cancel =
    [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel
                                                       target: self
                                                       action: cancelAction
    ];

    UIBarButtonItem * done =
    [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                       target: self
                                                       action: doneAction
    ];

    if (@available(iOS 26, *))
    {
        done.style = UIBarButtonItemStyleProminent;
    }

    self.navigationItem.leftBarButtonItem  = cancel;
    self.navigationItem.rightBarButtonItem = done;

    return done;
}

@end
