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

    func applicationDidFinishLaunching()
    {
        if WCSession.isSupported()
        {
            let session = WCSession.defaultSession()

            session.delegate = self
            session.activateSession()

            updateAllStopsFrom( session.receivedApplicationContext )
        }
    }

    func applicationDidBecomeActive()
    {
        // Restart any tasks that were paused (or not yet started) while the 
        // application was inactive. If the application was previously in the
        // background, optionally refresh the user interface.
    }

    func applicationWillResignActive()
    {
        // Sent when the application is about to move from active to inactive 
        // state. This can occur for certain types of temporary interruptions
        // (such as an incoming phone call or SMS message) or when the user
        // quits the application and it begins the transition to the background
        // state.
        //
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func presentError(
        error:      NSError,
        handler:    WKAlertActionHandler?,
        controller: WKInterfaceController?
    )
    {
        var actualHandler:    WKAlertActionHandler
        var actualController: WKInterfaceController

        if ( handler == nil )
        {
            actualHandler = { _ in }
        }
        else
        {
            actualHandler = handler!
        }

        if ( controller == nil )
        {
            actualController = WKExtension.sharedExtension().rootInterfaceController!
        }
        else
        {
            actualController = controller!
        }

        let action = WKAlertAction.init(
            title:   "OK",
            style:   .Default,
            handler: actualHandler
        )

        actualController.presentAlertControllerWithTitle(
                            error.localizedDescription,
            message:        error.localizedFailureReason,
            preferredStyle: .Alert,
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

    func updateAllStopsFrom( dictionary: [ String : AnyObject ] )
    {
        let stops = dictionary[ "allStops" ] as? NSArray

        dispatch_async( dispatch_get_main_queue() )
        {
            let stopsInterfaceController = WKExtension.sharedExtension().rootInterfaceController
                as! StopsInterfaceController

            stopsInterfaceController.updateStops( stops )
        }
    }

    func session( session: WCSession, didReceiveApplicationContext applicationContext: [ String : AnyObject ] )
    {
        updateAllStopsFrom( applicationContext )
    }
}
