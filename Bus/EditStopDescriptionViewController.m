//
//  EditStopDescriptionViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 2/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

#import "EditStopDescriptionViewController.h"

#import "DataManager.h"

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

    [ DataManager.dataManager addOrEditFavourite: [ self.sourceObject valueForKey: @"stopID" ]
                              settingDescription: self.descriptionField.text
                                andPreferredFlag: nil ];

    [ self dismissEditorView: nil ];
}

- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    [ self commitEdit: nil ];
    return YES;
}

// Define or redefine the keyboard toolbars using frame metrics appropriate
// for the current device interface idiom and device rotation.
//
- ( void ) redefineKeyboardToolbars
{
    CGFloat                height      = 44;
    UIInterfaceOrientation orientation = [ [ UIApplication sharedApplication ] statusBarOrientation ];

    if (
           UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
           UIInterfaceOrientationIsLandscape( orientation )
       )
       height = 32;

    CGRect frame = CGRectIntegral
    (
        CGRectMake
        (
            0,
            self.view.bounds.size.height - height,
            self.view.bounds.size.width,
            height
        )
    );

    self.descriptionToolbar          = [ [UIToolbar alloc ] initWithFrame: frame ];
    self.descriptionToolbar.barStyle = UIBarStyleDefault;

    self.descriptionToolbar.items    =
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
}

// See EnterStopIDViewController for details.
//
- ( void ) viewWillTransitionToSize: ( CGSize ) size
          withTransitionCoordinator: ( id <UIViewControllerTransitionCoordinator> ) coordinator
{
    [ super viewWillTransitionToSize: size withTransitionCoordinator: coordinator ];

    if (
           UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
           [ self.descriptionField isFirstResponder ]
       )
    {
        [ self.descriptionField resignFirstResponder ];

        [
            coordinator animateAlongsideTransition: nil
                                        completion: ^ ( id <UIViewControllerTransitionCoordinatorContext> context )
            {
                [ self redefineKeyboardToolbars ];
                self.descriptionField.inputAccessoryView = self.descriptionToolbar;
                [ self.descriptionField becomeFirstResponder ];
            }
        ];
    }
}

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];
    [ self redefineKeyboardToolbars ];

    self.descriptionField.inputAccessoryView = self.descriptionToolbar;
    self.descriptionField.text               = [ self.sourceObject valueForKey: @"stopDescription" ];
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.descriptionField becomeFirstResponder ];
}

@end
