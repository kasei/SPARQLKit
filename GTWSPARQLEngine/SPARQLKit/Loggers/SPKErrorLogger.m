#import "SPKErrorLogger.h"

@implementation SPKErrorLogger

- (void) logData: (id) data forKey: (NSString*) key {
    NSLog(@"%@: %@\n", key, data);
}

@end
