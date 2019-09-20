//
//  BackgroundColourCalculator.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 18/08/19.
//  Copyright © 2019 Andrew Hodgkinson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackgroundColourCalculator : NSObject

+ ( UIColor * ) foregroundFromBackground: ( UIColor * ) background;

@end

NS_ASSUME_NONNULL_END
