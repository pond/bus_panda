//
//  BackgroundColourCalculator.m
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 18/08/19.
//  Copyright © 2019 Andrew Hodgkinson. All rights reserved.
//

#import "BackgroundColourCalculator.h"

@implementation BackgroundColourCalculator

// https://stackoverflow.com/questions/19456288/text-color-based-on-background-image
// https://stackoverflow.com/questions/2509443/check-if-uicolor-is-dark-or-bright
//
+ ( UIColor * ) foregroundFromBackground: ( UIColor * ) background
{
    CGFloat red, green, blue, alpha;

    [ background getRed: &red green: &green blue: &blue alpha: &alpha ];

    float bgDelta = ((red * 299) + (green * 587) + (blue * 114)) / 1000;
    return (bgDelta > 0.42) ? [UIColor blackColor] : [UIColor whiteColor];
}

@end
