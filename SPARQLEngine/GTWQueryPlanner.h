#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#import "GTWTree.h"
#import "GTWIRI.h"
#import "GTWQueryDataset.h"

@interface GTWQueryPlanner : NSObject<GTWQueryPlanner>

@property id<GTWLogger> logger;

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWQueryDataset>) dataset;
//- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWQueryDataset*) dataset optimize: (BOOL) opt;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWQueryDataset>) dataset optimize: (BOOL) opt;

@end
