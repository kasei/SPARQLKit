#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWModelBase.h>

@interface GTWTripleModel : GTWModelBase<GTWModel,GTWQueryPlanner>

@property NSMutableDictionary* graphs;
@property id<GTWLogger> logger;

- (GTWTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph;

@end
