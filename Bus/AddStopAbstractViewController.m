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
// The toolbar isn't in a window yet, so it can't work out its own height
// from traits (e.g. shorter on iPhone in landscape, taller Liquid Glass
// metrics on iOS 26+). On iOS 17+, give it this view controller's traits
// and let it size itself; earlier, use the classic fixed bar heights.
//
- ( UIToolbar * _Nonnull ) keyboardToolbarWithItems: ( NSArray < UIBarButtonItem * > * _Nonnull ) items
{
    UITraitCollection * traits  = self.traitCollection;
    UIToolbar         * toolbar = [ [ UIToolbar alloc ] initWithFrame: CGRectMake( 0, 0, self.view.bounds.size.width, 44 ) ];

    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    toolbar.items            = items;
    toolbar.tintColor        = [ UIColor colorNamed: @"busLivery" ];

    if (@available(iOS 17, *))
    {
        toolbar.traitOverrides.verticalSizeClass   = traits.verticalSizeClass;
        toolbar.traitOverrides.horizontalSizeClass = traits.horizontalSizeClass;
        toolbar.traitOverrides.userInterfaceIdiom  = traits.userInterfaceIdiom;

        [ toolbar updateTraitsIfNeeded ];
        [ toolbar sizeToFit ];
    }
    else
    {
        CGRect frame = toolbar.frame;

        frame.size.height =
        (
            traits.userInterfaceIdiom == UIUserInterfaceIdiomPhone &&
            traits.verticalSizeClass  == UIUserInterfaceSizeClassCompact
        ) ? 32 : 44;

        toolbar.frame = frame;
    }

    return toolbar;
}

@end
