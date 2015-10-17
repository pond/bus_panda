//
//  EnterStopIDViewController.m
//  Bus
//
//  Created by Andrew Hodgkinson on 29/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "EnterStopIDViewController.h"
#import "MasterViewController.h"

@interface EnterStopIDViewController ()
@property ( weak, nonatomic ) MasterViewController * presentingMVC;
@end

@implementation EnterStopIDViewController

- ( void ) rememberPresentingMVC: ( MasterViewController * ) mvc
{
    self.presentingMVC = mvc;
}

// "sender" is ignored
//
- ( IBAction ) cancelNumberPad: ( id ) sender
{
    ( void ) sender;

    [ self.numberField setText: @"" ];
    [ self.numberField resignFirstResponder ];

    [ self.descriptionField setText: @"" ];
    [ self.descriptionField resignFirstResponder ];

    [ self dismissViewControllerAnimated: YES completion: nil ];
}

// "sender" is ignored
//
- ( IBAction ) acceptNumberPad: ( id ) sender
{
    ( void ) sender;

    NSString * stopID          = self.numberField.text;
    NSString * stopDescription = self.descriptionField.text;

    if ( stopID.length == 4 ) [ self.presentingMVC addFavourite: stopID
                                                withDescription: stopDescription];

    [ self cancelNumberPad: nil ];
}

- ( BOOL ) textFieldShouldReturn: ( UITextField * ) textField
{
    [ self acceptNumberPad: textField ];
    return NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = [NSArray arrayWithObjects:
                           [[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad:)],
                           [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                           [[UIBarButtonItem alloc]initWithTitle:@"Add Stop ID" style:UIBarButtonItemStyleDone target:self action:@selector(acceptNumberPad:)],
                           nil];
    [numberToolbar sizeToFit];
    self.numberField.inputAccessoryView = numberToolbar;
}

- (void) viewDidAppear:(BOOL)animated
{
    [ super viewDidAppear: animated ];
    [ self.numberField becomeFirstResponder ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
