#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWTree.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWDataset.h>

@interface GTWQueryPlanner : NSObject<GTWQueryPlanner>

@property id<GTWLogger> logger;

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset;
//- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWDataset*) dataset optimize: (BOOL) opt;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset optimize: (BOOL) opt;

@end
