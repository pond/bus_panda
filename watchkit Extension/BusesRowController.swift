//
//  BusesRowController.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 26/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit

@available( iOS 8.2, * )
class BusesRowController: NSObject
{
    @IBOutlet var nameLabel:             WKInterfaceLabel!
    @IBOutlet var timeLabel:             WKInterfaceLabel!
    @IBOutlet var numberLabel:           WKInterfaceLabel!
    @IBOutlet var numberBackgroundGroup: WKInterfaceGroup!

    var busInfo: NSDictionary?
    {
        didSet
        {
            if let busInfo = busInfo
            {
                nameLabel.setText( busInfo[ "routeName"   ] as? String )
                timeLabel.setText( busInfo[ "dueTime"     ] as? String )

                let routeNumber  = busInfo[ "routeNumber" ] as? String
                var routeColour  = busInfo[ "colour"      ] as? String

                if ( routeColour == nil )
                {
                    routeColour = "888888"
                }

                let uiColor = RouteColours.colourFromHexString( routeColour! )
                numberBackgroundGroup.setBackgroundColor( uiColor )

                numberLabel.setText( routeNumber )
            }
        }
    }
}
