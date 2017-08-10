//
//  GlanceController.swift
//  watchkit Extension
//
//  Created by Andrew Hodgkinson on 11/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

public func myNSLog(_ givenFormat: String, _ args: CVarArg..., _func function:String = #function) {
    let format = "\(function): \(givenFormat)"
    withVaList(args) { NSLogv(format, $0) }
}

@available( iOS 9, * )
class GlanceController: WKInterfaceController, WCSessionDelegate
{
    @IBOutlet var stopNameLabel:        WKInterfaceLabel!
    @IBOutlet var stopNumberLabel:      WKInterfaceLabel!

    @IBOutlet var row1Group:            WKInterfaceGroup!
    @IBOutlet var row2Group:            WKInterfaceGroup!
    @IBOutlet var spinnerImage:         WKInterfaceImage!
    @IBOutlet var errorMessageGroup:    WKInterfaceGroup!
    @IBOutlet var errorMessageLabel:    WKInterfaceLabel!

    @IBOutlet var bus1Group:            WKInterfaceGroup!
    @IBOutlet var bus1NumberBackground: WKInterfaceGroup!
    @IBOutlet var bus1NumberLabel:      WKInterfaceLabel!
    @IBOutlet var bus1TimeLabel:        WKInterfaceLabel!

    @IBOutlet var bus2Group:            WKInterfaceGroup!
    @IBOutlet var bus2NumberBackground: WKInterfaceGroup!
    @IBOutlet var bus2NumberLabel:      WKInterfaceLabel!
    @IBOutlet var bus2TimeLabel:        WKInterfaceLabel!

    @IBOutlet var bus3Group:            WKInterfaceGroup!
    @IBOutlet var bus3NumberBackground: WKInterfaceGroup!
    @IBOutlet var bus3NumberLabel:      WKInterfaceLabel!
    @IBOutlet var bus3TimeLabel:        WKInterfaceLabel!

    @IBOutlet var bus4Group:            WKInterfaceGroup!
    @IBOutlet var bus4NumberBackground: WKInterfaceGroup!
    @IBOutlet var bus4NumberLabel:      WKInterfaceLabel!
    @IBOutlet var bus4TimeLabel:        WKInterfaceLabel!

    var busOutlets: [ [ String: AnyObject ] ] = []

    // ========================================================================
    // MARK: - Convenience
    // ========================================================================

    func canUseWCSession() -> Bool
    {
        return WCSession.isSupported() &&
            WCSession.default.activationState == .activated &&
            WCSession.default.isReachable
    }

    // ========================================================================
    // MARK: - Lifecycle
    // ========================================================================

    override func awake( withContext context: Any? )
    {
        super.awake( withContext: context )

        // Using this array of dictionaries, we can iterate over each bus item
        // in the Glance view and either hide groups (if we don't have enough
        // buses to show) or fill in information.
        //
        busOutlets =
        [
            [
                "group":            bus1Group,
                "numberBackground": bus1NumberBackground,
                "numberLabel":      bus1NumberLabel,
                "timeLabel":        bus1TimeLabel
            ],
            [
                "group":            bus2Group,
                "numberBackground": bus2NumberBackground,
                "numberLabel":      bus2NumberLabel,
                "timeLabel":        bus2TimeLabel
            ],
            [
                "group":            bus3Group,
                "numberBackground": bus3NumberBackground,
                "numberLabel":      bus3NumberLabel,
                "timeLabel":        bus3TimeLabel
            ],
            [
                "group":            bus4Group,
                "numberBackground": bus4NumberBackground,
                "numberLabel":      bus4NumberLabel,
                "timeLabel":        bus4TimeLabel
            ]
        ];
    }

    override func willActivate()
    {
        super.willActivate()

        // 2016-03-31 (ADH): TODO
        //
        // I was unable with either Apple's demo "PotLoc" code or anything I
        // tried here, for over three hours, to ever pursuade the simulator to
        // prompt for location access on the iPhone side if the WatchOS side
        // asked for authorisation.
        //
        // As a result I'm unable to test or debug any such code and am forced
        // to give up. The user MUST have run Bus Panda on iOS first and
        // granted access; so we do all the heavy lifting there. This glance
        // controller just sends a message to iOS asking for bus details and
        // either gets back those details or gets an error message saying
        // something like "run Bus Panda and grant access first".
        //
        // Yuck.

        stopNameLabel.setText( "Finding Nearest" )
        stopNumberLabel.setText( "Bus Stop" )

        showSpinner()

        NSLog(
            "GLA Session supported %@, activated %@, reachable %@",
            WCSession.isSupported() as NSNumber,
            ( WCSession.default.activationState == .activated ) as NSNumber,
            WCSession.default.isReachable as NSNumber
        )

        // Worse yet, the glance often finds that at this moment of activation
        // the WCSession for some reason isn't ready. Race condition; sometimes
        // it is, sometimes not. Since we need to set the WCSession up in the
        // ExtensionDelegate, and since this controller runs in the same
        // process, we don't really want to risk (say) temporarily assigning
        // ourselves as the WCSession delegate, so we can't see activation
        // changes in this code and attempting to wire up a path for that from
        // the ExtensionDelegate handler would be very fiddly.
        //
        // Instead, hack-of-the-century becomes necessary; sleep for a short
        // period and check again, giving up if there's still no activation.

        if WCSession.isSupported()
        {
            let session  = WCSession.default
            let delegate = WKExtension.shared().delegate as! ExtensionDelegate

            session.delegate = delegate
            session.activate()
        }

        if canUseWCSession()
        {
            self.requestBuses()
        }
        else
        {
            DispatchQueue.main.asyncAfter(
                deadline: DispatchTime.now() + Double(100000000) / Double(NSEC_PER_SEC),
                execute: {
                    NSLog(
                        "GLA via GCD Session supported %@, activated %@, reachable %@",
                        WCSession.isSupported() as NSNumber,
                        ( WCSession.default.activationState == .activated ) as NSNumber,
                        WCSession.default.isReachable as NSNumber
                    )

                    if self.canUseWCSession()
                    {
                        self.requestBuses()
                    }
                    else
                    {
                        self.showError( "Cannot reach your iPhone to ask Bus Panda for bus times." )
                    }
                }
            );
        }
    }

    // Called when the session has completed activation. If session state is
    // WCSessionActivationStateNotActivated there will be an error with more
    // details.
    //
    @available(watchOS 2.2, *)
    public func session(_                 session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
                                            error: Error? )
    {
    }

    override func willDisappear()
    {
    }

    // ========================================================================
    // MARK: - Bus info display
    // ========================================================================

    // Request the update from the iPhone. Re-checks reachability here,
    // though the intention is that the caller will do this too.
    //
    func requestBuses()
    {
        if ( canUseWCSession() == false )
        {
            NSLog( "Unexpected inabilty to use WCSession in requestBuses" )
            return
        }

        NSLog("Send message");

        WCSession.default.sendMessage(
            [ "action": "getNearest" ],
            replyHandler:
            {
                ( busInfo: [ String: Any ] ) -> Void in

                if busInfo[ "error" ] != nil
                {
                    self.showError( busInfo[ "error" ] as! String )
                }
                else if busInfo[ "buses" ] != nil
                {
                    var stopDescription = busInfo[ "stopDescription" ] as? String
                    if ( stopDescription == nil ) { stopDescription = ""; }

                    let stringShortener = StringShortener()
                    stringShortener.maxCharactersPerLine = 21

                    self.stopNameLabel.setText( stringShortener.shortenDescription( stopDescription! ) )
                    self.stopNumberLabel.setText( busInfo[ "stopID" ] as? String )

                    self.updateBuses( busInfo[ "buses" ] as? NSArray )
                }
                else
                {
                    self.showError( "Bus Panda was unable to find any nearby stops." )
                }
            },
            errorHandler:
            {
                ( error: Error ) -> Void in

                // TODO: As in BusesInterfaceController, we can't rely on
                // this because of an apparent WatchOS 2.2 bug.
                //
                // https://forums.developer.apple.com/thread/43380
                //
                // self.showError( error.localizedDescription )
            }
        )
    }

    // This takes an array of services. That's like any "services" section in
    // a dictionary from the array given to BusesInterfaceController's
    // -updateBuses method; all we're interested in here is the service list,
    // so the caller should decide what to send. We're only interested in up
    // to four entries, so sending more is wasteful. If there are fewer
    // entries, then the remaining "slots" in the UI are blanked out.
    //
    func updateBuses( _ allBuses: NSArray? )
    {
        let buses    = allBuses!
        let busCount = buses.count

        for index in 0 ..< 4
        {
            let outlets               = busOutlets[ index ]
            let group                 = outlets[ "group"            ] as! WKInterfaceGroup
            let numberBackgroundGroup = outlets[ "numberBackground" ] as! WKInterfaceGroup
            let numberLabel           = outlets[ "numberLabel"      ] as! WKInterfaceLabel
            let dueTimeLabel          = outlets[ "timeLabel"        ] as! WKInterfaceLabel

            if index < busCount
            {
                let dictionary = buses[ index ] as! NSDictionary

                let routeNumber = dictionary[ "number" ] as! String
                var routeColour = dictionary[ "colour" ] as? String
                let dueTime     = dictionary[ "when"   ] as! String

                numberLabel.setText( routeNumber )
                dueTimeLabel.setText( dueTime )

                if ( routeColour == nil )
                {
                    routeColour = "888888"
                }

                let uiColor = RouteColours.colourFromHexString( routeColour! )
                numberBackgroundGroup.setBackgroundColor( uiColor )

                group.setHidden( false )
            }
            else
            {
                group.setHidden( true )
            }
        }

        showRows()
    }

    // ========================================================================
    // MARK: - Show/hide user interface sections
    //
    // In all cases, the "show" method hides any other user interface elements
    // but the companion "hide" method does not re-show other user interface
    // components because it doesn't know which to show. In general you never
    // call these directly outside the collection - just call a 'show' method,
    // which deals with hiding everything else.
    // ========================================================================

    func showSpinner()
    {
        spinnerImage.setImageNamed( "Activity" )
        spinnerImage.startAnimatingWithImages(
            in: NSMakeRange( 0, 15 ),
            duration: 1.0,
            repeatCount: 0
        )

        spinnerImage.setHidden( false )

        hideRows()
        hideError()
    }

    func hideSpinner()
    {
        spinnerImage.setHidden( true )
        spinnerImage.stopAnimating()
    }

    func showError( _ message: String )
    {
        stopNameLabel.setText( "Sorry" )
        stopNumberLabel.setText( ":-(" )

        errorMessageLabel.setText( message )
        errorMessageGroup.setHidden( false )

        hideRows()
        hideSpinner()
    }

    func hideError()
    {
        errorMessageGroup.setHidden( true )
    }

    func showRows()
    {
        hideError()
        hideSpinner()

        row1Group.setHidden( false )
        row2Group.setHidden( false )
    }

    func hideRows()
    {
        row2Group.setHidden( true )
        row1Group.setHidden( true )
    }

}
