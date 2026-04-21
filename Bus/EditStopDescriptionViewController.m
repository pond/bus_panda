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
                                andPreferredFlag: nil
                               includingCloudKit: YES ];

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

    self.descriptionField.text = [ self.sourceObject valueForKey: @"stopDescription" ];

    // On iOS 13, despite the label colour being set up in the storyboard, this
    // one view has invisible text in dark mode no matter what I try. In the end
    // I've given up and just hard-set the colour here.
    //
    if (@available(iOS 13, *))
    {
        self.descriptionField.textColor = [UIColor labelColor];
    }

    self.cancelButton = [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemClose
                                                       target: self
                                                       action: @selector( dismissEditorView: )
    ];

    self.saveChangesButton = [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemSave
                                                       target: self
                                                       action: @selector( commitEdit: )
    ];

    self.navigationItem.leftBarButtonItem  = self.cancelButton;
    self.navigationItem.rightBarButtonItem = self.saveChangesButton;

}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.descriptionField becomeFirstResponder ];
}

@end
