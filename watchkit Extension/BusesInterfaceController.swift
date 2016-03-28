//
//  BusesInterfaceController.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 26/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation

@available(iOS 8.2, *)
class BusesInterfaceController: WKInterfaceController
{
    static let maximumListEntries = 10

    @IBOutlet var busesTable: WKInterfaceTable!
    @IBOutlet var    spinner: WKInterfaceImage!

    func showSpinner()
    {
        spinner.setImageNamed( "Activity" )
        spinner.startAnimatingWithImagesInRange(
                         NSMakeRange( 0, 15 ),
               duration: 1.0,
            repeatCount: 0
        )

        busesTable.setHidden( true )
        spinner.setHidden( false )
    }

    func hideSpinner()
    {
        spinner.setHidden( true )
        busesTable.setHidden( false )

        spinner.stopAnimating()
    }

    // Wake up upon being presented by StopsInterfaceController. The context
    // object is a mandatory dictionary containing at the least a "stopID"
    // String key yielding a String with the numerical or alphabetic four
    // character stop ID.
    //
    override func awakeWithContext( context: AnyObject? )
    {
        super.awakeWithContext( context )

        let session  = WCSession.defaultSession()
        let delegate = WKExtension.sharedExtension().delegate as! ExtensionDelegate
        let stopInfo = context as? [ String: String ]

        showSpinner()

        // Make sure the table view is empty to start with. Cannot do anything
        // else this early on in the lifecycle.
        //
        updateBuses( [] )

        if ( session.reachable )
        {
            let message: [ String: String ] =
            [
                "action": "getBuses",
                "data":   stopInfo![ "stopID" ]!
            ]

            session.sendMessage(
                message,
                replyHandler:
                {
                    ( busInfo: [ String: AnyObject ] ) -> Void in

                    let sections = busInfo[ "allBuses" ] as! NSArray
                    let stops    = [] as NSMutableArray

                    for section in sections
                    {
                        let services: NSMutableArray = section[ "services" ] as! NSMutableArray

                        stops.addObjectsFromArray( services as [AnyObject] )
                        if ( stops.count > BusesInterfaceController.maximumListEntries ) { break }
                    }

                    self.updateBuses( stops )
                    self.hideSpinner()
                },
                errorHandler:
                {
                    ( error: NSError ) -> Void in

                    self.hideSpinner()

                    // TODO: There appears to be a WatchOS 2.2 bug (simulator
                    // only?) that causes a 'message timeout' error to fire for
                    // a message even if it's been replied to and the handler
                    // above has already run.
                    //
                    // Uncomment the error presenter below once fixed.
                    //
                    // Considering this is the main Watch<->iOS communications
                    // API, that's a seriously clumsy bug, even for Apple.
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
                    NSLocalizedFailureReasonErrorKey: "Cannot reach your iPhone to ask Bus Panda for bus times"
                ]
            )

            delegate.presentError(
                            error,
                handler:    { () -> Void in self.dismissController() },
                controller: self
            )
        }
    }

    // This method is called when watch view controller is about to be visible
    // to user
    //
    override func willActivate()
    {
        super.willActivate()
    }

    // This method is called when watch view controller is no longer visible
    //
    override func didDeactivate()
    {
        super.didDeactivate()
    }

    // ========================================================================
    // MARK: - WKInterfaceTable selection and updates
    // ========================================================================

    // This only takes as many entries as it is comfortable with - Apple's
    // documentation mentions 20 (March 2016) as a typical maximum list limit
    // and, in context, that may be excessive; see "maximumListEntries" for the
    // limit applied here.
    //
    func updateBuses( allBuses: NSArray? )
    {
        let buses    = ( allBuses == nil ) ? NSArray() : allBuses!
        let rowCount = min( BusesInterfaceController.maximumListEntries, buses.count )

        busesTable.setNumberOfRows( rowCount, withRowType: "BusesRow" )

        for index in 0 ..< rowCount
        {
            let controller = busesTable.rowControllerAtIndex( index ) as? BusesRowController
            let dictionary = buses[ index ] as! NSDictionary

            let routeName   = dictionary[ "name"   ] as! String
            let routeNumber = dictionary[ "number" ] as! String
            let colour      = dictionary[ "colour" ] as! String
            let dueTime     = dictionary[ "when"   ] as! String

            let busInfo: [ String: String ] =
            [
                "routeName":   routeName,
                "routeNumber": routeNumber,
                "colour":      colour,
                "dueTime":     dueTime
            ]
            
            controller?.busInfo = busInfo
        }
    }
}
