#import "GTWBlockEnumerator.h"

@implementation GTWBlockEnumerator

- (GTWBlockEnumerator*) initWithBlock: (GTWProducer) block {
    if (self = [self init]) {
        self.block  = block;
    }
    return self;
}

- (id)nextObject {
    return self.block();
}

@end
