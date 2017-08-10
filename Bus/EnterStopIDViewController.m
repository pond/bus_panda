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

         self.numberToolbar = [ [UIToolbar alloc ] initWithFrame: frame ];
    self.descriptionToolbar = [ [UIToolbar alloc ] initWithFrame: frame ];

         self.numberToolbar.barStyle = UIBarStyleDefault;
    self.descriptionToolbar.barStyle = UIBarStyleDefault;

    self.numberToolbar.items =
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

    self.descriptionToolbar.items =
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
}

// The numeric keyboard for stop ID and text keyboard for description have
// "cancel"/"add" buttons above implemented as a keyboard toolbar. These are
// resized via "sizeToFit". It transpires that different heights are applied
// in portrait or landscape mode and, on a device with a screen width of the
// iPhone 5 or 4, as examples, starting in portrait mode and rotating to
// landscape causes the toolbar to abut the text fields unless resizing is
// carried out again. We need to do this sizing *after* the rotation has
// happened, hence the block below. Via:
//
//   https://stackoverflow.com/questions/26315046/ios-8-orientation-change-detection
//
- ( void ) viewWillTransitionToSize: ( CGSize ) size
          withTransitionCoordinator: ( id <UIViewControllerTransitionCoordinator> ) coordinator
{
    [ super viewWillTransitionToSize: size withTransitionCoordinator: coordinator ];

    BOOL      numberWasFirstResponder = [      self.numberField isFirstResponder ];
    BOOL descriptionWasFirstResponder = [ self.descriptionField isFirstResponder ];

    // I've tried a lot of approaches and I just cannot get an on-screen
    // keyboard to respond to any kind of changes in the input accessory
    // view unless we just resign then reassign the first responder, making
    // the keyboard close and reopen. That's ugly on rotation but we try to
    // minimise the impact by only doing it on iPhone where the bar metrics
    // must change and only doing it if first responder is actually
    // assigned. It's still a better end result than doing nothing.
    //
    if (
           UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
           ( numberWasFirstResponder || descriptionWasFirstResponder )
       )
    {
        if (      numberWasFirstResponder ) [      self.numberField resignFirstResponder ];
        if ( descriptionWasFirstResponder ) [ self.descriptionField resignFirstResponder ];

        [
            coordinator animateAlongsideTransition: nil
                                        completion: ^ ( id <UIViewControllerTransitionCoordinatorContext> context )
            {
                [ self redefineKeyboardToolbars ];

                     self.numberField.inputAccessoryView = self.numberToolbar;
                self.descriptionField.inputAccessoryView = self.descriptionToolbar;

                if (      numberWasFirstResponder ) [      self.numberField becomeFirstResponder ];
                if ( descriptionWasFirstResponder ) [ self.descriptionField becomeFirstResponder ];
            }
        ];
    }
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
    [ self redefineKeyboardToolbars ];

         self.numberField.inputAccessoryView = self.numberToolbar;
    self.descriptionField.inputAccessoryView = self.descriptionToolbar;
}

- ( void ) viewDidAppear: ( BOOL ) animated
{
    [ super viewDidAppear: animated ];
    [ self.numberField becomeFirstResponder ];
}

@end
