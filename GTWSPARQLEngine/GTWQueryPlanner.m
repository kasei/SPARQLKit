#import "GTWQueryPlanner.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import "GTWSPARQLEngine.h"

@implementation GTWQueryPlanner

- (GTWQueryPlanner*) init {
    if (self = [super init]) {
        self.bnodeCounter   = 0;
        self.varID          = 0;
        self.bnodeMap       = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model optimize: (BOOL) opt {
    id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
    if (opt) {
        [plan computeScopeVariables];
    }
    return plan;
}

- (NSArray*) statementsForTemplateAlgebra: (id<GTWTree>) algebra {
    if (algebra.type == kTreeList || algebra.type == kAlgebraBGP) {
        NSMutableArray* triples = [NSMutableArray array];
        for (id<GTWTree> tree in algebra.arguments) {
            NSArray* t  = [self statementsForTemplateAlgebra:tree];
            if (t) {
                [triples addObjectsFromArray:t];
            }
        }
        return triples;
    } else if (algebra.type == kTreeTriple) {
        return @[ algebra.value ];
    } else if (algebra.type == kAlgebraProject) {
        id<GTWTree> tree    = algebra.arguments[0];
        return [self statementsForTemplateAlgebra:tree];
    } else {
        NSLog(@"don't know how to extract triples from algebra: %@", algebra);
        return nil;
    }
}

- (id<GTWTree,GTWQueryPlan>) joinPlanForPlans: (id<GTWTree>) lhs and: (id<GTWTree>) rhs {
    NSSet* lhsVars  = nil;
    NSSet* rhsVars  = nil;
    
    if (lhs.type == kTreeQuad && rhs.type == kPlanHashJoin) {
        id<GTWTree> temp    = lhs;
        lhs                 = rhs;
        rhs                 = temp;
//    } else if (lhs.type == kTreeQuad && rhs.type == kTreeQuad) {
//        if ([[lhs inScopeVariables] count] < [[rhs inScopeVariables] count]) {
//            id<GTWTree> temp    = lhs;
//            lhs                 = rhs;
//            rhs                 = temp;
//        }
    }
    
    
    if (lhs.type == kTreeQuad) {
        lhsVars   = [lhs inScopeVariables];
    } else if (lhs.type == kPlanHashJoin) {
        lhsVars   = [lhs inScopeVariables];
    }
    if (rhs.type == kTreeQuad) {
        rhsVars   = [rhs inScopeVariables];
    } else if (rhs.type == kPlanHashJoin) {
        rhsVars   = [rhs inScopeVariables];
    }
    if (lhsVars && rhsVars) {
        NSMutableSet* joinVars = [NSMutableSet setWithSet:lhsVars];
        [joinVars intersectSet:rhsVars];
        if ([joinVars count]) {
            return [[GTWQueryPlan alloc] initWithType:kPlanHashJoin value:joinVars arguments:@[lhs, rhs]];
        }
    }
//    NSLog(@"HashJoin not available for:\n%@\n%@", lhs, rhs);
//    NSLog(@"Join vars: %@ %@", lhsVars, rhsVars);
    return [[GTWQueryPlan alloc] initWithType:kPlanNLjoin arguments:@[lhs, rhs]];
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
    if (algebra == nil) {
        NSLog(@"trying to plan nil algebra");
        return nil;
    }
    id<GTWTriple> t;
    NSInteger count;
    NSArray* defaultGraphs;
    
//    NSLog(@"-------> %@", algebra);
    if (algebra.type == kAlgebraDistinct || algebra.type == kAlgebraReduced) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"DISTINCT/REDUCED must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanDistinct arguments:@[plan]];
    } else if (algebra.type == kAlgebraConstruct) {
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
        NSArray* st = [self statementsForTemplateAlgebra: algebra.arguments[0]];
        return [[GTWQueryPlan alloc] initWithType:kPlanConstruct value: st arguments:@[plan]];
    } else if (algebra.type == kAlgebraAsk) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"ASK must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanAsk arguments:@[plan]];
    } else if (algebra.type == kAlgebraGroup) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"Group must be 1-ary");
            return nil;
        }
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        return [[GTWQueryPlan alloc] initWithType:kPlanGroup treeValue: algebra.treeValue arguments:@[plan]];
    } else if (algebra.type == kAlgebraDataset) {
        id<GTWTree> pair        = algebra.treeValue;
        id<GTWTree> defSet      = pair.arguments[0];
        id<GTWTree> namedSet    = pair.arguments[1];
        NSSet* defaultGraphs    = defSet.value;
        NSSet* namedGraphs      = namedSet.value;
        GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:[defaultGraphs allObjects] restrictedToGraphs:[namedGraphs allObjects]];
        return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model];
    } else if (algebra.type == kAlgebraService) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"SERVICE must be 1-ary");
            return nil;
        }
        id<GTWTree> list        = algebra.treeValue;
        id<GTWTree> eptree      = list.arguments[0];
        id<GTWTerm> ep          = eptree.value;
        if ([ep isKindOfClass:[GTWIRI class]]) {
            id<GTWTree> pattern             = algebra.arguments[0];
            NSString* sparql                = [GTWTree sparqlForAlgebra: pattern];
            if (!sparql)
                return nil;
            GTWLiteral* spterm  = [[GTWLiteral alloc] initWithValue:sparql];
            id<GTWTree> tn      = [[GTWTree alloc] initWithType:kTreeNode value:spterm arguments:nil];
//            id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:@[spterm]];
            return [[GTWQueryPlan alloc] initWithType:kPlanService treeValue:list arguments:@[tn]];
        } else {
            NSLog(@"SERVICE not defined for non-IRIs");
            return nil;
        }
    } else if (algebra.type == kAlgebraGraph) {
        if ([algebra.arguments count] != 1) {
            NSLog(@"GRAPH must be 1-ary");
            return nil;
        }
        id<GTWTree> list        = algebra.treeValue;
        id<GTWTree> graphtree   = list.arguments[0];
        
        id<GTWTree> expr        = nil;
        if ([list.arguments count] > 1) {
            expr    = list.arguments[1];
        }
        
        id<GTWTerm> graph       = graphtree.value;
        if ([graph isKindOfClass:[GTWIRI class]]) {
            GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
            id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model];
            if (!plan) {
                NSLog(@"Failed to plan child of GRAPH <iri> pattern");
                return nil;
            }
            
            plan    = [[GTWQueryPlan alloc] initWithType:kPlanGraph treeValue: graphtree arguments:@[plan]];
            if (expr) {
                id<GTWTree> e    = [self treeByPlanningSubTreesOf:expr usingDataset:newDataset withModel:model];
                plan    = [[GTWQueryPlan alloc] initWithType:kPlanFilter treeValue: e arguments:@[plan]];
            }
            return plan;
        } else {
            NSArray* graphs = [dataset availableGraphsFromModel:model];
            
            id<GTWTree,GTWQueryPlan> gplan     = nil;
            for (id<GTWTerm> g in graphs) {
                GTWDataset* newDataset  = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[g]];
                id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:newDataset withModel:model];
                if (!plan) {
                    NSLog(@"Failed to plan child of GRAPH ?var pattern");
                    return nil;
                }
                
                id<GTWTree> list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[
                                                                                      [[GTWTree alloc] initWithType:kTreeNode value:g arguments:@[]],
                                                                                      graphtree,
                                                                                      ]];
                id<GTWTree, GTWQueryPlan> extend    = (id<GTWTree, GTWQueryPlan>) [[GTWTree alloc] initWithType:kPlanExtend treeValue:list arguments:@[plan]];
                if (expr) {
                    id<GTWTree> e    = [self treeByPlanningSubTreesOf:expr usingDataset:newDataset withModel:model];
                    extend    = [[GTWQueryPlan alloc] initWithType:kPlanFilter treeValue: e arguments:@[extend]];
                }
                
                if (gplan) {
                    gplan   = [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[gplan, extend]];
                } else {
                    gplan   = extend;
                }
            }
            if (!gplan)
                gplan   = [[GTWQueryPlan alloc] initWithType:kPlanEmpty arguments:@[]];

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
        id<GTWTree> list    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model];
        return [[GTWQueryPlan alloc] initWithType:kPlanProject treeValue: list arguments:@[lhs]];
    } else if (algebra.type == kAlgebraJoin || algebra.type == kTreeList) {
        if ([algebra.arguments count] == 0) {
            return [[GTWQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
        } else if ([algebra.arguments count] == 1) {
            return [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        } else if ([algebra.arguments count] == 2) {
            id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
            id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
            if (!lhs || !rhs) {
                NSLog(@"Failed to plan both sides of JOIN");
                return nil;
            }
            return [self joinPlanForPlans: lhs and: rhs];
        } else {
            NSMutableArray* args    = [NSMutableArray arrayWithArray:algebra.arguments];
            id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:[args lastObject] usingDataset:dataset withModel:model];
            [args removeLastObject];
            while ([args count] > 0) {
                id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:[args lastObject] usingDataset:dataset withModel:model];
                [args removeLastObject];
                if (!lhs) {
                    NSLog(@"Failed to plan both sides of %lu-way JOIN", [algebra.arguments count]);
                    return nil;
                }
                plan   = [self joinPlanForPlans:lhs and:plan];
            }
            return plan;
        }
    } else if (algebra.type == kAlgebraMinus) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"MINUS must be 2-ary");
            return nil;
        }
        // should probably have a new plan type for MINUS blocks
        return [[GTWQueryPlan alloc] initWithType:kPlanMinus value: @"minus" arguments:@[[self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model], [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model]]];
    } else if (algebra.type == kAlgebraLeftJoin) {
        if ([algebra.arguments count] != 2) {
            NSLog(@"LEFT JOIN must be 2-ary");
            return nil;
        }
        id<GTWQueryPlan> lhs    = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        id<GTWQueryPlan> rhs    = [self queryPlanForAlgebra:algebra.arguments[1] usingDataset:dataset withModel:model];
        id<GTWTree> expr        = algebra.treeValue;
        if (!lhs || !rhs) {
            NSLog(@"Failed to plan both sides of LEFT JOIN");
            return nil;
        }
        
        id<GTWTree,GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initWithType:kPlanNLLeftJoin treeValue:expr arguments:@[lhs, rhs]];
        return plan;
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
        id<GTWTree> expr    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model];
        return [[GTWQueryPlan alloc] initWithType:kPlanFilter treeValue: expr arguments:@[plan]];
    } else if (algebra.type == kAlgebraExtend) {
        if ([algebra.arguments count] > 1) {
            NSLog(@"EXTEND must be 0- or 1-ary");
            NSLog(@"Extend: %@", algebra);
            return nil;
        }
        id<GTWTree> pat = ([algebra.arguments count]) ? algebra.arguments[0] : nil;
        if (pat) {
            id<GTWTree,GTWQueryPlan> p   = [self queryPlanForAlgebra:pat usingDataset:dataset withModel:model];
            if (!p)
                return nil;
            id<GTWTree> expr    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model];
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend treeValue: expr arguments:@[p]];
        } else {
            id<GTWQueryPlan> empty    = [[GTWQueryPlan alloc] initLeafWithType:kPlanJoinIdentity value:nil];
            id<GTWTree> expr    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model];
            return [[GTWQueryPlan alloc] initWithType:kPlanExtend treeValue: expr arguments:@[empty]];
        }
    } else if (algebra.type == kAlgebraSlice) {
        id<GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        id<GTWTree> offset      = algebra.arguments[1];
        id<GTWTree> limit       = algebra.arguments[2];
        return [[GTWQueryPlan alloc] initWithType:kPlanSlice arguments:@[plan, offset, limit]];
    } else if (algebra.type == kAlgebraOrderBy) {
        if ([algebra.arguments count] != 1)
            return nil;
        id<GTWTree> list    = [self treeByPlanningSubTreesOf:algebra.treeValue usingDataset:dataset withModel:model];
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra.arguments[0] usingDataset:dataset withModel:model];
        if (!plan)
            return nil;
        
        return [[GTWQueryPlan alloc] initWithType:kPlanOrder treeValue: list arguments:@[plan]];
    } else if (algebra.type == kTreeTriple) {
        t   = algebra.value;
        defaultGraphs   = [dataset defaultGraphs];
        count   = [defaultGraphs count];
        NSMutableDictionary* bnodeMap   = self.bnodeMap;
        id<GTWTerm> (^mapBnodes)(id<GTWTerm> t) = ^id<GTWTerm>(id<GTWTerm> t){
            if ([t isKindOfClass:[GTWBlank class]]) {
                if ([bnodeMap objectForKey:t]) {
                    return [bnodeMap objectForKey:t];
                } else {
                    NSUInteger vid  = ++(self.varID);
                    id<GTWTerm> v   = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".b%lu", vid]];
                    [bnodeMap setObject:v forKey:t];
                    return v;
                }
            } else {
                return t;
            }
        };
        if (count == 0) {
            return [[GTWQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
        } else if (count == 1) {
            return [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:mapBnodes(t.subject) predicate:mapBnodes(t.predicate) object:mapBnodes(t.object) graph:defaultGraphs[0]]];
        } else {
            id<GTWTree,GTWQueryPlan> plan   = [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:mapBnodes(t.subject) predicate:mapBnodes(t.predicate) object:mapBnodes(t.object) graph:defaultGraphs[0]]];
            NSInteger i;
            for (i = 1; i < count; i++) {
                plan    = [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[plan, [[GTWQueryPlan alloc] initLeafWithType:kTreeQuad value: [[GTWQuad alloc] initWithSubject:mapBnodes(t.subject) predicate:mapBnodes(t.predicate) object:mapBnodes(t.object) graph:defaultGraphs[i]]]]];
            }
            return plan;
        }
    } else if (algebra.type == kTreePath) {
        return [self queryPlanForPathAlgebra:algebra usingDataset:dataset withModel:model];
    } else if (algebra.type == kTreeResultSet) {
        return (id<GTWTree, GTWQueryPlan>) algebra;
    } else {
        NSLog(@"cannot plan query algebra of type %@\n", [algebra treeTypeName]);
    }
    
    NSLog(@"returning nil query plan");
    return nil;
}

- (id<GTWTree>) treeByPlanningSubTreesOf: (id<GTWTree>) expr usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
    if (!expr)
        return nil;
    if (expr.type == kExprExists) {
        id<GTWTree> algebra = expr.arguments[0];
        id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
        return [[GTWTree alloc] initWithType:kExprExists arguments:@[plan]];
    } else if (expr.type == kExprNotExists) {
            id<GTWTree> algebra = expr.arguments[0];
            id<GTWTree,GTWQueryPlan> plan   = [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
            return [[GTWTree alloc] initWithType:kExprNotExists arguments:@[plan]];
    } else {
        NSMutableArray* arguments   = [NSMutableArray array];
        for (id<GTWTree> t in expr.arguments) {
            id<GTWTree> newt    = [self treeByPlanningSubTreesOf:t usingDataset:dataset withModel:model];
            [arguments addObject:newt];
        }
        id<GTWTree> tv  = [self treeByPlanningSubTreesOf:expr.treeValue usingDataset:dataset withModel:model];
        return [[[expr class] alloc] initWithType:expr.type value:expr.value treeValue:tv arguments:arguments];
    }
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForPathAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
    id<GTWTree> s       = algebra.arguments[0];
    id<GTWTree> path    = algebra.arguments[1];
    id<GTWTree> o       = algebra.arguments[2];
    return [self queryPlanForPath:path starting:s ending:o usingDataset:dataset withModel:model];
}

- (void) negationPath: (id<GTWTree>) path forwardPredicates: (NSMutableSet*) fwd inversePredicates: (NSMutableSet*) inv negate: (BOOL) negate {
    if (path.type == kPathInverse) {
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:!negate];
        return;
    } else if (path.type == kPathOr) {
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:negate];
        [self negationPath:path.arguments[1] forwardPredicates:fwd inversePredicates:inv negate:negate];
        return;
    } else if (path.type == kTreeNode) {
        if (negate) {
            [inv addObject:path.value];
        } else {
            [fwd addObject:path.value];
        }
    } else {
        return;
    }
        
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForPath: (id<GTWTree>) path starting: (id<GTWTree>) s ending: (id<GTWTree>) o usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
    if (path.type == kPathSequence) {
        GTWVariable* b = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@"qp__%lu", self.bnodeCounter++]];
        id<GTWTree> blank   = [[GTWTree alloc] initWithType:kTreeNode value:b arguments:nil];
        id<GTWTree> first   = path.arguments[0];
        id<GTWTree> rest    = path.arguments[1];
        id<GTWTree> lhsPath = [[GTWTree alloc] initWithType:kTreePath arguments:@[s, first, blank]];
        id<GTWTree> rhsPath = [[GTWTree alloc] initWithType:kTreePath arguments:@[blank, rest, o]];
        id<GTWTree, GTWQueryPlan> lhs = [self queryPlanForPathAlgebra:lhsPath usingDataset:dataset withModel:model];
        id<GTWTree, GTWQueryPlan> rhs = [self queryPlanForPathAlgebra:rhsPath usingDataset:dataset withModel:model];
        if (!(lhs && rhs))
            return nil;
        return [self joinPlanForPlans:lhs and:rhs];
    } else if (path.type == kPathOr) {
        id<GTWQueryPlan> lhs    = [self queryPlanForPath:path.arguments[0] starting:s ending:o usingDataset:dataset withModel:model];
        id<GTWQueryPlan> rhs    = [self queryPlanForPath:path.arguments[1] starting:s ending:o usingDataset:dataset withModel:model];
        return [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:@[lhs, rhs]];
    } else if (path.type == kPathNegate) {
        NSMutableSet* fwd   = [NSMutableSet set];
        NSMutableSet* inv   = [NSMutableSet set];
        [self negationPath:path.arguments[0] forwardPredicates:fwd inversePredicates:inv negate:NO];
        NSMutableArray* plans   = [NSMutableArray array];
        NSArray* graphs     = [dataset defaultGraphs];
        id<GTWTree> graph   = [[GTWTree alloc] initWithType:kTreeNode value:graphs[0] arguments:nil];
        if ([fwd count]) {
            id<GTWTree> set     = [[GTWTree alloc] initWithType:kTreeSet value:fwd arguments:nil];
            id<GTWTree> plan    = [[GTWQueryPlan alloc] initWithType:kPlanNPSPath arguments:@[s, set, o, graph]];
            [plans addObject:plan];
        }
        if ([inv count]) {
            id<GTWTree> set     = [[GTWTree alloc] initWithType:kTreeSet value:inv arguments:nil];
            id<GTWTree> plan    = [[GTWQueryPlan alloc] initWithType:kPlanNPSPath arguments:@[s, set, o, graph]];
            [plans addObject:plan];
        }
        
        if ([plans count] > 1) {
            return [[GTWQueryPlan alloc] initWithType:kPlanUnion arguments:plans];
        } else {
            return plans[0];
        }
    } else if (path.type == kPathZeroOrOne) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<GTWTree> temps  = [[GTWTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<GTWTree> tempo  = [[GTWTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<GTWTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<GTWTree> t   = [[GTWTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<GTWTree> activeGraphs    = [[GTWTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<GTWTree> list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[GTWQueryPlan alloc] initWithType:kPlanZeroOrOnePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathZeroOrMore) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<GTWTree> temps  = [[GTWTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<GTWTree> tempo  = [[GTWTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<GTWTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<GTWTree> t   = [[GTWTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<GTWTree> activeGraphs    = [[GTWTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<GTWTree> list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[GTWQueryPlan alloc] initWithType:kPlanZeroOrMorePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathOneOrMore) {
        GTWVariable* ts = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        GTWVariable* to = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zm%lu", self.bnodeCounter++]];
        id<GTWTree> temps  = [[GTWTree alloc] initWithType:kTreeNode value:ts arguments:nil];
        id<GTWTree> tempo  = [[GTWTree alloc] initWithType:kTreeNode value:to arguments:nil];
        id<GTWTree, GTWQueryPlan> plan  = [self queryPlanForPath:path.arguments[0] starting:temps ending:tempo usingDataset:dataset withModel:model];
        NSArray* graphs     = [dataset defaultGraphs];
        NSMutableArray* graphsTrees = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            id<GTWTree> t   = [[GTWTree alloc] initWithType:kTreeNode value:g arguments:nil];
            [graphsTrees addObject:t];
        }
        id<GTWTree> activeGraphs    = [[GTWTree alloc] initWithType:kTreeList arguments:graphsTrees];
        id<GTWTree> list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[ s, o, temps, tempo, activeGraphs ]];
        return [[GTWQueryPlan alloc] initWithType:kPlanOneOrMorePath treeValue:list arguments:@[plan]];
    } else if (path.type == kPathInverse) {
        id<GTWTree> p   = [[GTWTree alloc] initWithType:kTreePath arguments:@[o, path.arguments[0], s]];
        return [self queryPlanForPathAlgebra:p usingDataset:dataset withModel:model];
    } else if (path.type == kTreeNode) {
        id<GTWTerm> subj    = s.value;
        id<GTWTerm> pred    = path.value;
        id<GTWTerm> obj     = o.value;
        GTWTriple* t        = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:obj];
        id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreeTriple value: t arguments:nil];
        return [self queryPlanForAlgebra:triple usingDataset:dataset withModel:model];
    } else {
        NSLog(@"Cannot plan property path <%@ %@>: %@", s, o, path);
        return nil;
    }
    return nil;
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra withModel: (id<GTWModel>) model {
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[]];
    return [self queryPlanForAlgebra:algebra usingDataset:dataset withModel:model];
}

- (NSArray*) reorderBGPTriples: (NSArray*) triples {
    NSMutableArray* reordered   = [NSMutableArray array];
    NSMutableDictionary* varsToTriples  = [NSMutableDictionary dictionary];
    for (id<GTWTree> triple in triples) {
        if (triple.type == kAlgebraExtend || triple.type == kAlgebraFilter) {
            [reordered addObject:triple];
        } else {
            NSArray* terms;
            if (triple.type == kTreeTriple) {
                terms   = [triple.value allValues];
            } else if (triple.type == kTreePath) {
                // kTreePath
                id<GTWTree> s   = triple.arguments[0];
                id<GTWTree> o   = triple.arguments[2];
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
    for (id<GTWTree,NSCopying> triple in triples) {
        if (triple.type == kTreeTriple || triple.type == kTreePath) {
            NSMutableSet* connectedTriples   = [triplesToTriples objectForKey:triple];
            if (!connectedTriples) {
                connectedTriples = [NSMutableSet set];
                [triplesToTriples setObject:connectedTriples forKey:triple];
            }
            
//        NSLog(@"----------> triple: %@", triple);
            NSArray* terms;
            if (triple.type == kTreeTriple) {
                terms   = [triple.value allValues];
            } else if (triple.type == kTreePath) {
                // kTreePath
                id<GTWTree> s   = triple.arguments[0];
                id<GTWTree> o   = triple.arguments[2];
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
        id<GTWTree> currentTriple  = [remaining anyObject];
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

- (id<GTWTree,GTWQueryPlan>) planBGP: (NSArray*) triples usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model {
//    NSLog(@"planning BGP: %@\n", triples);
    NSArray* defaultGraphs   = [dataset defaultGraphs];
    NSInteger graphCount   = [defaultGraphs count];
    NSInteger i;
    id<GTWTree,GTWQueryPlan> plan;
    if (graphCount == 0) {
        return [[GTWQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
    } else if ([triples count] == 0) {
        return [[GTWQueryPlan alloc] initWithType:kPlanJoinIdentity arguments:@[]];
    } else if ([triples count] == 1) {
        return [self queryPlanForAlgebra:triples[0] usingDataset:dataset withModel:model];
    } else {
        NSArray* orderedTriples = [self reorderBGPTriples:triples];
        plan   = [self queryPlanForAlgebra:orderedTriples[0] usingDataset:dataset withModel:model];
        for (i = 1; i < [orderedTriples count]; i++) {
            id<GTWTree,GTWQueryPlan> quad    = [self queryPlanForAlgebra:orderedTriples[i] usingDataset:dataset withModel:model];
            plan   = [self joinPlanForPlans:plan and:quad];
        }
    }
    return plan;
}

@end
