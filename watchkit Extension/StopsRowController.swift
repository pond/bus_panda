//
//  StopsRowController.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 23/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit

@available( iOS 8.2, * )
class StopsRowController: NSObject {

    @IBOutlet var idLabel:          WKInterfaceLabel!
    @IBOutlet var descriptionLabel: WKInterfaceLabel!

    var stopInfo: NSDictionary?
    {
        didSet
        {
            if let stopInfo = stopInfo
            {
                         idLabel.setText( stopInfo[ "stopID"          ] as? String )
                descriptionLabel.setText( stopInfo[ "stopDescription" ] as? String )
            }
        }
    }
}
