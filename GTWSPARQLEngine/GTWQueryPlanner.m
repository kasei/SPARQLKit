#import "GTWQueryPlanner.h"
#import "GTWQuad.h"
#import "GTWSPARQLEngine.h"

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
    if (algebra.type == kAlgebraDistinct) {
        return [[GTWQueryPlan alloc] initWithType:kPlanDistinct arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraProject) {
        return [[GTWQueryPlan alloc] initWithType:kPlanProject value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraJoin) {
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraBGP) {
        return [self planBGP: algebra.arguments usingDataset: dataset];
    } else if (algebra.type == kAlgebraFilter) {
        return [[GTWQueryPlan alloc] initWithType:kPlanFilter value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraOrderBy) {
        list    = algebra.value;
        return [[GTWQueryPlan alloc] initWithType:kPlanOrder value: list arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kTreeTriple) {
        t   = algebra.value;
        defaultGraphs   = [dataset defaultGraphs];
        count   = [defaultGraphs count];
        if (count == 0) {
            return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
        } else if (count == 1) {
            return [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]] pointer:NULL];
        } else {
            id<GTWTree,GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]] pointer:NULL];
            NSInteger i;
            for (i = 1; i < count; i++) {
                plan    = [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[plan, [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[i]] pointer:NULL]]];
            }
            return plan;
        }
    } else {
        NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
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
        return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
    } else {
        plan   = [self queryPlanForAlgebra:triples[0] usingDataset:dataset];
        for (i = 1; i < [triples count]; i++) {
            id<GTWTree> triple  = triples[i];
            NSSet* projvars     = [triple annotationForKey:kProjectVariables];
            if (projvars) {
                NSLog(@"********* %@ projected for (%@)", triple, projvars);
            }
            
            
            id<GTWTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:triples[i] usingDataset:dataset];
            plan    = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[plan, quad]];
        }
    }
    return plan;
}

@end
