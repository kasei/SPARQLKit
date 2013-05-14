#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#import "GTWTree.h"
#import "GTWIRI.h"
#import "GTWQueryDataset.h"

@interface GTWQueryPlanner : NSObject

- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra;
- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWQueryDataset*) dataset;

@end
