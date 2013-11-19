#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWModelBase.h>

@interface SPKTripleModel : GTWModelBase<GTWModel,GTWQueryPlanner>

@property NSMutableDictionary* graphs;
@property id<GTWLogger> logger;

- (SPKTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph;
- (void) addStore:(id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph;

@end
