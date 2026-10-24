//
//  BusTimes.swift
//  Bus Panda Watch App
//
//  Fetches the arrival schedule for a stop from the Metlink API. The Watch
//  watch doesn't need an iPhone to be nearby, though it uses the iPhone's
//  network connection when it is, or Wi-Fi / cellular otherwise.
//
//  This mirrors parsing in the iPhone app's BusInfoFetcher, simplified for
//  the watch - no 'Today'/'Tomorrow' sections.
//
//  TODO: Unify, probably via Swift conversion on the iPhone side.
//

import Foundation

// One upcoming service at a stop.
//
nonisolated struct BusService: Identifiable, Sendable
{
    let id:          Int    // Position in the list
    let number:      String // Route number, e.g. "1", "N3"
    let destination: String // Where it's going, or "Cancelled"
    let when:        String // "Due", "5 mins" or e.g. "7:45pm"
    let colourHex:   String // Six hex digits, e.g. "FF0000"
    let isCancelled: Bool
}

enum BusTimesError: LocalizedError
{
    case unreadableResponse

    var errorDescription: String?
    {
        "Bus times from Metlink could not be understood."
    }
}

enum BusTimesFetcher
{
    // Same key as the iPhone app (MAGIC in Constants.h).
    //
    // TODO: Unify, probably via Swift conversion on the iPhone side.
    //
    private static let apiKey = "iuoMNXQjzC1PjijgMjKkHhYWPb4ZES2UpaYfgsd0"

    // Watch screens are small! Don't list more arrivals than this.
    //
    static let maximumServices = 10

    private static let placeholderColour = "888888"

    // Fetch upcoming services for the given stop ID. Throws on network errors
    // or a response that can't be understood. An empty array means nothing
    // is currently scheduled.
    //
    static func services( forStop stopID: String ) async throws -> [ BusService ]
    {
        var components = URLComponents( string: "https://api.opendata.metlink.org.nz/v1/stop-predictions" )!
        components.queryItems = [ URLQueryItem( name: "stop_id", value: stopID ) ]

        var request = URLRequest( url: components.url! )
        request.setValue( "application/json", forHTTPHeaderField: "Accept"    )
        request.setValue( apiKey,             forHTTPHeaderField: "x-api-key" )

        let ( data, _ ) = try await URLSession.shared.data( for: request )

        guard
            let overview   = try? JSONSerialization.jsonObject( with: data ) as? [ String: Any ],
            let departures = overview[ "departures" ] as? [ [ String: Any ] ]
        else
        {
            throw BusTimesError.unreadableResponse
        }

        let routeColours = RouteColours.colours()
        var services     = [ BusService ]()

        for departure in departures
        {
            if services.count >= maximumServices { break }

            guard let number = trimmed( departure[ "service_id" ] ), !number.isEmpty else { continue }

            let status      = trimmed( departure[ "status" ] ) ?? ""
            let isCancelled = ( status == "cancelled" )
            let isRealTime  = !status.isEmpty

            var destination = trimmed( ( departure[ "destination" ] as? [ String: Any ] )?[ "name" ] ) ?? ""

            if destination.isEmpty { destination = "Route \( number )" }
            if isCancelled         { destination = "Cancelled"         }

            let colour = routeColours[ number.uppercased() ] as? String ?? placeholderColour

            services.append(
                BusService(
                    id:          services.count,
                    number:      number,
                    destination: destination,
                    when:        whenText( for: departure, isRealTime: isRealTime ),
                    colourHex:   colour,
                    isCancelled: isCancelled
                )
            )
        }

        return services
    }

    // MARK: - Private

    // As on the iPhone, prefer the real-time expected arrival, then expected
    // departure, then the timetabled ("aimed") arrival or departure. A
    // timetabled time is shown as a clock time; a real-time one as minutes
    // from now, rounding down so as to err on the side of being early.
    //
    private static func whenText( for departure: [ String: Any ], isRealTime: Bool ) -> String
    {
        let arrival   = departure[ "arrival"   ] as? [ String: Any ] ?? [:]
        let leaving   = departure[ "departure" ] as? [ String: Any ] ?? [:]
        var realTime  = isRealTime
        var timeText  = trimmed( arrival[ "expected" ] ) ?? ""

        if timeText.isEmpty
        {
            timeText = trimmed( leaving[ "expected" ] ) ?? ""
        }

        if timeText.isEmpty
        {
            realTime = false
            timeText = trimmed( arrival[ "aimed" ] ) ?? trimmed( leaving[ "aimed" ] ) ?? ""
        }

        guard let date = ISO8601DateFormatter().date( from: timeText ) else { return "—" }

        if realTime
        {
            let minutes = Int( max( 0, date.timeIntervalSinceNow ) / 60 )
            return minutes < 2 ? "Due" : "\( minutes ) mins"
        }

        let formatter = DateFormatter()

        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.timeZone   = TimeZone( identifier: "Pacific/Auckland" )
        formatter.dateFormat = "h:mma"
        formatter.amSymbol   = "am"
        formatter.pmSymbol   = "pm"

        return formatter.string( from: date )
    }

    private static func trimmed( _ value: Any? ) -> String?
    {
        guard let string = value as? String else { return nil }
        return string.trimmingCharacters( in: .whitespacesAndNewlines )
    }
}
