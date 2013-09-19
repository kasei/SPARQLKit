#import "NSObject+NSDictionary_QueryBindings.h"
#import "GTWSPARQLEngine.h"

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

@end
