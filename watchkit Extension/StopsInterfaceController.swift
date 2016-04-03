//
//  InterfaceController.swift
//  watchkit Extension
//
//  Created by Andrew Hodgkinson on 11/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation

@available( iOS 8.2, * )
class StopsInterfaceController: WKInterfaceController
{
    // ========================================================================
    // MARK: - Lifecycle
    // ========================================================================

    // This method is called when watch view controller is about to be
    // visible to user
    //
    override func willActivate()
    {
        super.willActivate()

        if WCSession.isSupported()
        {
            let session  = WCSession.defaultSession()
            let delegate = WKExtension.sharedExtension().delegate as! ExtensionDelegate

            delegate.updateAllStopsFrom( session.receivedApplicationContext )
        }
    }

    // ========================================================================
    // MARK: - WKInterfaceTable selection and updates
    // ========================================================================

    @IBOutlet var stopsTable: WKInterfaceTable!

    // Handle table selections. Showing the realtime information for the buses
    // at the selected stop requires the iOS application, so this must be
    // reachable.
    //
    override func table( table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int )
    {
        let controller = stopsTable.rowControllerAtIndex( rowIndex ) as? StopsRowController
        pushControllerWithName( "Buses", context: controller?.stopInfo )
    }

    // Update the WKInterfaceTable list of stops based on the given NSArray
    // of dictionaries. Each is expected to have "stopID" (four digit/letter
    // stop ID) and "stopDescription" (human-readable description). A human
    // parseable decimation algorithm tries to reduce the description length
    // to better fit the narrow watch display; e.g. "Street" might get
    // shortened to "St", or even removed entirely (e.g. "Victoria Street at
    // Ghuznee Street" might shorten right down to "Victoria Ghuznee"). For
    // the most aggressive last attempt, vowels are removed.
    //
    func updateStops( allStops: NSArray? )
    {
        let stringShortener = StringShortener()
        let stops           = ( allStops == nil ) ? NSArray() : allStops!

        stopsTable.setNumberOfRows( stops.count, withRowType: "StopsRow" )
        stringShortener.maxCharactersPerLine = 17

        for index in 0 ..< stopsTable.numberOfRows
        {
            let controller = stopsTable.rowControllerAtIndex( index ) as? StopsRowController
            let dictionary = stops[ index ] as! NSDictionary

            let stopID          = dictionary[ "stopID"          ] as! String
            var stopDescription = dictionary[ "stopDescription" ] as! String

            stopDescription = stringShortener.shortenDescription( stopDescription )

            let stopInfo: [ String: String ] =
            [
                "stopID":          stopID,
                "stopDescription": stopDescription
            ]

            controller?.stopInfo = stopInfo
        }
    }

}
