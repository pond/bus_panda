//
//  InterfaceController.swift
//  watchkit Extension
//
//  Created by Andrew Hodgkinson on 11/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation

let MAX_CHARACTERS_PER_LINE = 17

@available( iOS 8.2, * )
class StopsInterfaceController: WKInterfaceController
{
    // ========================================================================
    // MARK: - Lifecycle
    // ========================================================================

    override func awakeWithContext( context: AnyObject? )
    {
        super.awakeWithContext( context )
        
        // TODO: Configure interface objects here.
    }

    // This method is called when watch view controller is about to be
    // visible to user
    //
    override func willActivate()
    {
        super.willActivate()
    }

    // This method is called when watch view controller is no longer visible
    //
    override func didDeactivate()
    {
        super.didDeactivate()
    }

    // ========================================================================
    // MARK: - WKInterfaceTable selection and updates
    // ========================================================================

    @IBOutlet var stopsTable: WKInterfaceTable!

    // Handle table selections. Showing the realtime information for the buses
    // at the selected stop requires the iOS application, so this must be
    // reachable.
    //
    override func table( table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int )
    {
        let controller = stopsTable.rowControllerAtIndex( rowIndex ) as? StopsRowController
        pushControllerWithName( "Buses", context: controller?.stopInfo )
    }

    // Update the WKInterfaceTable list of stops based on the given NSArray
    // of dictionaries. Each is expected to have "stopID" (four digit/letter
    // stop ID) and "stopDescription" (human-readable description). A human
    // parseable decimation algorithm tries to reduce the description length
    // to better fit the narrow watch display; e.g. "Street" might get
    // shortened to "St", or even removed entirely (e.g. "Victoria Street at
    // Ghuznee Street" might shorten right down to "Victoria Ghuznee"). For
    // the most aggressive last attempt, vowels are removed.
    //
    func updateStops( allStops: NSArray? )
    {
        let stops = ( allStops == nil ) ? NSArray() : allStops!

        stopsTable.setNumberOfRows( stops.count, withRowType: "StopsRow" )

        for index in 0 ..< stopsTable.numberOfRows
        {
            let controller = stopsTable.rowControllerAtIndex( index ) as? StopsRowController
            let dictionary = stops[ index ] as! NSDictionary

            let stopID          = dictionary[ "stopID"          ] as! String
            var stopDescription = dictionary[ "stopDescription" ] as! String

            stopDescription = shortenDescription( stopDescription )

            let stopInfo: [ String: String ] =
            [
                "stopID":          stopID,
                "stopDescription": stopDescription
            ]

            controller?.stopInfo = stopInfo
        }
    }

    // ========================================================================
    // MARK: - String processing
    // ========================================================================

    // Given a String, split it at spaces into an array of words. For all words
    // more than two characters long, remove English vowels ("AEIOU"). Return
    // the result as a String by re-joining the words with spaces.
    //
    func removeVowels( str: String ) -> String
    {
        let words                = str.componentsSeparatedByString( " " )
        var newWords: [ String ] = []

        for word in words
        {
            if ( word.characters.count > 2 )
            {
                newWords.append(
                    String(
                        word.characters.filter
                        {
                            !"aeiou".characters.contains( $0 )
                        }
                    )
                )
            }
            else
            {
                newWords.append( word )
            }
        }

        return newWords.joinWithSeparator( " " )
    }

    // Given a String ("from:"), replace words using a Dictionary ("using:")
    // of search (keys) and replace (values) strings, using case insensitive
    // searches. Returns a new String which is the result of the removals.
    //
    func replaceStrings( from: String, using: [ String: String ] ) -> String
    {
        var newString = from

        for ( search, replace ) in using
        {
            newString = newString.stringByReplacingOccurrencesOfString(
                search,
                withString: replace,
                options:    .CaseInsensitiveSearch,
                range:      nil
            )
        }

        return newString
    }

    // Given a String describing a bus stop, shorten or entirely remove various
    // common words (e.g. "Street" to "St", or " near " removed), possibly
    // removing vowels if need be, to if possible fit into a width defined by
    // the MAX_CHARACTERS_PER_LINE constant (see top of file). Returns a new
    // String containing the result.
    //
    func shortenDescription( description: String ) -> String
    {
        var newDescription = description

        if ( newDescription.characters.count > MAX_CHARACTERS_PER_LINE )
        {
            // Common word abbreviations

            newDescription = replaceStrings(
                newDescription,
                using: [
                    " Street":  " St",
                    " Road":    " Rd",
                    " Terrace": " Tce",
                    " Place":   " Plc",
                    " at ":     " @ "
                ]
            )
        }

        if ( newDescription.characters.count > MAX_CHARACTERS_PER_LINE )
        {
            // If it's still too long, start again but be much more aggressive
            // by removing, not just abbreivating, redundant words.

            newDescription = replaceStrings(
                description,
                using: [
                    " Street":  "",
                    " Road":    "",
                    " Terrace": "",
                    " Place":   "",
                    " at ":     " ",
                    " - ":      " ",
                    " near ":   " "
                ]
            )
        }

        if ( newDescription.characters.count > MAX_CHARACTERS_PER_LINE )
        {
            // Again, if still too long, remove vowels.

            newDescription = removeVowels( newDescription )
        }

        return newDescription
    }
}
