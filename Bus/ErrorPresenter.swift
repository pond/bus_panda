//
//  ErrorPresenter.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 8/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import Foundation
import UIKit

@objc class ErrorPresenter : NSObject
{
    @objc class func showModalAlertFor
    (
        _ controller: UIViewController,
        withError:    NSError,
        title:        NSString,
        andHandler:   @escaping ( _ result: UIAlertAction ) -> Void
    )
    {
        showModalPopupFor(
            controller,
            withMessage: withError.localizedDescription as NSString,
            title:       title,
            button:      "OK",
            andHandler:  andHandler
        )
    }

    @objc class func showModalPopupFor
    (
        _ controller: UIViewController,
         withMessage: NSString,
               title: NSString,
              button: NSString,
          andHandler: @escaping ( _ result: UIAlertAction ) -> Void
    )
    {
        let alert = UIAlertController(
            title:          title       as String,
            message:        withMessage as String,
            preferredStyle: .alert
        )

        let action = UIAlertAction(
            title:   button as String,
            style:   .cancel,
            handler: andHandler
        )

        alert.addAction( action )

        controller.present(
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
