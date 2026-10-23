//
//  BusesView.swift
//  Bus Panda Watch App
//
//  Upcoming buses at one stop, fetched directly from Metlink and refreshed
//  every 30 seconds while on screen (and on returning to the app).
//

import SwiftUI
import UIKit

struct BusesView: View
{
    let stop: FavouriteStop

    @Environment( \.scenePhase ) private var scenePhase

    @State private var services:  [ BusService ] = []
    @State private var loading                   = true
    @State private var errorText: String?        = nil

    // Same interval as the iPhone app's schedule view.
    //
    private static let refreshInterval: UInt64 = 30

    var body: some View
    {
        content
            .navigationTitle( stop.stopID )
            .task( id: stop.stopID ) { await refreshPeriodically() }
            .onChange( of: scenePhase )
            {
                phase in
                if phase == .active { Task { await load() } }
            }
    }

    @ViewBuilder
    private var content: some View
    {
        if loading && services.isEmpty
        {
            ProgressView()
        }
        else if let errorText, services.isEmpty
        {
            message( symbol: "exclamationmark.triangle", title: "Can't Get Bus Times", detail: errorText )
        }
        else if services.isEmpty
        {
            message( symbol: "bus", title: "No Buses", detail: "No services are currently scheduled." )
        }
        else
        {
            List( services ) { service in ServiceRow( service: service ) }
        }
    }

    private func message( symbol: String, title: String, detail: String ) -> some View
    {
        ScrollView
        {
            VStack( spacing: 8 )
            {
                Image( systemName: symbol )
                    .font( .title2 )
                    .foregroundStyle( .secondary )

                Text( title )
                    .font( .headline )

                Text( detail )
                    .font( .footnote )
                    .foregroundStyle( .secondary )
                    .multilineTextAlignment( .center )
            }
            .padding( .top )
        }
    }

    // Runs for as long as the view is on screen; SwiftUI cancels it when the
    // view goes away.
    //
    private func refreshPeriodically() async
    {
        while !Task.isCancelled
        {
            await load()
            try? await Task.sleep( nanoseconds: Self.refreshInterval * 1_000_000_000 )
        }
    }

    // Fetch bus times. On failure, keep showing any earlier results; only
    // show an error if there's nothing else to show.
    //
    private func load() async
    {
        do
        {
            let latest = try await BusTimesFetcher.services( forStop: stop.stopID )

            services  = latest
            errorText = nil
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            errorText = error.localizedDescription
        }

        loading = false
    }
}

private struct ServiceRow: View
{
    let service: BusService

    var body: some View
    {
        HStack( spacing: 8 )
        {
            Text( service.number )
                .font( .system( .body, design: .rounded ).weight( .bold ) )
                .minimumScaleFactor( 0.6 )
                .lineLimit( 1 )
                .frame( minWidth: 30 )
                .padding( .horizontal, 4 )
                .padding( .vertical,   2 )
                .foregroundColor( textColour )
                .background( RoundedRectangle( cornerRadius: 4 ).fill( Color( uiColor: badgeColour ) ) )

            VStack( alignment: .leading, spacing: 0 )
            {
                Text( service.destination )
                    .lineLimit( 1 )
                    .strikethrough( service.isCancelled )

                Text( service.when )
                    .font( .footnote.monospacedDigit() )
                    .foregroundStyle( .secondary )
            }
        }
    }

    private var badgeColour: UIColor
    {
        RouteColours.colourFromHexString( service.colourHex )
    }

    // Black or white text, whichever reads best on the badge colour (the same
    // rule as the iPhone app's BackgroundColourCalculator).
    //
    private var textColour: Color
    {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        badgeColour.getRed( &red, green: &green, blue: &blue, alpha: &alpha )

        let brightness = ( red * 299 + green * 587 + blue * 114 ) / 1000
        return brightness > 0.42 ? .black : .white
    }
}
