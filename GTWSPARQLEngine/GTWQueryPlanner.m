#import "GTWQueryPlanner.h"
#import <GTWSWBase/GTWQuad.h>
#import "GTWSPARQLEngine.h"

@implementation GTWQueryPlanner

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset optimize: (BOOL) opt {
    id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset];
    if (opt) {
        [plan computeScopeVariables];
    }
    return plan;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset {
    if (algebra == nil) {
        NSLog(@"trying to plan nil algebra");
        return nil;
    }
    id<GTWTriple> t;
    NSInteger count;
    NSArray* defaultGraphs;
    NSArray* list;
    
    // TODO: if any of these recursive calls fails and returns nil, we need to propogate that nil up the stack instead of having it crash when an array atempts to add the nil value
    if (algebra.type == kAlgebraDistinct) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"DISTINCT must be 1-ary");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanDistinct arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraAsk) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"ASK must be 1-ary");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanAsk value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraGraph) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"GRAPH must be 1-ary");
            return nil;
        }
        id<GTWTree> graphtree   = algebra.value;
        id<GTWTerm> graph       = graphtree.value;
        GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
        return [[GTWQueryPlan alloc] initWithType:kPlanGraph value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset]]];
    } else if (algebra.type == kAlgebraUnion) {
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset];
        if (!(lhs && rhs)) {
            NSLog(@"Failed to plan both sides of UNION");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[lhs, rhs]];
    } else if (algebra.type == kAlgebraProject) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"PROJECT must be 1-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        if (!lhs) {
            NSLog(@"Failed to plan PROJECT sub-plan");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanProject value: algebra.value arguments:@[lhs]];
    } else if (algebra.type == kAlgebraJoin || algebra.type == kTreeList) {
        if ([algebra.arguments count] == 0) {
            return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
        } else if ([algebra.arguments count] == 1) {
            return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        } else if ([algebra.arguments count] == 2) {
            id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
            id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of JOIN");
                return nil;
            }
            return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
        } else {
            id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
            id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of %lu-way JOIN", [algebra.arguments count]);
                return nil;
            }
            id<GTWTree, GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
            for (NSUInteger i = 2; i < [algebra.arguments count]; i++) {
                id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[i] usingDataset:dataset];
                if (!rhs) {
                    NSLog(@"Failed to plan JOIN branch");
                    return nil;
                }
                plan    = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[plan, rhs]];
            }
            return plan;
        }
    } else if (algebra.type == kAlgebraMinus) {
        NSLog(@"MINUS must be 2-ary");
        if ([algebra.arguments count] != 2)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin value: @"minus" arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraLeftJoin) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"LEFT JOIN must be 2-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset];
        if (!lhs || !rhs) {
            NSLog(@"Failed to plan both sides of LEFT JOIN");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin value: @"left" arguments:@[lhs, rhs]];
    } else if (algebra.type == kAlgebraBGP) {
        return [self planBGP: algebra.arguments usingDataset: dataset];
    } else if (algebra.type == kAlgebraFilter) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"FILTER must be 1-ary");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanFilter value: algebra.value arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset]]];
    } else if (algebra.type == kAlgebraExtend) {
        if ([algebra.arguments count] > 1) {
            NSLog(@"EXTEND must be 0- or 1-ary");
            NSLog(@"Extend: %@", algebra);
            return nil;
        }
        id<GTWTree> pat = ([algebra.arguments count]) ? algebra.arguments[0] : nil;
        if (pat) {
            id<GTWTree,GTWQueryPlan> p   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
            if (!p)
                return nil;
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend value: algebra.value arguments:@[p]];
        } else {
            id<GTWQueryPlan> empty    = [[GTWQueryPlan alloc] initLeafWithType:kPlanEmpty value:nil pointer:NULL];
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend value: algebra.value arguments:@[empty]];
        }
    } else if (algebra.type == kAlgebraSlice) {
        id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset];
        id<GTWTree> offset      = algebra.arguments[1];
        id<GTWTree> limit       = algebra.arguments[2];
        return [[GTWQueryPlan alloc] initWithType:kPlanSlice arguments:@[plan, offset, limit]];
    } else if (algebra.type == kAlgebraOrderBy) {
        if ([algebra.arguments count] != 1)
            return nil;
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
    } else if (algebra.type == kTreeResultSet) {
        return (id<GTWTree, GTWQueryPlan>) algebra;
    } else {
        NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
    }
    
    NSLog(@"returning nil query plan");
    return nil;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra {
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[]];
    return [self queryPlanForAlgebra:algebra usingDataset:dataset];
}

- (id<GTWTree,GTWQueryPlan>) planBGP: (NSArray*) triples usingDataset: (id<GTWDataset>) dataset {
//    NSLog(@"planning BGP: %@\n", triples);
    NSArray* defaultGraphs   = [dataset defaultGraphs];
    NSInteger graphCount   = [defaultGraphs count];
    NSInteger i;
    id<GTWTree,GTWQueryPlan> plan;
    if (graphCount == 0) {
        return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
    } else if ([triples count] == 0) {
        return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
    } else {
        plan   = [self queryPlanForAlgebra:triples[0] usingDataset:dataset];
        for (i = 1; i < [triples count]; i++) {
            id<GTWTree> triple  = triples[i];
            NSSet* projvars     = [triple annotationForKey:kProjectVariables];
            id<GTWTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:triples[i] usingDataset:dataset];
            plan    = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[plan, quad]];
        }
    }
    return plan;
}

@end
