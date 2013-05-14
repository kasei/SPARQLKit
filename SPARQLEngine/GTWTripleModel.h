#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#import "GTWIRI.h"

@interface GTWTripleModel : NSObject<GTWModel>

@property NSMutableDictionary* graphs;
//@property GTWIRI* graph;
//@property id<GTWTripleStore> store;

- (GTWTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph;

@end
