#import "GTWQueryPlanner.h"
#import "GTWQuad.h"
#import "SPARQLEngine.h"

@implementation GTWQueryPlanner

- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (GTWQueryDataset*) dataset {
    id<Triple> t;
    NSInteger count;
    NSArray* defaultGraphs;
    switch (algebra.type) {
        case ALGEBRA_PROJECT:
            return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        case ALGEBRA_BGP:
            return [self planBGP: algebra.arguments usingDataset: dataset];
        case TREE_TRIPLE:
            t   = algebra.arguments[0];
            defaultGraphs   = [dataset defaultGraphs];
            count   = [defaultGraphs count];
            if (count == 0) {
                return [[GTWTree alloc] initWithType:PLAN_EMPTY pointer:nil arguments:@[]];
            } else if (count == 1) {
                return [[GTWTree alloc] initWithType:TREE_QUAD pointer:nil arguments:@[[[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]]]];
            } else {
                GTWTree* plan   = [[GTWTree alloc] initWithType:TREE_QUAD pointer:nil arguments:@[[[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]]]];
                NSInteger i;
                for (i = 1; i < count; i++) {
                    plan    = [[GTWTree alloc] initWithType:PLAN_UNION pointer:nil arguments:@[plan, [[GTWTree alloc] initWithType:TREE_QUAD pointer:nil arguments:@[[[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[i]]]]]];
                }
                return plan;
            }
        default:
            NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
            break;
    }
    return nil;
}

- (GTWTree*) queryPlanForAlgebra: (GTWTree*) algebra {
    GTWQueryDataset* dataset    = [[GTWQueryDataset alloc] initDatasetWithDefaultGraphs:@[]];
    return [self queryPlanForAlgebra:algebra usingDataset:dataset];
}

- (GTWTree*) planBGP: (NSArray*) triples usingDataset: (GTWQueryDataset*) dataset {
    NSLog(@"planning BGP: %@\n", triples);
    NSArray* defaultGraphs   = [dataset defaultGraphs];
    NSInteger count   = [defaultGraphs count];
    NSInteger i;
    GTWTree* plan;
    if (count == 0) {
        return [[GTWTree alloc] initWithType:PLAN_EMPTY pointer:nil arguments:@[]];
    } else {
        plan   = [self queryPlanForAlgebra:triples[0] usingDataset:dataset];
        for (i = 1; i < [triples count]; i++) {
            GTWTree* quad    = [self queryPlanForAlgebra:triples[i] usingDataset:dataset];
            plan    = [[GTWTree alloc] initWithType:PLAN_NLJOIN pointer:NULL arguments:@[plan, quad]];
        }
    }
    return plan;
}

@end
