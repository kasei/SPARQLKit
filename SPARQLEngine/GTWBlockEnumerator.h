#import <Foundation/Foundation.h>

@interface GTWBlockEnumerator : NSEnumerator

typedef NSDictionary*(^GTWProducer)(void);

@property (copy) GTWProducer block;

- (GTWBlockEnumerator*) initWithBlock: (GTWProducer) block;

@end
