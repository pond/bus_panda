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
    @IBOutlet var stopsTable: WKInterfaceTable!
    @IBOutlet var    spinner: WKInterfaceImage!

    func showSpinner()
    {
        spinner.setImageNamed( "Activity" )
        spinner.startAnimatingWithImages(
                         in: NSMakeRange( 0, 15 ),
               duration: 1.0,
            repeatCount: 0
        )

        stopsTable.setHidden( true )
        spinner.setHidden( false )
    }

    func hideSpinner()
    {
        spinner.setHidden( true )
        stopsTable.setHidden( false )

        spinner.stopAnimating()
    }

    // ========================================================================
    // MARK: - Lifecycle
    // ========================================================================

    // This method is called when watch view controller is about to be
    // visible to user
    //
    override func willActivate()
    {
        super.willActivate()

        self.hideSpinner()

        if WCSession.isSupported()
        {
            let session  = WCSession.default()
            let delegate = WKExtension.shared().delegate as! ExtensionDelegate

            delegate.updateAllStopsFrom( session.receivedApplicationContext as [ String: AnyObject ] )
        }
    }

    // Wake up and, if we don't seem to have any stops defined locally, try
    // contacting the iOS application to find some.
    //
    override func awake( withContext context: Any? )
    {
        super.awake( withContext: context )

        if stopsTable.numberOfRows > 0
        {
            return // Note early exit
        }

        let session  = WCSession.default()
        let delegate = WKExtension.shared().delegate as! ExtensionDelegate

        showSpinner()

        if ( session.activationState == .activated && session.isReachable )
        {
            let message: [ String: String ] = [ "action": "getStops" ]

            // This has no reply handler because we don't get a reply. Instead
            // the iOS handling code pushes an application context update which
            // we'll get eventually. This reduces the number of different code
            // paths in use.
            //
            session.sendMessage(
                message,
                replyHandler: nil,
                errorHandler:
                {
                    ( error: Error ) -> Void in

                    self.hideSpinner()

                    // TODO: As in BusesInterfaceController, we can't rely on
                    // this because of an apparent WatchOS 2.2 bug.
                    //
                    // https://forums.developer.apple.com/thread/43380
                    //
//                    delegate.presentError(
//                        error,
//                        handler:    { () -> Void in self.dismissController() },
//                        controller: self
//                    )
                }
            )
        }
        else
        {
            hideSpinner()

            let error = NSError(
                domain:   "uk.org.pond.Bus-Panda-WKExtension",
                code:     -9999,
                userInfo:
                [
                    NSLocalizedDescriptionKey:        "No iPhone Found",
                    NSLocalizedFailureReasonErrorKey: "Cannot reach your iPhone to ask Bus Panda for bus stops"
                ]
            )

            delegate.presentError(
                            error,
                handler:    { () -> Void in self.dismiss() },
                controller: self
            )
        }
    }

    // ========================================================================
    // MARK: - WKInterfaceTable selection and updates
    // ========================================================================

    // Handle table selections. Showing the realtime information for the buses
    // at the selected stop requires the iOS application, so this must be
    // reachable.
    //
    override func table( _ table: WKInterfaceTable, didSelectRowAt rowIndex: Int )
    {
        let controller = stopsTable.rowController( at: rowIndex ) as? StopsRowController
        pushController( withName: "Buses", context: controller?.stopInfo )
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
    func updateStops( _ allStops: NSArray? )
    {
        let stringShortener = StringShortener()
        let stops           = ( allStops == nil ) ? NSArray() : allStops!

        stopsTable.setNumberOfRows( stops.count, withRowType: "StopsRow" )
        stringShortener.maxCharactersPerLine = 17

        for index in 0 ..< stopsTable.numberOfRows
        {
            let controller = stopsTable.rowController( at: index ) as? StopsRowController
            let dictionary = stops[ index ] as! NSDictionary

            let stopID          = dictionary[ "stopID"          ] as! String
            var stopDescription = dictionary[ "stopDescription" ] as! String

            stopDescription = stringShortener.shortenDescription( stopDescription )

            let stopInfo: [ String: String ] =
            [
                "stopID":          stopID,
                "stopDescription": stopDescription
            ]

            controller?.stopInfo = stopInfo as NSDictionary?
        }
    }

}
