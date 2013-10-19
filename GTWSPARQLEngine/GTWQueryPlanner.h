#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWTree.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWDataset.h>

@interface GTWQueryPlanner : NSObject<GTWQueryPlanner>

@property id<GTWLogger> logger;
@property NSUInteger bnodeCounter;

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra withModel: (id<GTWModel>) model;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model;
//- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWDataset*) dataset optimize: (BOOL) opt;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize: (BOOL) opt;

@end
