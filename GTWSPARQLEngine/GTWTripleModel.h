#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWModelBase.h>

@interface GTWTripleModel : GTWModelBase<GTWModel>

@property NSMutableDictionary* graphs;
//@property GTWIRI* graph;
//@property id<GTWTripleStore> store;

- (GTWTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph;

@end
