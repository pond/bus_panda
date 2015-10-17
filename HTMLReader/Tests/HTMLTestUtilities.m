//  HTMLTestUtilities.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTestUtilities.h"

NSString * html5libTestPath(void)
{
    #define STRINGIFY_EXPAND(a) #a
    #define STRINGIFY(a) @STRINGIFY_EXPAND(a)
    return STRINGIFY(HTML5LIBTESTPATH);
}

BOOL ShouldRunTestsForParameterizedTestClass(Class class)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"

    NSString *scope = [defaults stringForKey:XCTestScopeKey];
    if ([scope isEqualToString:XCTestScopeAll] || [scope isEqualToString:XCTestScopeSelf]) {
        return YES;
    } else if ([scope isEqualToString:XCTestScopeNone]) {
        return NO;
    } else {
        NSArray *tests = [scope componentsSeparatedByString:@","];
        BOOL invertScope = [defaults boolForKey:@"XCTestInvertScope"];
        return [tests containsObject:NSStringFromClass(class)] != invertScope;
    }
    
    #pragma clang diagnostic pop
}
