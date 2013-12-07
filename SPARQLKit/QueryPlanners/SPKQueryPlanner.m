#import "SPKQueryPlanner.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import "SPARQLKit.h"

@implementation SPKQueryPlanner

- (SPKQueryPlanner*) init {
    if (self = [super init]) {
        self.bnodeCounter   = 0;
        self.varID          = 0;
        self.bnodeMap       = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id<SPKTree,GTWQueryPlan>) planQuad:(id<GTWQuad>)q usingDataset:(id<GTWDataset>)dataset withModel:(id<GTWModel>)model optimize:(BOOL)optFlag options:(NSDictionary*)options {
//    NSLog(@"Planning quad with dataset: %@", dataset);
    if (dataset.availabilityType == GTWRestrictedDataset) {
//        NSLog(@"Restricted dataset");
        // TODO: Need to restrict quad matching to restricted dataset
        NSMutableArray* graphs = [[dataset availableGraphsFromModel:model] mutableCopy];
        [graphs addObjectsFromArray:[dataset defaultGraphs]];
        
        id<GTWTerm> g    = q.graph;
        if ([g isKindOfClass:[GTWVariable class]]) {
//            NSLog(@"Quad has a variable graph %@", g);
            id<SPKTree,GTWQueryPlan> plan   = [[SPKQueryPlan alloc] initLeafWithType:kTreeQuad value: q];
            
            id<SPKTree> tn      = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            NSMutableArray* graphTrees  = [NSMutableArray array];
            for (id<GTWIRI> graph in graphs) {
                id<SPKTree> tree    = [[SPKTree alloc] initWithType:kTreeNode value:graph arguments:nil];
                [graphTrees addObject:tree];
            }
            id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:graphTrees];
            id<SPKTree> expr    = [[SPKTree alloc] initWithType:kExprIn arguments:@[tn, list]];
            id<SPKTree> algebra = [[SPKTree alloc] initWithType:kAlgebraFilter treeValue:expr arguments:@[plan]];
            return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
        } else {
//            NSLog(@"Quad has an IRI graph %@", g);
            NSSet* graphsSet    = [NSSet setWithArray:graphs];
//            NSLog(@"-> graphs from dataset: %@", graphsSet);
            
            if ([graphsSet containsObject:g]) {
                return [[SPKQueryPlan alloc] initLeafWithType:kTreeQuad value: q];
            } else {
                return [[SPKQueryPlan alloc] initWithType:kPlanEmpty arguments:nil];
            }
        }
        
//        NSLog(@"Need to restrict quad matching to restricted dataset");
    } else {
        return [[SPKQueryPlan alloc] initLeafWithType:kTreeQuad value: q];
    }
}

- (NSArray*) statementsForTemplateAlgebra: (id<SPKTree>) algebra {
    if ([algebra.type isEqual:kTreeList] || [algebra.type isEqual:kAlgebraBGP]) {
        NSMutableArray* triples = [NSMutableArray array];
        for (id<SPKTree> tree in algebra.arguments) {
            NSArray* t  = [self statementsForTemplateAlgebra:tree];
            if (t) {
                [triples addObjectsFromArray:t];
            }
        }
        return triples;
    } else if ([algebra.type isEqual:kTreeTriple]) {
        return @[ algebra.value ];
    } else if ([algebra.type isEqual:kAlgebraProject]) {
        id<SPKTree> tree    = algebra.arguments[0];
        return [self statementsForTemplateAlgebra:tree];
    } else {
        NSLog(@"don't know how to extract triples from algebra: %@", algebra);
        return nil;
    }
}

- (NSSet*) inScopeVariablesForUnionPlan: (id<SPKTree>) plan {
    NSMutableArray* plans  = [plan.arguments mutableCopy];
    SPKQueryPlan* empty = [[SPKQueryPlan alloc] initWithType:kPlanEmpty arguments:nil];
    [plans removeObject:empty];
    if ([plans count] == 0) {
        return [NSSet set];
    } else if ([plans count] == 1) {
        id<SPKTree> plan    = plans[0];
        NSSet* vars = [plan inScopeVariables];
        return vars;
    } else {
        id<SPKTree> plan    = plans[0];
        NSMutableSet* vars  = [[plan inScopeVariables] mutableCopy];
        NSUInteger count    = [plans count];
        for (NSUInteger i = 1; i < count; i++) {
            NSSet* rhsVars    = [plans[i] inScopeVariables];
            [vars intersectSet: rhsVars];
        }
        return vars;
    }
}

- (id<SPKTree,GTWQueryPlan>) joinPlanForPlans: (id<SPKTree>) lhs and: (id<SPKTree>) rhs {
    NSSet* lhsVars  = nil;
    NSSet* rhsVars  = nil;
    
    if ([lhs.type isEqual: kTreeQuad] && [rhs.type isEqual: kPlanHashJoin]) {
        id<SPKTree> temp    = lhs;
        lhs                 = rhs;
        rhs                 = temp;
//    } else if ([lhs.type isEqual:kTreeQuad] && [rhs.type isEqual:kTreeQuad]) {
//        if ([[lhs inScopeVariables] count] < [[rhs inScopeVariables] count]) {
//            id<SPKTree> temp    = lhs;
//            lhs                 = rhs;
//            rhs                 = temp;
//        }
    }
    
    if ([lhs.type isEqual:kTreeQuad] || [lhs.type isEqual:kPlanHashJoin] || [lhs.treeTypeName isEqualToString:@"PlanCustom"]) {
        lhsVars   = [lhs inScopeVariables];
    } else if ([lhs.type isEqual:kPlanUnion]) {
        lhsVars = [self inScopeVariablesForUnionPlan:lhs];
    }
    if ([rhs.type isEqual:kTreeQuad] || [rhs.type isEqual:kPlanHashJoin] || [rhs.treeTypeName isEqualToString:@"PlanCustom"]) {
        rhsVars   = [rhs inScopeVariables];
    } else if ([rhs.type isEqual:kPlanUnion]) {
        rhsVars = [self inScopeVariablesForUnionPlan:rhs];
    }
    if (lhsVars && rhsVars) {
        NSMutableSet* joinVars = [NSMutableSet setWithSet:lhsVars];
        [joinVars intersectSet:rhsVars];
        if ([joinVars count]) {
            return [[SPKQueryPlan alloc] initWithType:kPlanHashJoin value:joinVars arguments:@[lhs, rhs]];
        }
    }
//    NSLog(@"HashJoin not available for:\n%@\n%@", lhs, rhs);
//    NSLog(@"Join vars: %@ %@", lhsVars, rhsVars);
    return [[SPKQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
}

- (id<SPKTree>) replaceBlanksWithVariables: (id<SPKTree>) algebra {
    NSSet* blanks   = [algebra referencedBlanks];
    if ([blanks count]) {
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (id<GTWTerm> b in blanks) {
            NSUInteger vid  = ++(self.varID);
            id<GTWTerm> v   = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".b%lu", vid]];
            mapping[b]      = v;
        }
        return [algebra copyReplacingValues:mapping];
    }
    return algebra;
}

- (id<SPKTree>) replaceVariablesWithBlanks: (id<SPKTree>) algebra {
    NSSet* vars   = [algebra inScopeVariables];
    if ([vars count]) {
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (id<GTWTerm> v in vars) {
            if ([v.value hasPrefix:@".b"]) {
                id<GTWTerm> b   = [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"b%@", [v.value substringFromIndex:2]]];
                mapping[v]      = b;
            }
        }
        return [algebra copyReplacingValues:mapping];
    }
    return algebra;
}

- (id<SPKTree,GTWQueryPlan>) queryPlanForAlgebra: (id<SPKTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize:(BOOL)optFlag options: (NSDictionary*) options {
    algebra = [self replaceBlanksWithVariables:algebra];
    BOOL customPlanning = optFlag;
    if (customPlanning && [model conformsToProtocol:@protocol(SPKQueryPlanner)]) {
        NSMutableDictionary* opt    = [NSMutableDictionary dictionaryWithDictionary:options];
        opt[@"queryPlanner"]    = self;
        id<SPKTree,GTWQueryPlan> plan   = [(id<SPKQueryPlanner>)model queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:opt];
        if (plan) {
            return plan;
        }
    }
    
    if (algebra == nil) {
        NSLog(@"trying to plan nil algebra");
        return nil;
    }
    id<GTWTriple> t;
    NSInteger count;
    
//    NSLog(@"-------> %@", algebra);
    if ([algebra.type isEqual:kAlgebraDistinct] || [algebra.type isEqual:kAlgebraReduced]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"DISTINCT/REDUCED must be 1-ary");
            return nil;
        }
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!plan)
            return nil;
        return [[SPKQueryPlan alloc] initWithType:kPlanDistinct arguments:@[plan]];
    } else if ([algebra.type isEqual:kAlgebraConstruct]) {
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model optimize:optFlag options:options];
        NSArray* st = [self statementsForTemplateAlgebra: algebra.arguments[0]];
        return [[SPKQueryPlan alloc] initWithType:kPlanConstruct value: st arguments:@[plan]];
    } else if ([algebra.type isEqual:kAlgebraAsk]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"ASK must be 1-ary");
            return nil;
        }
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!plan)
            return nil;
        return [[SPKQueryPlan alloc] initWithType:kPlanAsk arguments:@[plan]];
    } else if ([algebra.type isEqual:kAlgebraGroup]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"Group must be 1-ary");
            return nil;
        }
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!plan)
            return nil;
        return [[SPKQueryPlan alloc] initWithType:kPlanGroup treeValue: algebra.treeValue arguments:@[plan]];
    } else if ([algebra.type isEqual:kAlgebraDataset]) {
        id<SPKTree> pair        = algebra.treeValue;
        id<SPKTree> defSet      = pair.arguments[0];
        id<SPKTree> namedSet    = pair.arguments[1];
        NSSet* defaultGraphs    = defSet.value;
        NSSet* namedGraphs      = namedSet.value;
        GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:[defaultGraphs allObjects] restrictedToGraphs:[namedGraphs allObjects]];
        return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model optimize:optFlag options:options];
    } else if ([algebra.type isEqual:kAlgebraService]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"SERVICE must be 1-ary");
            return nil;
        }
        id<SPKTree> list        = algebra.treeValue;
        id<SPKTree> eptree      = list.arguments[0];
        id<GTWTerm> ep          = eptree.value;
        if ([ep isKindOfClass:[GTWIRI class]]) {
            id<SPKTree> pattern             = algebra.arguments[0];
            NSString* sparql                = [SPKTree sparqlForAlgebra: pattern];
            if (!sparql)
                return nil;
            GTWLiteral* spterm  = [[GTWLiteral alloc] initWithValue:sparql];
            id<SPKTree> tn      = [[SPKTree alloc] initWithType:kTreeNode value:spterm arguments:nil];
//            id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:@[spterm]];
            return [[SPKQueryPlan alloc] initWithType:kPlanService treeValue:list arguments:@[tn]];
        } else {
            NSLog(@"SERVICE not defined for non-IRIs");
            return nil;
        }
    } else if ([algebra.type isEqual:kAlgebraGraph]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"GRAPH must be 1-ary");
            return nil;
        }
        id<SPKTree> graphtree   = algebra.treeValue;
        
        id<GTWTerm> graph       = graphtree.value;
        if ([graph isKindOfClass:[GTWIRI class]]) {
            GTWDataset* newDataset  = [GTWDataset datasetFromDataset:dataset withDefaultGraphs:@[graph]];
//            GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
            id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model optimize:optFlag options:options];
            if (!plan) {
                NSLog(@"Failed to plan child of GRAPH <iri> pattern");
                return nil;
            }
            
            return plan;
        } else {
            NSArray* graphs = [dataset availableGraphsFromModel:model];
            
            id<SPKTree,GTWQueryPlan> gplan     = nil;
            for (id<GTWTerm> g in graphs) {
                GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[g]];
                id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model optimize:optFlag options:options];
                if (!plan) {
                    NSLog(@"Failed to plan child of GRAPH ?var pattern");
                    return nil;
                }
                
                id<SPKTree> list   = [[SPKTree alloc] initWithType:kTreeList arguments:@[
                                                                                      [[SPKTree alloc] initWithType:kTreeNode value:g arguments:@[]],
                                                                                      graphtree,
                                                                                      ]];
                id<SPKTree, GTWQueryPlan> extend    = (id<SPKTree, GTWQueryPlan>) [[SPKTree alloc] initWithType:kPlanExtend treeValue:list arguments:@[plan]];
                if (gplan) {
                    gplan   = [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:@[gplan, extend]];
                } else {
                    gplan   = extend;
                }
            }
            if (!gplan)
                gplan   = [[SPKQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];

            return gplan;
        }
    } else if ([algebra.type isEqual:kAlgebraUnion]) {
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!(lhs && rhs)) {
            NSLog(@"Failed to plan both sides of UNION");
            return nil;
        }
        return [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:@[lhs, rhs]];
    } else if ([algebra.type isEqual:kAlgebraProject]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"PROJECT must be 1-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!lhs) {
            NSLog(@"Failed to plan PROJECT sub-plan");
            return nil;
        }
        id<SPKTree> list    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model optimize:optFlag options:options];
        return [[SPKQueryPlan alloc] initWithType:kPlanProject treeValue: list arguments:@[lhs]];
    } else if ([algebra.type isEqual:kAlgebraJoin] || [algebra.type isEqual:kTreeList]) {
        if ([algebra.arguments count] == 0) {
            if ([algebra.type isEqual:kTreeList]) {
                return [[SPKQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
            } else {
                return [[SPKQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
            }
        } else if ([algebra.arguments count] == 1) {
            return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        } else if ([algebra.arguments count] == 2) {
            id<SPKTree,GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
            id<SPKTree,GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model optimize:optFlag options:options];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of JOIN");
                return nil;
            }
            return [self joinPlanForPlans: lhs and: rhs];
        } else {
            NSMutableArray* args    = [NSMutableArray arrayWithArray:algebra.arguments];
            id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:[args lastObject] usingDataset:dataset withModel:model optimize:optFlag options:options];
            [args removeLastObject];
            while ([args count] > 0) {
                id<SPKTree,GTWQueryPlan> lhs    = [self queryPlanForAlgebra:[args lastObject] usingDataset:dataset withModel:model optimize:optFlag options:options];
                [args removeLastObject];
                if (!lhs) {
                    NSLog(@"Failed to plan both sides of %lu-way JOIN", [algebra.arguments count]);
                    return nil;
                }
                plan   = [self joinPlanForPlans:lhs and:plan];
            }
            return plan;
        }
    } else if ([algebra.type isEqual:kAlgebraMinus]) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"MINUS must be 2-ary");
            return nil;
        }
        // should probably have a new plan type for MINUS blocks
        return [[SPKQueryPlan alloc] initWithType:kPlanMinus value: @"minus" arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model optimize:optFlag options:options]]];
    } else if ([algebra.type isEqual:kAlgebraLeftJoin]) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"LEFT JOIN must be 2-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model optimize:optFlag options:options];
        id<SPKTree> expr        = algebra.treeValue;
        if (!lhs || !rhs) {
            NSLog(@"Failed to plan both sides of LEFT JOIN");
            return nil;
        }
        
        id<SPKTree,GTWQueryPlan> plan   = [[SPKQueryPlan alloc] initWithType:kPlanNLLeftJoin treeValue:expr arguments:@[lhs, rhs]];
        return plan;
    } else if ([algebra.type isEqual:kAlgebraBGP]) {
        return [self planBGP: algebra.arguments usingDataset: dataset withModel:model optimize:optFlag options:nil];
    } else if ([algebra.type isEqual:kAlgebraFilter]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"FILTER must be 1-ary");
            return nil;
        }
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:(BOOL)optFlag options:options];
        if (!plan)
            return nil;
        id<SPKTree> expr    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model optimize:optFlag options:options];
        return [[SPKQueryPlan alloc] initWithType:kPlanFilter treeValue: expr arguments:@[plan]];
    } else if ([algebra.type isEqual:kAlgebraExtend]) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"EXTEND must be 1-ary");
            NSLog(@"Extend: %@", algebra);
            return nil;
        }
        id<SPKTree> pat = algebra.arguments[0];
        id<SPKTree,GTWQueryPlan> p   = [self queryPlanForAlgebra:pat usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!p)
            return nil;
        id<SPKTree> expr    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model optimize:optFlag options:options];
        return [[SPKQueryPlan alloc] initWithType:kPlanExtend treeValue: expr arguments:@[p]];
    } else if ([algebra.type isEqual:kAlgebraSlice]) {
        id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        id<SPKTree> offset      = algebra.arguments[1];
        id<SPKTree> limit       = algebra.arguments[2];
        return [[SPKQueryPlan alloc] initWithType:kPlanSlice arguments:@[plan, offset, limit]];
    } else if ([algebra.type isEqual:kAlgebraOrderBy]) {
        if ([algebra.arguments count] != 1)
            return nil;
        id<SPKTree> list    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model optimize:optFlag options:options];
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        if (!plan)
            return nil;
        
        return [[SPKQueryPlan alloc] initWithType:kPlanOrder treeValue: list arguments:@[plan]];
    } else if ([algebra.type isEqual:kTreeQuad]) {
        return [self planQuad:algebra.value usingDataset:dataset withModel:model optimize:optFlag options:options];
    } else if ([algebra.type isEqual:kTreeTriple]) {
        t   = algebra.value;
        NSArray* defaultGraphs  = [dataset defaultGraphs];
        count   = [defaultGraphs count];
        if (count == 0) {
            return [[SPKQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
        } else if (count == 1) {
            id<GTWQuad> q   = [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]];
            return [self planQuad:q usingDataset:dataset withModel:model optimize:optFlag options:options];
        } else {
            id<GTWQuad> q                   = [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[0]];
            id<SPKTree,GTWQueryPlan> plan   = [self planQuad:q usingDataset:dataset withModel:model optimize:optFlag options:options];
            NSInteger i;
            for (i = 1; i < count; i++) {
                id<GTWQuad> q   = [[GTWQuad alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:defaultGraphs[i]];
                id<SPKTree> qp  = [self planQuad:q usingDataset:dataset withModel:model optimize:optFlag options:options];
                plan            = [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:@[plan, qp]];
            }
            return plan;
        }
    } else if ([algebra.type isEqual:kTreePath]) {
        return [self queryPlanForPathAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag];
    } else if ([algebra.type isEqual:kTreeResultSet]) {
        return (id<SPKTree, GTWQueryPlan>) algebra;
    } else if ([algebra.type isEqual:kAlgebraLoad]) {
        id<SPKTree> list        = algebra.treeValue;
        id<SPKTree> silentTree  = list.arguments[0];
        id<SPKTree> srcTree     = list.arguments[1];
        NSMutableArray* data    = [NSMutableArray array];
        [data addObject:silentTree];
        [data addObject:srcTree];
        if ([list.arguments count] > 2) {
            [data addObject:list.arguments[2]];
        } else {
            NSArray* graphs = [dataset defaultGraphs];
            id<GTWIRI> dg   = [graphs firstObject];
            id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:dg arguments:nil];
            [data addObject:tn];
        }
        
        id<SPKTree> newList = [[SPKTree alloc] initWithType:kTreeList arguments:data];
        return [[SPKQueryPlan alloc] initWithType:kPlanLoad treeValue:newList arguments:nil];
    } else if ([algebra.type isEqual:kAlgebraAdd]) {
        id<SPKTree> list        = algebra.treeValue;
//        id<SPKTree> silentTree  = list.arguments[0];
        id<SPKTree> srcTree     = list.arguments[1];
        id<SPKTree> dstTree     = list.arguments[2];
        
        GTWVariable* s          = [[GTWVariable alloc] initWithValue:@"s"];
        GTWVariable* p          = [[GTWVariable alloc] initWithValue:@"p"];
        GTWVariable* o          = [[GTWVariable alloc] initWithValue:@"o"];
        id<SPKTree> ipattern, qpattern;
        if ([srcTree.type isEqual: kTreeString]) {
            // DEFAULT
            GTWTriple* t    = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
            SPKTree* tt     = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
            qpattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[tt]];
        } else {
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:srcTree.value];
            SPKTree* qt     = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            qpattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[qt]];
        }
        
        if ([dstTree.type isEqual: kTreeString]) {
            // DEFAULT
            GTWTriple* t    = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
            SPKTree* tt     = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
            ipattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[tt]];
        } else {
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:dstTree.value];
            SPKTree* qt     = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            ipattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[qt]];
        }

        id<SPKTree> dpattern    = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];

        id<SPKTree> algebra = [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dpattern, ipattern, qpattern]];
//        NSLog(@"ADD planning algebra: %@", algebra);
        return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
//        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:qpattern usingDataset:dataset withModel:model optimize:optFlag options:options];
//        return [[SPKQueryPlan alloc] initWithType:kPlanModify treeValue:nil arguments:@[dpattern, ipattern, plan]];
    } else if ([algebra.type isEqual:kAlgebraCopy] || [algebra.type isEqual:kAlgebraMove]) {
        BOOL move               = [algebra.type isEqual:kAlgebraMove];
        id<SPKTree> list        = algebra.treeValue;
//        id<SPKTree> silentTree  = list.arguments[0];
        id<SPKTree> srcTree     = list.arguments[1];
        id<SPKTree> dstTree     = list.arguments[2];
        
        GTWVariable* s          = [[GTWVariable alloc] initWithValue:@"s"];
        GTWVariable* p          = [[GTWVariable alloc] initWithValue:@"p"];
        GTWVariable* o          = [[GTWVariable alloc] initWithValue:@"o"];
        if ([srcTree isEqual:dstTree]) {
            // no-op copy
            return [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:@[]];
        }
        
        id<SPKTree> src, dst;
        id<GTWQueryPlan> dropDestination, dropSource;
        if ([srcTree.type isEqual:kTreeString]) {
            // COPY from DEFAULT
            GTWTriple* t    = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
            SPKTree* tt     = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
            src             = [[SPKTree alloc] initWithType:kTreeList arguments:@[tt]];
            
            NSArray* graphs = [dataset defaultGraphs];
            NSMutableArray* ops     = [NSMutableArray array];
            for (id<GTWIRI> dg in graphs) {
                id<SPKTree> tn      = [[SPKTree alloc] initWithType:kTreeNode value:dg arguments:nil];
                id<SPKTree> plan    = [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:tn arguments:nil];
                [ops addObject:plan];
            }
            dropSource      = [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
        } else {
            // COPY from GRAPH
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:srcTree.value];
            SPKTree* qt     = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            src             = [[SPKTree alloc] initWithType:kTreeList arguments:@[qt]];
            dropSource      = [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:srcTree arguments:nil];
        }
        
        if ([dstTree.type isEqual:kTreeString]) {
            // COPY to DEFAULT
            GTWTriple* t    = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
            SPKTree* tt     = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
            dst             = [[SPKTree alloc] initWithType:kTreeList arguments:@[tt]];
            
            NSArray* graphs = [dataset defaultGraphs];
            NSMutableArray* ops     = [NSMutableArray array];
            for (id<GTWIRI> dg in graphs) {
                id<SPKTree> tn      = [[SPKTree alloc] initWithType:kTreeNode value:dg arguments:nil];
                id<SPKTree> plan    = [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:tn arguments:nil];
                [ops addObject:plan];
            }
            dropDestination = [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
        } else {
            // COPY to GRAPH
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:dstTree.value];
            SPKTree* qt     = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            dst             = [[SPKTree alloc] initWithType:kTreeList arguments:@[qt]];
            dropDestination = [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:dstTree arguments:nil];
        }
        
        id<SPKTree> dpattern    = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
        id<SPKTree> algebra     = [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dpattern, dst, src]];

        id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
        NSMutableArray* ops     = [NSMutableArray arrayWithObjects:dropDestination, plan, nil];
        if (move) {
            [ops addObject:dropSource];
        }
        return [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
    } else if ([algebra.type isEqual:kAlgebraClear]) {
        //# Remove all triples from the graph named with the IRI denoted by IRIref.
        //DELETE { GRAPH IRIref { ?s ?p ?o } } WHERE { GRAPH IRIref { ?s ?p ?o } }
        id<SPKTree> list        = algebra.treeValue;
//        id<SPKTree> silentTree  = list.arguments[0];
        id<SPKTree> srcTree     = list.arguments[1];
        
        GTWVariable* s          = [[GTWVariable alloc] initWithValue:@"s"];
        GTWVariable* p          = [[GTWVariable alloc] initWithValue:@"p"];
        GTWVariable* o          = [[GTWVariable alloc] initWithValue:@"o"];
        GTWVariable* g          = [[GTWVariable alloc] initWithValue:@"g"];
        
        id<SPKTree> dpattern;
        id<SPKTree> ipattern    = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
        if ([srcTree.value isEqualToString:@"ALL"]) {
            // CLEAR ALL
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:g];
            id<SPKTree> pat = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            dpattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[pat]];
            id<SPKTree> algebra     = [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dpattern, ipattern, dpattern]];
            return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
        } else if ([srcTree.value isEqualToString:@"GRAPH"]) {
            id<SPKTree> graphTree   = list.arguments[2];
            GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:graphTree.value];
            id<SPKTree> pat = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
            dpattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[pat]];
            id<SPKTree> algebra     = [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dpattern, ipattern, dpattern]];
            return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
        } else if ([srcTree.value isEqualToString:@"NAMED"] || [srcTree.value isEqualToString:@"DEFAULT"]) {
            NSArray* graphs;
            if ([srcTree.value isEqualToString:@"DEFAULT"]) {
                // CLEAR DEFAULT
                graphs  = [dataset defaultGraphs];
            } else {
                // CLEAR NAMED
                graphs  = [dataset availableGraphsFromModel:model];
            }
            NSMutableArray* ops     = [NSMutableArray array];
            for (id<GTWIRI> dg in graphs) {
                GTWQuad* q      = [[GTWQuad alloc] initWithSubject:s predicate:p object:o graph:dg];
                id<SPKTree> pat = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
                dpattern        = [[SPKTree alloc] initWithType:kTreeList arguments:@[pat]];
                id<SPKTree> algebra     = [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dpattern, ipattern, dpattern]];
                id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
                [ops addObject:plan];
            }
            
            return [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
        }
    } else if ([algebra.type isEqual:kAlgebraDrop]) {
        id<SPKTree> list        = algebra.treeValue;
//        id<SPKTree> silentTree  = list.arguments[0];
        id<SPKTree> dstTree     = list.arguments[1];
        if ([dstTree.value isEqualToString:@"ALL"]) {
            // DROP ALL
            // TODO: Create default graph after drop
            return [[SPKQueryPlan alloc] initWithType:kPlanDropAll arguments:nil];
        } else if ([dstTree.value isEqualToString:@"NAMED"] || [dstTree.value isEqualToString:@"DEFAULT"]) {
            NSArray* graphs;
            if ([dstTree.value isEqualToString:@"DEFAULT"]) {
                // DROP DEFAULT
                // TODO: Create default graph after drop
                graphs  = [dataset defaultGraphs];
            } else {
                // DROP NAMED
                graphs  = [dataset availableGraphsFromModel:model];
            }
//            NSLog(@"DROP %@ graphs: %@", dstTree.value, graphs);
            NSMutableArray* ops     = [NSMutableArray array];
            for (id<GTWIRI> dg in graphs) {
                id<SPKTree> tn      = [[SPKTree alloc] initWithType:kTreeNode value:dg arguments:nil];
                id<SPKTree> plan    = [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:tn arguments:nil];
                [ops addObject:plan];
            }
            return [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
        } else if ([dstTree.value isEqualToString:@"GRAPH"]) {
            id<SPKTree> graphTree   = list.arguments[2];
            return [[SPKQueryPlan alloc] initWithType:kPlanDrop treeValue:graphTree arguments:nil];
        }
    } else if ([algebra.type isEqual:kAlgebraInsertData]) {
        NSMutableArray* quads   = [NSMutableArray arrayWithCapacity:[algebra.arguments count]];
        for (id<SPKTree> tree in algebra.arguments) {
            id<GTWStatement> st = tree.value;
            if (![st conformsToProtocol:@protocol(GTWQuad)]) {
                NSArray* defaultGraphs   = [dataset defaultGraphs];
                for (id<GTWIRI> dg in defaultGraphs) {
                    id<GTWQuad,GTWRewriteable> q   = [GTWQuad quadFromTriple:(id<GTWTriple>)st withGraph:dg];
                    id<SPKTree> qt  = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
                    qt              = [self replaceVariablesWithBlanks:qt];
                    [quads addObject:qt];
                }
            } else {
                id<SPKTree> qt  = [self replaceVariablesWithBlanks:tree];
                [quads addObject:qt];
            }
        }
        return [[SPKQueryPlan alloc] initWithType:kPlanInsertData arguments:quads];
    } else if ([algebra.type isEqual:kAlgebraDeleteData]) {
//        NSLog(@"DELETE DATA: %@", algebra);
        NSMutableArray* quads   = [NSMutableArray arrayWithCapacity:[algebra.arguments count]];
        for (id<SPKTree> tree in algebra.arguments) {
            id<GTWStatement> st = tree.value;
            if (![st conformsToProtocol:@protocol(GTWQuad)]) {
                NSArray* defaultGraphs   = [dataset defaultGraphs];
                for (id<GTWIRI> dg in defaultGraphs) {
                    id<GTWQuad,GTWRewriteable> q   = [GTWQuad quadFromTriple:(id<GTWTriple>)st withGraph:dg];
                    id<SPKTree> qt  = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
                    qt              = [self replaceVariablesWithBlanks:qt];
                    [quads addObject:qt];
                }
            } else {
                id<SPKTree> qt  = [self replaceVariablesWithBlanks:tree];
                [quads addObject:qt];
            }
        }
        return [[SPKQueryPlan alloc] initWithType:kPlanDeleteData arguments:quads];
    } else if ([algebra.type isEqual:kAlgebraModify]) {
        id<SPKTree> dpattern    = algebra.arguments[0];
        id<SPKTree> ipattern    = algebra.arguments[1];
        
        NSMutableArray* dstatements    = [NSMutableArray array];
        NSMutableArray* istatements    = [NSMutableArray array];
        for (id<SPKTree> tst in dpattern.arguments) {
            id<GTWStatement> st = tst.value;
            if (![st conformsToProtocol:@protocol(GTWQuad)]) {
                NSArray* defaultGraphs   = [dataset defaultGraphs];
                for (id<GTWIRI> dg in defaultGraphs) {
                    id<GTWQuad> q   = [GTWQuad quadFromTriple:(id<GTWTriple>)st withGraph:dg];
                    [dstatements addObject:[[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil]];
                }
            } else {
                [dstatements addObject:tst];
            }
        }
        for (id<SPKTree> tst in ipattern.arguments) {
            id<GTWStatement> st = tst.value;
            if (![st conformsToProtocol:@protocol(GTWQuad)]) {
                NSArray* defaultGraphs   = [dataset defaultGraphs];
                for (id<GTWIRI> dg in defaultGraphs) {
                    id<GTWQuad> q   = [GTWQuad quadFromTriple:(id<GTWTriple>)st withGraph:dg];
                    [istatements addObject:[[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil]];
                }
            } else {
                [istatements addObject:tst];
            }
        }
        
        id<SPKTree> dlist   = [[SPKTree alloc] initWithType:kTreeList arguments:dstatements];
        id<SPKTree> ilist   = [[SPKTree alloc] initWithType:kTreeList arguments:istatements];
        
        ilist   = [self replaceVariablesWithBlanks:ilist];
        
        id<SPKTree> qpattern    = algebra.arguments[2];
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:qpattern usingDataset:dataset withModel:model optimize:optFlag options:options];
        SPKQueryPlan* modify = [[SPKQueryPlan alloc] initWithType:kPlanModify treeValue:nil arguments:@[dlist, ilist, plan]];
        return modify;
    } else if ([algebra.type isEqual:kAlgebraCreate]) {
        return [[SPKQueryPlan alloc] initWithType:kPlanCreate treeValue:algebra.treeValue arguments:nil];
    } else if ([algebra.type isEqual:kAlgebraSequence]) {
        NSMutableArray* ops = [NSMutableArray array];
        for (id<SPKTree> t in algebra.arguments) {
            id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:t usingDataset:dataset withModel:model optimize:optFlag options:options];
            if (!plan)
                return nil;
            [ops addObject:plan];
        }
        return [[SPKQueryPlan alloc] initWithType:kPlanSequence arguments:ops];
    } else {
        NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
    }
    
    NSLog(@"returning nil query plan");
    return nil;
}

- (id<SPKTree>) treeByPlanningSubTreesOf: (id<SPKTree>) expr usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize:(BOOL)optFlag options: (NSDictionary*) options {
    if (!expr)
        return nil;
    if (expr.type == kExprExists) {
        id<SPKTree> algebra = expr.arguments[0];
        id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
        return [[SPKTree alloc] initWithType:kExprExists arguments:@[plan]];
    } else if (expr.type == kExprNotExists) {
            id<SPKTree> algebra = expr.arguments[0];
            id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model optimize:optFlag options:options];
            return [[SPKTree alloc] initWithType:kExprNotExists arguments:@[plan]];
    } else {
        NSMutableArray* arguments   = [NSMutableArray array];
        for (id<SPKTree> t in expr.arguments) {
            id<SPKTree> newt    = [self treeByPlanningSubTreesOf:t usingDataset:dataset withModel:model optimize:optFlag options:options];
            [arguments addObject:newt];
        }
        id<SPKTree> tv  = [self treeByPlanningSubTreesOf:expr.treeValue usingDataset:dataset withModel:model optimize:optFlag options:options];
        return [[[expr class] alloc] initWithType:expr.type value:expr.value treeValue:tv arguments:arguments];
    }
}

- (id<SPKTree,GTWQueryPlan>) queryPlanForPathAlgebra: (id<SPKTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize:(BOOL)optFlag {
    id<SPKTree> s       = algebra.arguments[0];
    id<SPKTree> path    = algebra.arguments[1];
    id<SPKTree> o       = algebra.arguments[2];
    return [self queryPlanForPath:path starting:s ending:o usingDataset:dataset withModel:model optimize:optFlag];
}

- (void) negationPath: (id<SPKTree>) path forwardPredicates: (NSMutableSet*) fwd inversePredicates: (NSMutableSet*) inv negate: (BOOL) negate {
    if (path.type == kPathInverse) {
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:!negate];
        return;
    } else if (path.type == kPathOr) {
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:negate];
        [self negationPath:path.arguments[1] forwardPredicates:fwd inversePredicates:inv negate:negate];
        return;
    } else if ([path.type isEqual:kTreeNode]) {
        if (negate) {
            [inv addObject:path.value];
        } else {
            [fwd addObject:path.value];
        }
    } else {
        return;
    }
        
}

- (id<SPKTree,GTWQueryPlan>) queryPlanForPath: (id<SPKTree>) path starting: (id<SPKTree>) s ending: (id<SPKTree>) o usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize:(BOOL)optFlag {
    if (path.type == kPathSequence) {
        GTWVariable* b = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@"qp__%lu", self.bnodeCounter++]];
        id<SPKTree> blank   = [[SPKTree alloc] initWithType:kTreeNode value:b arguments:nil];
        id<SPKTree> first   = path.arguments[0];
        id<SPKTree> rest    = path.arguments[1];
        id<SPKTree> lhsPath = [[SPKTree alloc] initWithType:kTreePath arguments:@[s, first, blank]];
        id<SPKTree> rhsPath = [[SPKTree alloc] initWithType:kTreePath arguments:@[blank, rest, o]];
        id<SPKTree, GTWQueryPlan> lhs = [self queryPlanForPathAlgebra:lhsPath usingDataset:dataset withModel:model optimize:optFlag];
        id<SPKTree, GTWQueryPlan> rhs = [self queryPlanForPathAlgebra:rhsPath usingDataset:dataset withModel:model optimize:optFlag];
        if (!(lhs && rhs))
            return nil;
        return [self joinPlanForPlans:lhs and:rhs];
    } else if (path.type == kPathOr) {
        id<GTWQueryPlan> lhs    = [self queryPlanForPath:path.arguments[0] starting:s ending:o usingDataset:dataset withModel:model optimize:optFlag];
        id<GTWQueryPlan> rhs    = [self queryPlanForPath:path.arguments[1] starting:s ending:o usingDataset:dataset withModel:model optimize:optFlag];
        return [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:@[lhs, rhs]];
    } else if (path.type == kPathNegate) {
        NSMutableSet* fwd   = [NSMutableSet set];
        NSMutableSet* inv   = [NSMutableSet set];
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:NO];
        NSMutableArray* plans   = [NSMutableArray array];
        NSArray* graphs     = [dataset defaultGraphs];
        id<SPKTree> graph   = [[SPKTree alloc] initWithType:kTreeNode value:graphs[0] arguments:nil];
        if ([fwd count]) {
            id<SPKTree> set     = [[SPKTree alloc] initWithType:kTreeSet value:fwd arguments:nil];
            id<SPKTree> plan    = [[SPKQueryPlan alloc] initWithType:kPlanNPSPath arguments:@[s, set, o, graph]];
            [plans addObject:plan];
        }
        if ([inv count]) {
            id<SPKTree> set     = [[SPKTree alloc] initWithType:kTreeSet value:inv arguments:nil];
            id<SPKTree> plan    = [[SPKQueryPlan alloc] initWithType:kPlanNPSPath arguments:@[s, set, o, graph]];
            [plans addObject:plan];
        }
        
        if ([plans count] > 1) {
            return [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:plans];
        } else {
            return plans[0];
        }
    } else if (path.type == kPathZeroOrOne) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<SPKTree> temps  = [[SPKTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<SPKTree> tempo  = [[SPKTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<SPKTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model optimize:optFlag];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<SPKTree> t   = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<SPKTree> activeGraphs    = [[SPKTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<SPKTree> list   = [[SPKTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[SPKQueryPlan alloc] initWithType:kPlanZeroOrOnePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathZeroOrMore) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<SPKTree> temps  = [[SPKTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<SPKTree> tempo  = [[SPKTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<SPKTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model optimize:optFlag];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<SPKTree> t   = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<SPKTree> activeGraphs    = [[SPKTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<SPKTree> list   = [[SPKTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[SPKQueryPlan alloc] initWithType:kPlanZeroOrMorePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathOneOrMore) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<SPKTree> temps  = [[SPKTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<SPKTree> tempo  = [[SPKTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<SPKTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model optimize:optFlag];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<SPKTree> t   = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<SPKTree> activeGraphs    = [[SPKTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<SPKTree> list   = [[SPKTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[SPKQueryPlan alloc] initWithType:kPlanOneOrMorePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathInverse) {
        id<SPKTree> p   = [[SPKTree alloc] initWithType:kTreePath arguments:@[o, path.arguments[0], s]];
        return [self queryPlanForPathAlgebra:p usingDataset:dataset withModel:model optimize:optFlag];
    } else if ([path.type isEqual:kTreeNode]) {
        id<GTWTerm> subj    = s.value;
        id<GTWTerm> pred    = path.value;
        id<GTWTerm> obj     = o.value;
        GTWTriple* t        = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:obj];
        id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeTriple value: t arguments:nil];
        return [self queryPlanForAlgebra:triple usingDataset:dataset withModel:model optimize:optFlag options:nil];
    } else {
        NSLog(@"Cannot plan property path <%@ %@>: %@", s, o, path);
        return nil;
    }
    return nil;
}

- (NSArray*) reorderBGPTriples: (NSArray*) triples {
    NSMutableArray* reordered   = [NSMutableArray array];
    NSMutableDictionary* varsToTriples  = [NSMutableDictionary dictionary];
    for (id<SPKTree> triple in triples) {
        if ([triple.type isEqual:kAlgebraExtend] || [triple.type isEqual:kAlgebraFilter]) {
            [reordered addObject:triple];
        } else {
            NSArray* terms;
            if ([triple.type isEqual:kTreeTriple]) {
                terms   = [triple.value allValues];
            } else if ([triple.type isEqual:kTreePath]) {
                // kTreePath
                id<SPKTree> s   = triple.arguments[0];
                id<SPKTree> o   = triple.arguments[2];
                terms   = @[s.value, o.value];
            } else {
                NSLog(@"(1) Unexpected tree type %@", triple);
                NSLog(@"%@", triples);
            }
    //        NSLog(@"terms: %@", terms);
            for (id<GTWTerm> var in terms) {
                if ([var isKindOfClass:[GTWVariable class]] || [var isKindOfClass:[GTWBlank class]]) {
    //                NSLog(@"    var -> %@ (%@)", var, [var class]);
                    NSMutableSet* set   = [varsToTriples objectForKey:var];
                    if (!set) {
                        set = [NSMutableSet set];
                        [varsToTriples setObject:set forKey:var];
                    }
                    [set addObject:triple];
                }
            }
        }
    }
    NSMutableDictionary* triplesToTriples  = [NSMutableDictionary dictionary];
    for (id<SPKTree,NSCopying> triple in triples) {
        if ([triple.type isEqual:kTreeTriple] || [triple.type isEqual:kTreePath]) {
            NSMutableSet* connectedTriples   = [triplesToTriples objectForKey:triple];
            if (!connectedTriples) {
                connectedTriples = [NSMutableSet set];
                [triplesToTriples setObject:connectedTriples forKey:triple];
            }
            
//        NSLog(@"----------> triple: %@", triple);
            NSArray* terms;
            if ([triple.type isEqual:kTreeTriple]) {
                terms   = [triple.value allValues];
            } else if ([triple.type isEqual:kTreePath]) {
                // kTreePath
                id<SPKTree> s   = triple.arguments[0];
                id<SPKTree> o   = triple.arguments[2];
                terms   = @[s.value, o.value];
            } else {
                NSLog(@"(2) Unexpected tree type %@", triple);
            }
            for (id<GTWTerm> var in terms) {
                if ([var isKindOfClass:[GTWVariable class]] || [var isKindOfClass:[GTWBlank class]]) {
    //                NSLog(@"---------->     var: %@", var);
                    NSMutableSet* varConnectedTriples   = [varsToTriples objectForKey:var];
    //                NSLog(@">>>>> %@", varConnectedTriples);
                    if (varConnectedTriples) {
                        [connectedTriples addObjectsFromArray:[varConnectedTriples allObjects]];
                    }
                }
            }
        }
    }
    
//    NSLog(@"triples to triples ---> %@", triplesToTriples);
    NSMutableSet* remaining = [NSMutableSet setWithArray:triples];
    for (id t in reordered) {
        [remaining removeObject:t];
    }
    NSMutableSet* frontier  = [NSMutableSet set];
    if ([remaining count]) {
        id<SPKTree> currentTriple  = [remaining anyObject];
        [reordered addObject:currentTriple];
        [frontier addObjectsFromArray:[[triplesToTriples objectForKey:currentTriple] allObjects]];
        [frontier removeObject:currentTriple];
        [remaining removeObject:currentTriple];
        
        while ([remaining count]) {
            if ([frontier count]) {
                currentTriple   = [frontier anyObject];
            } else {
    //            NSLog(@"Cartesian join in BGP re-ordering");
                currentTriple   = [remaining anyObject];
            }
            [remaining removeObject:currentTriple];
            [frontier addObjectsFromArray:[[triplesToTriples objectForKey:currentTriple] allObjects]];
            [reordered addObject:currentTriple];
            for (id t in reordered) {
                [frontier removeObject:t];
            }
        }
    }
    
    // use varsToTriples to join
    
    return reordered;
}

- (id<SPKTree,GTWQueryPlan>) planBGP:(NSArray*)triples usingDataset:(id<GTWDataset>)dataset withModel: (id<GTWModel>)model optimize:(BOOL)optFlag options:(NSDictionary*)options {
    NSArray* defaultGraphs  = [dataset defaultGraphs];
    NSInteger graphCount    = [defaultGraphs count];
    NSInteger i;
    id<SPKTree,GTWQueryPlan> plan;
    if (graphCount == 0) {
        return [[SPKQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];
    } else if ([triples count] == 0) {
        return [[SPKQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
    } else if ([triples count] == 1) {
        return [self queryPlanForAlgebra:triples[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
    } else {
        NSArray* orderedTriples = [self reorderBGPTriples:triples];
        plan   = [self queryPlanForAlgebra:orderedTriples[0] usingDataset:dataset withModel:model optimize:optFlag options:options];
        for (i = 1; i < [orderedTriples count]; i++) {
            id<SPKTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:orderedTriples[i] usingDataset:dataset withModel:model optimize:optFlag options:options];
            plan   = [self joinPlanForPlans:plan and:quad];
        }
    }
    return plan;
}

@end
