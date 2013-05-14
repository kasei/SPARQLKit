#import "GTWErrorLogger.h"

@implementation GTWErrorLogger

- (void) logData: (id) data forKey: (NSString*) key {
    NSLog(@"%@: %@\n", key, data);
}

@end
