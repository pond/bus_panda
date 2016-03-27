//
//  ErrorPresenter.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 8/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import Foundation
import UIKit

@objc class ErrorPresenter : NSObject {
    @objc class func showModalAlertFor(
        controller: UIViewController,
        withError:  NSError,
        title:      NSString,
        andHandler: ( result: UIAlertAction ) -> Void
    )
    {
        let message = withError.localizedDescription
        let alert   = UIAlertController(
            title:          title as String,
            message:        message,
            preferredStyle: .Alert
        )

        let action  = UIAlertAction(
            title:   "OK",
            style:   .Default,
            handler: andHandler
        )

        alert.addAction( action )

        controller.presentViewController(
            alert,
            animated: true,
            completion: nil
        )
    }
}

//@implementation ErrorPresenter
//
//+ ( void ) showModalAlertFor: ( UIViewController * ) controller
//                   withError: ( NSError          * ) error
//                       title: ( NSString         * ) title
//                  andHandler: ( void ( ^ ) ( UIAlertAction * action ) ) handler;
//{
//    NSString          * message = [ error localizedDescription ];
//    UIAlertController * alert   = [ UIAlertController alertControllerWithTitle: title
//                                                                       message: message
//                                                                preferredStyle: UIAlertControllerStyleAlert ];
//
//    UIAlertAction     * action  = [ UIAlertAction actionWithTitle: @"OK"
//                                                            style: UIAlertActionStyleDefault
//                                                          handler: handler ];
//
//    [ alert addAction: action ];
//    [ controller presentViewController: alert animated: YES completion: nil ];
//}
//
//@end
