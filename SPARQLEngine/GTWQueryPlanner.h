#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#import "GTWTree.h"
#import "GTWIRI.h"
#import "GTWQueryDataset.h"

@interface GTWQueryPlanner : NSObject<GTWQueryPlanner>

- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra;
- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWQueryDataset*) dataset;
- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWQueryDataset*) dataset optimize: (BOOL) opt;

@end
