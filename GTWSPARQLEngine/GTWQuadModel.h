#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWQuadModel : NSObject<GTWModel>

@property id<GTWQuadStore> store;

- (GTWQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store;

@end
