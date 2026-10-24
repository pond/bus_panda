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

// Return YES if the stop ID field contains a complete stop ID.
//
- ( BOOL ) hasCompleteStopID
{
    return self.numberField.text.length == 4 ? YES : NO;
}

// Called whenever the stop ID field's text changes. The 'Done' button is only
// enabled for a complete stop ID. Once one has been typed in, focus moves to
// the optional description (iOS's number pad has no "Next" or "Return" key).
//
- ( void ) numberFieldDidChange: ( UITextField * ) textField
{
    BOOL complete = [ self hasCompleteStopID ];

    self.navigationItem.rightBarButtonItem.enabled = complete;

    if ( complete ) [ self.descriptionField becomeFirstResponder ];
}

// The stop ID field is set up so that it clears (empties) when editing begins
// (see storyboard), but that doesn't count as an editing change. Update the
// 'Done' button state here to account for that.
//
- ( void ) textFieldDidBeginEditing: ( UITextField * ) textField
{
    if ( textField == self.numberField )
    {
        self.navigationItem.rightBarButtonItem.enabled = [ self hasCompleteStopID ];
    }
}

// The 'Done' button adds the stop, as long as there's a complete stop ID;
// otherwise it does nothing.
//
- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    if ( textField == self.descriptionField && [ self hasCompleteStopID ] )
    {
        [ self addStop: nil ];
        return YES;
    }

    return NO;
}

// From the UITextFieldDelegate protocol and called because the numerical
// entry field has been given the Enter Stop ID object as its delegate in the
// storyboard. The description field is allowed any changes.
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

    UIBarButtonItem * done = [ self installCancelAction: @selector( dismissAdditionView: )
                                          andDoneAction: @selector( addStop: ) ];
    done.enabled = NO;

    [ self.numberField addTarget: self
                          action: @selector( numberFieldDidChange: )
                forControlEvents: UIControlEventEditingChanged ];
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.numberField becomeFirstResponder ];
}

@end
