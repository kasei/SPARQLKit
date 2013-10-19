#import "GTWQueryPlanner.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>
#import "GTWSPARQLEngine.h"

@implementation GTWQueryPlanner

- (GTWQueryPlanner*) init {
    if (self = [super init]) {
        self.bnodeCounter   = 0;
    }
    return self;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize: (BOOL) opt {
    id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
    if (opt) {
        [plan computeScopeVariables];
    }
    return plan;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
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
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanDistinct arguments:@[plan]];
    } else if (algebra.type == kAlgebraAsk) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"ASK must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanAsk value: algebra.value arguments:@[plan]];
    } else if (algebra.type == kAlgebraGroup) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"Group must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanGroup value: algebra.value arguments:@[plan]];
    } else if (algebra.type == kAlgebraGraph) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"GRAPH must be 1-ary");
            return nil;
        }
        id<GTWTree> graphtree   = algebra.value;
        id<GTWTerm> graph       = graphtree.value;
        if ([graph isKindOfClass:[GTWIRI class]]) {
            GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
            id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model];
            if (!plan)
                return nil;
            return [[GTWQueryPlan alloc] initWithType:kPlanGraph value: algebra.value arguments:@[plan]];
        } else {
            NSError* error  = nil;
            NSArray* graphs = [dataset availableGraphsFromModel:model];
            
            id<GTWTree,GTWQueryPlan> gplan     = nil;
            for (id<GTWTerm> g in graphs) {
                GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[g]];
                id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model];
                if (!plan)
                    return nil;
                
                GTWTree* list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[
                                                                                      [[GTWTree alloc] initWithType:kTreeNode value:g arguments:@[]],
                                                                                      graphtree,
                                                                                      ]];
                id<GTWTree, GTWQueryPlan> extend    = (id<GTWTree, GTWQueryPlan>) [[GTWTree alloc] initWithType:kPlanExtend value:list arguments:@[plan]];
                if (gplan) {
                    gplan   = [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[gplan, extend]];
                } else {
                    gplan   = extend;
                }
            }
            return gplan;
        }
    } else if (algebra.type == kAlgebraUnion) {
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
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
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!lhs) {
            NSLog(@"Failed to plan PROJECT sub-plan");
            return nil;
        }
        // TODO: need to convert kAlgebraExtend in algebra.value[] to kPlanExtend
        return [[GTWQueryPlan alloc] initWithType:kPlanProject value: algebra.value arguments:@[lhs]];
    } else if (algebra.type == kAlgebraJoin || algebra.type == kTreeList) {
        if ([algebra.arguments count] == 0) {
            return [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
        } else if ([algebra.arguments count] == 1) {
            return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        } else if ([algebra.arguments count] == 2) {
            id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
            id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of JOIN");
                return nil;
            }
            return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
        } else {
            id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
            id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of %lu-way JOIN", [algebra.arguments count]);
                return nil;
            }
            id<GTWTree, GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
            for (NSUInteger i = 2; i < [algebra.arguments count]; i++) {
                id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[i] usingDataset:dataset withModel:model];
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
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin value: @"minus" arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model]]];
    } else if (algebra.type == kAlgebraLeftJoin) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"LEFT JOIN must be 2-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
        if (!lhs || !rhs) {
            NSLog(@"Failed to plan both sides of LEFT JOIN");
            return nil;
        }
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin value: @"left" arguments:@[lhs, rhs]];
    } else if (algebra.type == kAlgebraBGP) {
        return [self planBGP: algebra.arguments usingDataset: dataset withModel:model];
    } else if (algebra.type == kAlgebraFilter) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"FILTER must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanFilter value: algebra.value arguments:@[plan]];
    } else if (algebra.type == kAlgebraExtend) {
        if ([algebra.arguments count] > 1) {
            NSLog(@"EXTEND must be 0- or 1-ary");
            NSLog(@"Extend: %@", algebra);
            return nil;
        }
        id<GTWTree> pat = ([algebra.arguments count]) ? algebra.arguments[0] : nil;
        if (pat) {
            id<GTWTree,GTWQueryPlan> p   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
            if (!p)
                return nil;
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend value: algebra.value arguments:@[p]];
        } else {
            id<GTWQueryPlan> empty    = [[GTWQueryPlan alloc] initLeafWithType:kPlanEmpty value:nil pointer:NULL];
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend value: algebra.value arguments:@[empty]];
        }
    } else if (algebra.type == kAlgebraSlice) {
        id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        id<GTWTree> offset      = algebra.arguments[1];
        id<GTWTree> limit       = algebra.arguments[2];
        return [[GTWQueryPlan alloc] initWithType:kPlanSlice arguments:@[plan, offset, limit]];
    } else if (algebra.type == kAlgebraOrderBy) {
        if ([algebra.arguments count] != 1)
            return nil;
        list    = algebra.value;
        
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        
        return [[GTWQueryPlan alloc] initWithType:kPlanOrder value: list arguments:@[plan]];
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
    } else if (algebra.type == kTreePath) {
        return [self queryPlanForPath:algebra usingDataset:dataset withModel:model];
    } else if (algebra.type == kTreeResultSet) {
        return (id<GTWTree, GTWQueryPlan>) algebra;
    } else {
        NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
    }
    
    NSLog(@"returning nil query plan");
    return nil;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForPath: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
    id<GTWTree> s       = algebra.arguments[0];
    id<GTWTree> path    = algebra.arguments[1];
    id<GTWTree> o       = algebra.arguments[2];
    
    if (path.type == kPathSequence) {
        GTWVariable* b = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@"qp__%lu", self.bnodeCounter++]];
        id<GTWTree> blank   = [[GTWTree alloc] initWithType:kTreeNode value:b arguments:nil];
        id<GTWTree> first   = path.arguments[0];
        id<GTWTree> rest    = path.arguments[1];
        id<GTWTree> lhsPath = [[GTWTree alloc] initWithType:kTreePath arguments:@[s, first, blank]];
        id<GTWTree> rhsPath = [[GTWTree alloc] initWithType:kTreePath arguments:@[blank, rest, o]];
        id<GTWTree, GTWQueryPlan> lhs = [self queryPlanForPath:lhsPath usingDataset:dataset withModel:model];
        id<GTWTree, GTWQueryPlan> rhs = [self queryPlanForPath:rhsPath usingDataset:dataset withModel:model];
        if (!(lhs && rhs))
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
    } else if (path.type == kPathInverse) {
        id<GTWTree> p   = [[GTWTree alloc] initWithType:kTreePath arguments:@[o, path.arguments[0], s]];
        return [self queryPlanForPath:p usingDataset:dataset withModel:model];
    } else if (path.type == kTreeNode) {
        id<GTWTerm> subj    = s.value;
        id<GTWTerm> pred    = path.value;
        id<GTWTerm> obj     = o.value;
        GTWTriple* t        = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:obj];
        id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreeTriple value: t arguments:nil];
        return [self queryPlanForAlgebra:triple usingDataset:dataset withModel:model];
    } else {
        NSLog(@"Cannot plan property path %@", algebra);
        return nil;
    }
    return nil;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (GTWTree*) algebra withModel: (id<GTWModel>) model {
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[]];
    return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
}

- (id<GTWTree,GTWQueryPlan>) planBGP: (NSArray*) triples usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
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
        plan   = [self queryPlanForAlgebra:triples[0] usingDataset:dataset withModel:model];
        for (i = 1; i < [triples count]; i++) {
            id<GTWTree> triple  = triples[i];
            NSSet* projvars     = [triple annotationForKey:kProjectVariables];
            id<GTWTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:triples[i] usingDataset:dataset withModel:model];
            plan    = [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[plan, quad]];
        }
    }
    return plan;
}

@end
