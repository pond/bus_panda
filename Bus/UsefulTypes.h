//
//  UsefulTypes.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 13/12/15.
//  Copyright © 2015 Andrew Hodgkinson. All rights reserved.
//

#ifndef UsefulTypes_h
#define UsefulTypes_h

// Clean up nesting in code inside methods that make HTTP requests by assigning
// the URL competion handler block to a strongly typed variable.

typedef void ( ^ URLRequestCompletionHandler )( NSData        * data,
                                                NSURLResponse * response,
                                                NSError       * error);

#endif /* UsefulTypes_h */
