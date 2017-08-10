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

//    // ========================================================================
//    // MARK: - Core Data support.
//    // ========================================================================
//    //
//    // The iOS application uses WCSession to tell this watch application about
//    // the list of favourite stops. The watch application itself then keeps a
//    // copy of that data locally.
//    //
//    // It's a very great pity that iCloud Core Data sync cannot be achieved
//    // with Watch OS 2.
//
//    lazy var applicationDocumentsDirectory: NSURL =
//    {
//        let urls = NSFileManager.defaultManager().URLsForDirectory(
//            .DocumentDirectory,
//            inDomains: .UserDomainMask
//        )
//
//        return urls[ urls.count - 1 ]
//    }()
//
//    // The managed object model for the application. This property is not
//    // optional. It is a fatal error for the application not to be able to
//    // find and load its model.
//    //
//    lazy var managedObjectModel: NSManagedObjectModel =
//    {
//        let modelURL = NSBundle.mainBundle().URLForResource(
//            "Bus-Panda-WKExtension",
//            withExtension: "momd"
//        )!
//
//        return NSManagedObjectModel( contentsOfURL: modelURL )!
//    }()
//
//    // The persistent store coordinator for the application. This
//    // implementation creates and returns a coordinator, having added the
//    // store for the application to it. This property is optional since there
//    // are legitimate error conditions that could cause the creation of the
//    // store to fail.
//    //
//    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator =
//    {
//        let coordinator   = NSPersistentStoreCoordinator( managedObjectModel: self.managedObjectModel )
//        let url           = self.applicationDocumentsDirectory.URLByAppendingPathComponent( "Bus-Panda-WKExtension.sqlite" )
//        var failureReason = "Unexpected error encountered - cannot continue."
//
//        do
//        {
//            try coordinator.addPersistentStoreWithType(
//                NSSQLiteStoreType,
//
//                configuration: nil,
//                URL:           url,
//                options:       nil
//            )
//        }
//        catch
//        {
//            var dict = [ String: AnyObject ]()
//
//            dict[ NSLocalizedDescriptionKey        ] = "Could not load favourites"
//            dict[ NSLocalizedFailureReasonErrorKey ] = failureReason
//            dict[ NSUnderlyingErrorKey             ] = error as NSError
//
//            let wrappedError = NSError(
//                domain:   "uk.org.pond.Bus-Panda-WKExtension",
//                code:     9999,
//                userInfo: dict
//            )
//
//            // Tell the user, log it, then bail. There's nothing we can do to
//            // recover from this. The application is useless without the list
//            // of favourite stops.
//
//            self.presentError( wrappedError )
//
//            NSLog( "Unresolved error \( wrappedError ), \( wrappedError.userInfo )" )
//            abort()
//        }
//
//        return coordinator
//    }()
//
//    // Returns the managed object context for the application (which is already
//    // bound to the persistent store coordinator for the application.) This
//    // property is optional since there are legitimate error conditions that
//    // could cause the creation of the context to fail.
//    //
//    lazy var managedObjectContext: NSManagedObjectContext =
//    {
//        let coordinator          = self.persistentStoreCoordinator
//        var managedObjectContext = NSManagedObjectContext( concurrencyType: .MainQueueConcurrencyType )
//
//        managedObjectContext.persistentStoreCoordinator = coordinator
//
//        return managedObjectContext
//    }()
//
//    func saveContext()
//    {
//        if managedObjectContext.hasChanges
//        {
//            do
//            {
//                try managedObjectContext.save()
//            }
//            catch
//            {
//                // Nothing much we can do to recover, but it isn't necessarily
//                // fatal; it might mean we get a bit out of step with the iOS
//                // application though. Present a fairly useless error to the
//                // user really just so they hopefully start to expect that the
//                // application might misbehave after this, but don't exit.
//
//                let nserror = error as NSError
//                self.presentError( nserror )
//                NSLog( "Unresolved error \( nserror ), \( nserror.userInfo )" )
//            }
//        }
//    }

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
