//
//  EditStopDescriptionViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 2/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

#import "EditStopDescriptionViewController.h"
#import "MasterViewController.h"

@implementation EditStopDescriptionViewController

// Dismiss the 'edit description' view without adding anything.
//
// "sender" is ignored.
//
- ( IBAction ) dismissEditorView: ( id ) sender
{
    ( void ) sender;

    [ self.descriptionField setText: @"" ];
    [ self.descriptionField resignFirstResponder ];

    [ self dismissAdditionView ];
}

// Edit the description and dismiss the view.
//
// "sender" is ignored.
//
- ( IBAction ) commitEdit: ( id ) sender
{
    ( void ) sender;

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

    [ masterController editFavourite: self.sourceObject
                  settingDescription: self.descriptionField.text ];

    [ self dismissEditorView: nil ];
}

- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    [ self commitEdit: nil ];
    return YES;
}

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    UIToolbar * descriptionToolbar = [ [ UIToolbar alloc ] initWithFrame: CGRectMake( 0, 0, 320, 50 ) ];

    descriptionToolbar.barStyle = UIBarStyleDefault;
    descriptionToolbar.items    =
    [
        NSArray arrayWithObjects:

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Cancel"
                                            style: UIBarButtonItemStylePlain
                                           target: self
                                           action: @selector( dismissEditorView: ) ],

        [ [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace
                                                         target: nil
                                                         action: nil ],

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Save Changes"
                                            style: UIBarButtonItemStyleDone
                                           target: self
                                           action: @selector( commitEdit: ) ],
        nil
    ];

    [ descriptionToolbar sizeToFit ];

    self.descriptionField.inputAccessoryView = descriptionToolbar;
    self.descriptionField.text               = [ self.sourceObject valueForKey: @"stopDescription" ];
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.descriptionField becomeFirstResponder ];
}

@end
