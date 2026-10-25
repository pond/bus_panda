//
//  StopsView.swift
//  Bus Panda Watch App
//
//  The watch app's main view - favourite stops sent by the iPhone app.
//

import SwiftUI

struct StopsView: View
{
    @EnvironmentObject private var favourites: FavouritesStore

    var body: some View
    {
        NavigationStack
        {
            Group
            {
                if favourites.stops.isEmpty
                {
                    emptyState
                }
                else
                {
                    List( favourites.stops )
                    {
                        stop in

                        NavigationLink( value: stop )
                        {
                            StopRow( stop: stop )
                        }
                    }
                }
            }
            .navigationTitle( "Bus Panda" )
            .navigationDestination( for: FavouriteStop.self )
            {
                stop in BusesView( stop: stop )
            }
        }
        .onAppear { favourites.requestUpdate() }
    }

    private var emptyState: some View
    {
        ScrollView
        {
            VStack( spacing: 8 )
            {
                Image( systemName: "star" )
                    .font( .title2 )
                    .foregroundStyle( .secondary )

                Text( "No Favourites" )
                    .font( .headline )

                Text(
                    favourites.hasReceivedStops
                    ? "Add favourite stops in Bus Panda on your iPhone."
                    : "Open Bus Panda on your iPhone to send your favourite stops here."
                )
                .font( .footnote )
                .foregroundStyle( .secondary )
                .multilineTextAlignment( .center )
            }
            .padding( .top )
        }
    }
}

private struct StopRow: View
{
    let stop: FavouriteStop

    var body: some View
    {
        VStack( alignment: .leading, spacing: 2 )
        {
            Text( shortDescription )
                .lineLimit( 2 )

            HStack( spacing: 4 )
            {
                if stop.preferred
                {
                    Image( systemName: "pin.fill" )
                        .imageScale( .small )
                        .foregroundStyle( .tint ) // (use AccentColor from Assets)
                }

                Text( stop.stopID )
                    .font( .footnote.monospacedDigit() )
                    .foregroundStyle( .secondary )
            }
        }
        .padding( .vertical, 2 )
    }

    // Shorten a description via StringShortner.
    //
    private var shortDescription: String
    {
        let shortener = StringShortener()
        shortener.maxCharactersPerLine = 17
        return shortener.shortenDescription( stop.stopDescription )
    }
}
