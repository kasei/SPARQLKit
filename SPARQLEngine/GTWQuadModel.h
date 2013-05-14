#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"

@interface GTWQuadModel : NSObject<GTWModel>

@property id<GTWQuadStore> store;

- (GTWQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store;

@end
