//
//  ShorteningLabel.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 2/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  A 'shortening label' is a subclass of UILabel that shortens its displayed
//  text by abbreviating or eliminating certain words. This is done "properly";
//  the available label width is compared to the plotted text width and passes
//  of shortening are applied if it's still too wide.
//
//  Shortening needs to be applied at the 'drawTextInRect:' stage of processing
//  but is obviously a relatively slow process, so the last label width for
//  which shortening was applied is remembered and it's only reapplied if that
//  width has altered since the last redraw call.
//
//  See also the StringShortener component used by the Watch app, which does
//  the same thing but using a more lightweight "maximum number of characters"
//  basis and shortens even more aggressively if need be, with a third pass
//  which removes vowels. We don't go that far on iOS, which has more display
//  space and can be told to shrink the font size if all else fails via the
//  standard UILabel properties.
//

#import "ShorteningLabel.h"
#import "Bus_Panda-Swift.h"

@interface ShorteningLabel()
@property ( weak, nonatomic ) NSString * originalText;
@property                     CGFloat    lastComputedWidth;
@end

@implementation ShorteningLabel

#pragma mark - Text truncation

// Returns YES if the given string would be truncated by this UILabel at full
// font size (or require font shrinking, which amounts to the same concept),
// else NO.
//
- ( BOOL ) willTruncateText: ( NSString * ) text
{
    BOOL   isTruncated = NO;
    CGRect labelSize   =
    [
        text boundingRectWithSize: CGSizeFromString( text )
                          options: NSStringDrawingUsesLineFragmentOrigin
                       attributes: @{ NSFontAttributeName: self.font }
                          context: nil
    ];

    if ( labelSize.size.width > self.bounds.size.width )
    {
        isTruncated = YES;
    }

    return isTruncated;
}

// Within a given string, uses a dictionary of case-insensitive but otherwise
// literal (no wildcards, regexps etc.) global search/replace string pairs and
// returns a new string with all replacements completed.
//
- ( NSString * ) replaceStringsFrom: ( NSString                              * ) from
                              using: ( NSDictionary <NSString *, NSString *> * ) dict
{
    NSString * newString = from;

    for ( NSString * search in dict )
    {
        NSString * replace = dict[ search ];

        newString = [ newString stringByReplacingOccurrencesOfString: search
                                                          withString: replace
                                                             options: NSCaseInsensitiveSearch
                                                               range: NSMakeRange( 0, [ newString length ] ) ];
    }

    return newString;
}

// Given an input string, returns a new string with some common words
// shortened - e.g. Street to St, At to @.
//
- ( NSString * ) shortenLightly: ( NSString * ) text
{
    NSDictionary * replaceData =
    @{
        @" Street":  @" St",
        @" Road":    @" Rd",
        @" Terrace": @" Tce",
        @" Place":   @" Plc",
        @" at ":     @" @ "
    };

    return [ self replaceStringsFrom: text using: replaceData ];
}

// Given an input string, returns a new string with some common but in context
// redundant words removed - e.g. Street, At, "-".
//
- ( NSString * ) shortenAggressively: ( NSString * ) text
{
    NSDictionary * replaceData =
    @{
        @" Street":  @"",
        @" Road":    @"",
        @" Terrace": @"",
        @" Place":   @"",
        @" at ":     @" ",
        @" - ":      @" ",
        @" near ":   @" "
    };

    return [ self replaceStringsFrom: text using: replaceData ];
}

#pragma mark - UILabel overrides

// A custom text setter which remembers the original string used for this
// label even though, upon drawing it, different text might get assigned.
//
- ( void ) setText: ( NSString * ) text
{
    [ super setText: text ];

    self.originalText      = text;
    self.lastComputedWidth = 0.0;
}

// A custom getter which returns the original text set by 'setText:', rather
// than whatever shortened version might actually be in use right now.
//
- ( NSString * ) text
{
    return self.originalText;
}

// If need be, apply shortening to the original string from 'setText:' and set
// a shortened version via the superclass; then ask the superclass to draw.
//
- ( void ) drawTextInRect: ( CGRect ) rect
{
    if ( [ [ NSUserDefaults standardUserDefaults ] boolForKey: @"shorten_names_preference" ] == YES )
    {
        if ( self.lastComputedWidth != self.bounds.size.width )
        {
            NSString * newText = self.originalText;

            if ( [ self willTruncateText: newText ] ) newText = [ self shortenLightly:      self.originalText ];
            if ( [ self willTruncateText: newText ] ) newText = [ self shortenAggressively: self.originalText ];

            [ super setText: newText ];

            self.lastComputedWidth = self.bounds.size.width;
        }
    }
    // ...else, someone else is assumed to have rebuilt their view with new
    // labels so that we don't carry on drawing with old shortened, or not-
    // shortened, label text - e.g. by using NSTableView '-reloadData'.

    [ super drawTextInRect: rect ];
}

@end
