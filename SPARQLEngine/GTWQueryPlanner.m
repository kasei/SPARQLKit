#import "GTWQueryPlanner.h"
#import "GTWQuad.h"
#import "SPARQLEngine.h"

@implementation GTWQueryPlanner

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWQueryDataset>) dataset optimize: (BOOL) opt {
    id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset];
    if (opt) {
        [plan computeScopeVariables];
    }
    return plan;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWQueryDataset>) dataset {
    id<GTWTriple> t;
    NSInteger count;
    NSArray* defaultGraphs;
    NSArray* list;
    switch (algebra.type) {
        case ALGEBRA_DISTINCT:
            return [[GTWQueryPlan alloc] initWithType:PLAN_DISTINCT arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
        case ALGEBRA_PROJECT:
            return [[GTWQueryPlan alloc] initWithType:PLAN_PROJECT value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
        case ALGEBRA_JOIN:
            return [[GTWQueryPlan alloc] initWithType:PLAN_NLJOIN arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset]]];
        case ALGEBRA_BGP:
            return [self planBGP: algebra.arguments usingDataset: dataset];
        case ALGEBRA_FILTER:
            return [[GTWQueryPlan alloc] initWithType:PLAN_FILTER value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
        case ALGEBRA_ORDERBY:
            list    = algebra.value;
            return [[GTWQueryPlan alloc] initWithType:PLAN_ORDER value: list arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
        case TREE_TRIPLE:
            t   = algebra.value;
            defaultGraphs   = [dataset defaultGraphs];
            count   = [defaultGraphs count];
            if (count == 0) {
                return [[GTWQueryPlan alloc] initWithType:PLAN_EMPTY arguments:@[]];
            } else if (count == 1) {
                return [[GTWQueryPlan alloc] initLeafWithType:TREE_QUAD value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]] pointer:NULL];
            } else {
                id<GTWTree,GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initLeafWithType:TREE_QUAD value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]] pointer:NULL];
                NSInteger i;
                for (i = 1; i < count; i++) {
                    plan    = [[GTWQueryPlan alloc] initWithType:PLAN_UNION arguments:@[plan, [[GTWQueryPlan alloc] initLeafWithType:TREE_QUAD value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[i]] pointer:NULL]]];
                }
                return plan;
            }
        default:
            NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
            break;
    }
    return nil;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra {
    GTWQueryDataset* dataset    = [[GTWQueryDataset alloc] initDatasetWithDefaultGraphs:@[]];
    return [self queryPlanForAlgebra:algebra usingDataset:dataset];
}

- (id<GTWTree,GTWQueryPlan>) planBGP: (NSArray*) triples usingDataset: (id<GTWQueryDataset>) dataset {
//    NSLog(@"planning BGP: %@\n", triples);
    NSArray* defaultGraphs   = [dataset defaultGraphs];
    NSInteger count   = [defaultGraphs count];
    NSInteger i;
    id<GTWTree,GTWQueryPlan> plan;
    if (count == 0) {
        return [[GTWQueryPlan alloc] initWithType:PLAN_EMPTY arguments:@[]];
    } else {
        plan   = [self queryPlanForAlgebra:triples[0] usingDataset:dataset];
        for (i = 1; i < [triples count]; i++) {
            id<GTWTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:triples[i] usingDataset:dataset];
            plan    = [[GTWQueryPlan alloc] initWithType:PLAN_NLJOIN arguments:@[plan, quad]];
        }
    }
    return plan;
}

@end
