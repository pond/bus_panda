//
//  FavouritesStore.swift
//  Bus Panda Watch App
//
//  The favourite stops to show on the watch. The iPhone app sends them via
//  WatchConnectivity's "application context", which is delivered in the
//  background whenever the watch next connects. The most recent list is
//  cached here so it's available immediately at launch, with or without the
//  iPhone nearby.
//
//  The payload is a dictionary with key "allStops", an array of dictionaries
//  with keys "stopID" (String), "stopDescription" (String) and "preferred"
//  (Bool). See -[DataManager watchPayload] in the iPhone app.
//
//  TODO: Unify, probably via Swift conversion on the iPhone side.
//

import Combine
import Foundation
import WatchConnectivity

// Can be created and used from any thread whatever the target's default
// actor isolation.
//
nonisolated struct FavouriteStop: Identifiable, Hashable, Codable, Sendable
{
    let stopID:          String
    let stopDescription: String
    let preferred:       Bool

    var id: String { stopID }
}

@MainActor
final class FavouritesStore: NSObject, ObservableObject
{
    // Favourite stops in display order (preferred stops first).
    //
    @Published private( set ) var stops: [ FavouriteStop ] = []

    // YES once a list has been received from the iPhone at least once (even
    // an empty one), so the UI can tell "no favourites" from "never synced".
    //
    @Published private( set ) var hasReceivedStops = false

    private static let cacheKey         = "favouriteStops"
    private static let hasReceivedKey   = "hasReceivedFavouriteStops"

    override init()
    {
        super.init()

        loadCache()

        if WCSession.isSupported()
        {
            let session = WCSession.default

            session.delegate = self
            session.activate()
        }
    }

    // Use the latest list already delivered by the iPhone and, if the iPhone
    // is reachable right now, ask it for a fresh one too.
    //
    func requestUpdate()
    {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        guard session.activationState == .activated else { return }

        if let latest = Self.stops( from: session.receivedApplicationContext )
        {
            apply( latest )
        }

        guard session.isReachable else { return }

        session.sendMessage(
            [ "action": "getStops" ],
            replyHandler:
            {
                // @Sendable: WatchConnectivity calls this on a background
                // queue, so it mustn't inherit this method's main actor
                // isolation.
                //
                @Sendable reply in

                guard let latest = Self.stops( from: reply ) else { return }
                Task { @MainActor in self.apply( latest ) }
            },
            errorHandler: nil
        )
    }

    // MARK: - Private

    private func apply( _ newStops: [ FavouriteStop ] )
    {
        stops            = newStops
        hasReceivedStops = true

        if let data = try? JSONEncoder().encode( newStops )
        {
            UserDefaults.standard.set( data, forKey: Self.cacheKey       )
            UserDefaults.standard.set( true, forKey: Self.hasReceivedKey )
        }
    }

    private func loadCache()
    {
        let defaults = UserDefaults.standard

        if
            let data   = defaults.data( forKey: Self.cacheKey ),
            let cached = try? JSONDecoder().decode( [ FavouriteStop ].self, from: data )
        {
            stops = cached
        }

        hasReceivedStops = defaults.bool( forKey: Self.hasReceivedKey )
    }

    // Parse a payload from the iPhone. Returns 'nil' if it doesn't contain a
    // list of stops at all (e.g. an empty application context).
    //
    nonisolated private static func stops( from payload: [ String: Any ] ) -> [ FavouriteStop ]?
    {
        guard let list = payload[ "allStops" ] as? [ [ String: Any ] ] else { return nil }

        return list.compactMap
        {
            entry in

            guard let stopID = entry[ "stopID" ] as? String else { return nil }

            return FavouriteStop(
                stopID:          stopID,
                stopDescription: entry[ "stopDescription" ] as? String ?? stopID,
                preferred:       entry[ "preferred"       ] as? Bool   ?? false
            )
        }
    }
}

// MARK: - WCSessionDelegate
//
// WatchConnectivity calls these on a background queue. Anything that changes
// published state hops to the main actor.

extension FavouritesStore: WCSessionDelegate
{
    nonisolated func session(
        _                                 session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
                                            error: Error?
    )
    {
        if let error
        {
            NSLog( "Watch session activation failed: %@", error.localizedDescription )
            return
        }

        Task { @MainActor in self.requestUpdate() }
    }

    nonisolated func session(
        _                                       session: WCSession,
        didReceiveApplicationContext applicationContext: [ String: Any ]
    )
    {
        guard let latest = Self.stops( from: applicationContext ) else { return }
        Task { @MainActor in self.apply( latest ) }
    }
}
