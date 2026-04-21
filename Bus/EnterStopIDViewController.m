//
//  EnterStopIDViewController.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 29/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "EnterStopIDViewController.h"
#import "MasterViewController.h"

@implementation EnterStopIDViewController

// Dismiss the 'add stop' view without adding anything.
//
// "sender" is ignored.
//
- ( IBAction ) dismissAdditionView: ( id ) sender
{
    ( void ) sender;

    [ self.numberField setText: @"" ];
    [ self.numberField resignFirstResponder ];

    [ self.descriptionField setText: @"" ];
    [ self.descriptionField resignFirstResponder ];

    [ self dismissAdditionView ];
}

// Add a stop (provided the stop ID has 4 digits in it, else just ignore the
// stop information) and dismiss the view.
//
// "sender" is ignored.
//
- ( IBAction ) addStop: ( id ) sender
{
    ( void ) sender;

    NSString * stopID          = self.numberField.text;
    NSString * stopDescription = self.descriptionField.text;

    if ( stopID.length == 4 ) [ self addFavourite: stopID
                                  withDescription: stopDescription ];

    [ self dismissAdditionView: nil ];
}

- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    if ( textField == self.descriptionField )
    {
        [ self addStop: nil ];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void) inputFieldsChanged
{
    NSString * number      = self.numberField.text      ?: @"";
    NSString * description = self.descriptionField.text ?: @"";

    self.addStopButton.enabled = (number.length == 4 && description.length > 0);
}

// From the UITextFieldDelegate protocol and called because the numerical
// entry field has been given the Enter Stop ID object as its delegate in the
// storyboard. The description field has no delegate at the time of writing.
// but just in case it does end up wired to here one day, the method makes
// sure it is dealing with the right field.
//
// The sole aim is to limit the numeric stop ID entry to 4 digits. Via:
//
//   http://stackoverflow.com/questions/433337/set-the-maximum-character-length-of-a-uitextfield
//
- ( BOOL ) textField: ( UITextField * ) textField shouldChangeCharactersInRange: ( NSRange    ) range
                                                              replacementString: ( NSString * ) string
{
    if ( textField == self.descriptionField ) return YES;

    // Prevent crashing undo bug (see StackOverflow link above).
    //
    if ( range.length + range.location > textField.text.length )
    {
        return NO;
    }

    NSUInteger newLength = [ textField.text length ] + [ string length ] - range.length;
    return newLength <= 4 ? YES : NO;
}

- ( void ) viewDidLoad
{
    [ super viewDidLoad ];

    self.cancelButton = [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemClose
                                                       target: self
                                                       action: @selector( dismissAdditionView: )
    ];

    self.addStopButton = [
        [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd
                                                       target: self
                                                       action: @selector( addStop: )
    ];

    self.navigationItem.leftBarButtonItem  = self.cancelButton;
    self.navigationItem.rightBarButtonItem = self.addStopButton;


    [ self.numberField      addTarget: self
                               action: @selector( inputFieldsChanged )
                     forControlEvents: UIControlEventEditingChanged ];

    [ self.descriptionField addTarget: self
                               action: @selector( inputFieldsChanged )
                     forControlEvents: UIControlEventEditingChanged ];

    [ self inputFieldsChanged ];
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.numberField becomeFirstResponder ];
}

@end
