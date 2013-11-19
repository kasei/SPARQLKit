#import "NSObject+NSDictionary_QueryBindings.h"
#import "SPARQLKit.h"

@implementation NSDictionary (NSDictionary_QueryBindings)

- (NSDictionary*) join: (NSDictionary*) result {
    NSMutableSet* mykeys    = [NSMutableSet setWithArray:[self allKeys]];
    NSSet* keys             = [NSSet setWithArray:[result allKeys]];
    [mykeys intersectSet:keys];
    for (NSString* key in mykeys) {
        id<GTWTerm> myterm  = self[key];
        id<GTWTerm> term    = result[key];
        if (![myterm isEqual:term]) {
            return nil;
        }
    }
    
    NSMutableDictionary* join   = [NSMutableDictionary dictionaryWithDictionary:self];
    [join addEntriesFromDictionary:result];
    return join;
}

- (id) copyWithCanonicalization {
//    NSLog(@"copying result dictionary with canonicalization: %@", self);
    NSMutableDictionary* copy   = [NSMutableDictionary dictionary];
    for (id key in self) {
        id value    = self[key];
        copy[key]   = ([value respondsToSelector:@selector(copyWithCanonicalization)]) ? [value copyWithCanonicalization] : [value copy];
    }
    return [copy copy];
}

@end
