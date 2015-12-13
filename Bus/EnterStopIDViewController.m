//
//  EnterStopIDViewController.m
//  Bus
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

// Move input focus to the 'description' field.
//
// "sender" is ignored.
//
- ( IBAction ) moveToDescription: ( id ) sender
{
    ( void ) sender;
    [ self.descriptionField becomeFirstResponder ];
}

- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    [ self dismissAdditionView: textField ];
    return NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIToolbar *      numberToolbar = [ [ UIToolbar alloc ] initWithFrame: CGRectMake( 0, 0, 320, 50 ) ];
    UIToolbar * descriptionToolbar = [ [ UIToolbar alloc ] initWithFrame: CGRectMake( 0, 0, 320, 50 ) ];

         numberToolbar.barStyle = UIBarStyleDefault;
    descriptionToolbar.barStyle = UIBarStyleDefault;

    numberToolbar.items =
    [
        NSArray arrayWithObjects:

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Cancel"
                                            style: UIBarButtonItemStylePlain
                                           target: self
                                           action: @selector( dismissAdditionView: ) ],

        [ [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace
                                                         target: nil
                                                         action: nil ],

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Next"
                                            style: UIBarButtonItemStylePlain
                                           target: self
                                           action: @selector( moveToDescription: ) ],
        nil
    ];

    descriptionToolbar.items =
    [
        NSArray arrayWithObjects:

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Cancel"
                                            style: UIBarButtonItemStylePlain
                                           target: self
                                           action: @selector( dismissAdditionView: ) ],

        [ [ UIBarButtonItem alloc ] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace
                                                         target: nil
                                                         action: nil ],

        [ [ UIBarButtonItem alloc ] initWithTitle: @"Add Stop ID"
                                            style: UIBarButtonItemStyleDone
                                           target: self
                                           action: @selector( addStop: ) ],
        nil
    ];

    [      numberToolbar sizeToFit ];
    [ descriptionToolbar sizeToFit ];

         self.numberField.inputAccessoryView = numberToolbar;
    self.descriptionField.inputAccessoryView = descriptionToolbar;
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.numberField becomeFirstResponder ];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
