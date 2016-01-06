//
//  ErrorPresenter.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 6/01/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

#import "ErrorPresenter.h"

@implementation ErrorPresenter

+ ( void ) showModalAlertFor: ( UIViewController * ) controller
                   withError: ( NSError          * ) error
                       title: ( NSString         * ) title
                  andHandler: ( void ( ^ ) ( UIAlertAction * action ) ) handler;
{
    NSString          * message = [ error localizedDescription ];
    UIAlertController * alert   = [ UIAlertController alertControllerWithTitle: title
                                                                       message: message
                                                                preferredStyle: UIAlertControllerStyleAlert ];

    UIAlertAction     * action  = [ UIAlertAction actionWithTitle: @"OK"
                                                            style: UIAlertActionStyleDefault
                                                          handler: handler ];

    [ alert addAction: action ];
    [ controller presentViewController: alert animated: YES completion: nil ];
}

@end
