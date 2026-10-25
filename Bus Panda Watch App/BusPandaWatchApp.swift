//
//  BusPandaWatchApp.swift
//  Bus Panda Watch App
//
//  Entrypoint for the SwiftUI Watch app. Shows favourite stops sent over by
//  the iPhone app. Tapping on one shows its arrivals schedule, fetched by the
//  Watch itself from Metlink..
//

import SwiftUI

@main
struct BusPandaWatchApp: App
{
    // Create at launch so that the WatchConnectivity session is activated
    // straight away - any favourites waiting to be delivered by the iPhone
    // will arrive.
    //
    @StateObject private var favourites = FavouritesStore()

    var body: some Scene
    {
        WindowGroup
        {
            StopsView()
                .environmentObject( favourites )
        }
    }
}
