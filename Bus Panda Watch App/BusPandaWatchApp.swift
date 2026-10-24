//
//  BusPandaWatchApp.swift
//  Bus Panda Watch App
//
//  Entry point for the SwiftUI watch app. Shows the favourite stops sent
//  over by the iPhone app; choosing one shows its upcoming buses, which the
//  watch fetches for itself straight from Metlink.
//

import SwiftUI

@main
struct BusPandaWatchApp: App
{
    // Created at launch, so that the WatchConnectivity session is activated
    // straight away and any favourites waiting from the iPhone arrive.
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
