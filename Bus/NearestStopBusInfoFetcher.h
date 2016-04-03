//
//  NearestStopBusInfoFetcher.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 1/04/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface NearestStopBusInfoFetcher : NSObject

- ( void ) beginWithWatchOSReplyHandler: ( nonnull void (^)( NSDictionary <NSString *, id> * _Nonnull ) ) replyHandler;

@end
