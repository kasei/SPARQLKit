#import "SPKErrorLogger.h"

@implementation SPKErrorLogger

- (void) logData:(id) data forKey:(NSString*) key inDomain:(NSString*) domain {
    NSLog(@"%@: %@: %@\n", domain, key, data);
}

@end
