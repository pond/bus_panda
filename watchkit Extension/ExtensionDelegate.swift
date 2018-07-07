//
//  ExtensionDelegate.swift
//  watchkit Extension
//
//  Created by Andrew Hodgkinson on 11/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit
import WatchConnectivity
import CoreData

@available( iOS 8.2, * )
class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate
{
    // ========================================================================
    // MARK: - WCSession support.
    // ========================================================================

    override init()
    {
        super.init()

        if WCSession.isSupported()
        {
            let session = WCSession.default

            session.delegate = self
            session.activate()
        }
    }

    func applicationDidFinishLaunching()
    {
        if WCSession.isSupported()
        {
            updateAllStopsFrom( WCSession.default.receivedApplicationContext as [String : AnyObject] )
        }
    }

    func applicationDidBecomeActive()
    {
    }

    func applicationWillResignActive()
    {
    }

    func presentError(
        _ error:      NSError,
        handler:    WKAlertActionHandler?,
        controller: WKInterfaceController?
    )
    {
        var actualHandler:    WKAlertActionHandler
        var actualController: WKInterfaceController

        if ( handler == nil )
        {
            actualHandler = {  }
        }
        else
        {
            actualHandler = handler!
        }

        if ( controller == nil )
        {
            actualController = WKExtension.shared().rootInterfaceController!
        }
        else
        {
            actualController = controller!
        }

        let action = WKAlertAction.init(
            title:   "OK",
            style:   .default,
            handler: actualHandler
        )

        actualController.presentAlert(
                            withTitle: error.localizedDescription,
            message:        error.localizedFailureReason,
            preferredStyle: .alert,
            actions:        [ action ]
        )
    }

    // ========================================================================
    // MARK: - WCSessionDelegate and related code
    // ========================================================================

    func session( _ session: WCSession,
                  activationDidCompleteWith activationState: WCSessionActivationState,
                  error: Error? )
    {
    }

    func session( _ session: WCSession, didReceiveApplicationContext applicationContext: [ String : Any ] )
    {
        updateAllStopsFrom( applicationContext as [String : AnyObject] )
    }

    func updateAllStopsFrom( _ dictionary: [ String : AnyObject ] )
    {
        let stops = dictionary[ "allStops" ] as? NSArray

        DispatchQueue.main.async
        {
            let stopsInterfaceController = WKExtension.shared().rootInterfaceController
                as? StopsInterfaceController

            if ( stopsInterfaceController != nil )
            {
                stopsInterfaceController!.updateStops( stops )
            }
        }
    }
}
