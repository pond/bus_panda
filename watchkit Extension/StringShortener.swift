//
//  StringShortener.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 1/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

import Foundation

class StringShortener
{
    var maxCharactersPerLine = 17

    // Given a String, split it at spaces into an array of words. For all words
    // more than two characters long, remove English vowels ("AEIOU"). Return
    // the result as a String by re-joining the words with spaces.
    //
    func removeVowels( _ str: String ) -> String
    {
        let words                = str.components( separatedBy: " " )
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

        return newWords.joined( separator: " " )
    }

    // Given a String ("from:"), replace words using a Dictionary ("using:")
    // of search (keys) and replace (values) strings, using case insensitive
    // searches. Returns a new String which is the result of the removals.
    //
    func replaceStrings( _ from: String, using: [ String: String ] ) -> String
    {
        var newString = from

        for ( search, replace ) in using
        {
            newString = newString.replacingOccurrences(
                of: search,
                with: replace,
                options:    .caseInsensitive,
                range:      nil
            )
        }

        return newString
    }

    // Given a String describing a bus stop, shorten or entirely remove various
    // common words (e.g. "Street" to "St", or " near " removed), possibly
    // removing vowels if need be, to if possible fit into a width defined by
    // the maxCharactersPerLine property (see top of file). Returns a new
    // String containing the result.
    //
    func shortenDescription( _ description: String ) -> String
    {
        var newDescription = description

        if ( newDescription.characters.count > maxCharactersPerLine )
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

        if ( newDescription.characters.count > maxCharactersPerLine )
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

        if ( newDescription.characters.count > maxCharactersPerLine )
        {
            // Again, if still too long, remove vowels.

            newDescription = removeVowels( newDescription )
        }

        return newDescription
    }
}
