#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import "GTWTree.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWDataset.h>

@interface SPKQueryPlanner : NSObject<SPKQueryPlanner>

@property id<GTWLogger> logger;
@property NSUInteger bnodeCounter;
@property NSUInteger varID;
@property NSMutableDictionary* bnodeMap;

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model options: (NSDictionary*) options;

@end
