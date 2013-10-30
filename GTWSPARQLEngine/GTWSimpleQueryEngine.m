//
//  GTWSimpleQueryEngine.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSimpleQueryEngine.h"
#import "GTWTree.h"
#import "NSObject+NSDictionary_QueryBindings.h"
#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import "GTWExpression.h"
#import <GTWSWBase/GTWQuad.h>

@implementation GTWSimpleQueryEngine

- (NSEnumerator*) evaluateNLJoin:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    BOOL leftJoin   = (plan.value && [plan.value isEqualToString:@"left"]);
    NSEnumerator* lhs    = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSArray* rhs    = [[self _evaluateQueryPlan:plan.arguments[1] withModel:model] allObjects];
    return [self joinResultsEnumerator:lhs withResults:rhs leftJoin: leftJoin];
}

- (NSEnumerator*) joinResultsEnumerator: (NSEnumerator*) lhs withResults: (NSArray*) rhs leftJoin: (BOOL) leftJoin {
    NSMutableArray* results = [NSMutableArray array];
    for (NSDictionary* l in lhs) {
        BOOL joined = NO;
        for (NSDictionary* r in rhs) {
            NSDictionary* j = [l join: r];
            if (j) {
                joined  = YES;
                [results addObject:j];
            }
        }
        if (leftJoin && !joined) {
            [results addObject:l];
        }
    }
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateAsk:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSDictionary* result    = [results nextObject];
    GTWLiteral* l   = [[GTWLiteral alloc] initWithString:(result ? @"true" : @"false") datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    NSDictionary* r = @{ @".bool": l };
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateDistinct:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSMutableArray* distinct    = [NSMutableArray array];
    NSMutableSet* seen  = [NSMutableSet set];
    for (id r in results) {
        if (![seen member:r]) {
            [distinct addObject:r];
            [seen addObject:r];
        }
    }
    return [distinct objectEnumerator];
}

- (NSEnumerator*) evaluateProject:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSArray* results   = [[self _evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    NSMutableArray* projected   = [NSMutableArray arrayWithCapacity:[results count]];
    GTWTree* listtree   = plan.treeValue;
    NSArray* list       = listtree.arguments;
    for (id r in results) {
        NSMutableDictionary* testResult = [NSMutableDictionary dictionaryWithDictionary:r];
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        for (GTWTree* treenode in list) {
            if (treenode.type == kTreeNode) {
                GTWVariable* v  = treenode.value;
                NSString* name  = [v value];
                if (r[name]) {
                    result[name]    = r[name];
                    testResult[name]    = r[name];
                }
            } else if (treenode.type == kAlgebraExtend) {
                id<GTWTree> list    = treenode.treeValue;
                GTWTree* expr       = list.arguments[0];
                GTWTree* node       = list.arguments[1];
                id<GTWVariable> v   = node.value;
                NSString* name  = [v value];
                id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:testResult usingModel:model resultIdentity:r];
                if (f) {
                    result[name]    = f;
                    testResult[name]    = f;
                }
            }
        }
        [projected addObject:result];
    }
    return [projected objectEnumerator];
}

- (NSEnumerator*) evaluateTriple:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTriple> t    = plan.value;
    NSMutableArray* results = [NSMutableArray array];
    [model enumerateBindingsMatchingSubject:t.subject predicate:t.predicate object:t.object graph:nil usingBlock:^(NSDictionary* r) {
        [results addObject:r];
    } error:nil];
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateQuad:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWQuad> q    = plan.value;
    NSMutableArray* results = [NSMutableArray array];
    [model enumerateBindingsMatchingSubject:q.subject predicate:q.predicate object:q.object graph:q.graph usingBlock:^(NSDictionary* r) {
        [results addObject:r];
    } error:nil];
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateOrder:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSArray* results    = [[self _evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    id<GTWTree> list    = plan.treeValue;
    NSMutableArray* orderTerms  = [NSMutableArray array];
    NSInteger i;
    for (i = 0; i < [list.arguments count]; i+=2) {
        GTWTree* vtree  = list.arguments[i];
        GTWTree* dtree  = list.arguments[i+1];
        id<GTWTerm> dirterm     = dtree.value;
        NSInteger direction     = [[dirterm value] integerValue];
        [orderTerms addObject:@{ @"expr": vtree, @"direction": @(direction) }];
    }
    
    NSArray* ordered    = [results sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
        for (NSDictionary* sortdata in orderTerms) {
            id<GTWTree> expr        = sortdata[@"expr"];
            NSNumber* direction     = sortdata[@"direction"];
            id<GTWTerm> aterm       = [self.evalctx evaluateExpression:expr withResult:a usingModel: model];
            id<GTWTerm> bterm       = [self.evalctx evaluateExpression:expr withResult:b usingModel: model];
//            id<GTWTerm> aterm       = a[variable.value];
//            id<GTWTerm> bterm       = b[variable.value];
            NSComparisonResult cmp  = [aterm compare: bterm];
            if ([direction integerValue] < 0) {
                cmp = -1 * cmp;
            }
            if (cmp != NSOrderedSame)
                return cmp;
        }
        return NSOrderedSame;
    }];
    return [ordered objectEnumerator];
}

- (NSEnumerator*) evaluateUnion:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* lhs    = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSEnumerator* rhs    = [self _evaluateQueryPlan:plan.arguments[1] withModel:model];
    NSMutableArray* results = [NSMutableArray arrayWithArray:[lhs allObjects]];
    [results addObjectsFromArray:[rhs allObjects]];
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateGroupPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> groupData   = plan.treeValue;
    id<GTWTree> groupList   = groupData.arguments[0];
    id<GTWTree> aggListTree = groupData.arguments[1];
    NSArray* aggList        = aggListTree.arguments;
    NSMutableDictionary* aggregates = [NSMutableDictionary dictionary];
    for (id<GTWTree> list in aggList) {
        GTWVariable* v      = list.value;
        id<GTWTree, NSCopying> expr    = list.arguments[0];
        aggregates[expr]    = v;
    }
    NSLog(@"grouping trees: %@", groupList.arguments);
    NSLog(@"aggregates: %@", aggregates);

    NSMutableDictionary* resultGroups   = [NSMutableDictionary dictionary];
    NSEnumerator* results    = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    for (NSDictionary* result in results) {
        NSMutableDictionary* groupKeyDict   = [NSMutableDictionary dictionary];
        for (id<GTWTree> g in groupList.arguments) {
            if (g.type == kAlgebraExtend) {
                id<GTWTree> list    = g.treeValue;
                id<GTWTree> expr    = list.arguments[0];
                id<GTWTree> tn      = list.arguments[1];
                id<GTWTerm> var = tn.value;
                id<GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr withResult:result usingModel: model];
                if (t)
                    groupKeyDict[var.value]   = t;
            } else {
                id<GTWTerm> var = g.value;
                id<GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)g withResult:result usingModel: model];
                if (t)
                    groupKeyDict[var.value]   = t;
            }
        }
        
        id groupKey = groupKeyDict;
        
        if (!resultGroups[groupKey]) {
            resultGroups[groupKey]   = [NSMutableArray array];
        }
        [resultGroups[groupKey] addObject:result];
    }
    
    // There is always at least one group.
    if ([resultGroups count] == 0) {
        resultGroups[@{}]   = @[];
    }
    
    NSLog(@"-------------\nGroups:%@", resultGroups);
    NSMutableArray* finalResults    = [NSMutableArray array];
    for (id groupKey in resultGroups) {
        NSArray* groupResults   = resultGroups[groupKey];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:groupKey];
        for (id<GTWTree> expr in aggregates) {
            GTWVariable* v  = aggregates[expr];
            id<GTWTerm> value   = [self valueOfAggregate:expr forResults:groupResults withModel:model];
            if (value) {
                result[v.value]   = value;
            }
        }
        [finalResults addObject:result];
    }
    return [finalResults objectEnumerator];
}

- (id<GTWTerm>) valueOfAggregate: (id<GTWTree>) expr forResults: (NSArray*) results withModel: (id<GTWModel>) model {
//    NSLog(@"computing aggregate %@", expr);
    if (expr.type == kExprCount) {
        NSNumber* distinct    = expr.value;
        id counter  = ([distinct integerValue]) ? [NSMutableSet set] : [NSMutableArray array];
//        NSLog(@"counting with counter object %@", counter);
        for (NSDictionary* result in results) {
            if ([expr.arguments count]) {
                id<GTWTerm> f   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
                [counter addObject:f];
            } else {
                [counter addObject:@(1)];
            }
        }
//        NSLog(@"-> %lu", [counter count]);
        return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%lu", [counter count]] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
    } else if (expr.type == kExprGroupConcat) {
        NSArray* a  = expr.value;
        NSNumber* distinct  = a[0];
        NSString* separator = a[1];
        NSMutableArray* array   = [NSMutableArray array];
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            if (t)
                [array addObject:t.value];
        }
        return [[GTWLiteral alloc] initWithString:[array componentsJoinedByString:separator]];
    } else if (expr.type == kExprMax) {
        id<GTWTerm> max = nil;
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            if (!max || [t compare:max] == NSOrderedDescending) {
                max = t;
            }
        }
        return max;
    } else if (expr.type == kExprMin) {
        id<GTWTerm> min = nil;
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            if (!min || [t compare:min] == NSOrderedAscending) {
                min = t;
            }
        }
        return min;
    } else if (expr.type == kExprSum) {
        id<GTWTerm> sum    = [[GTWLiteral alloc] initWithString:@"0" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        for (NSDictionary* result in results) {
            id<GTWLiteral,GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            sum = [self.evalctx evaluateNumericExpressionOfType:kExprPlus lhs:sum rhs:t];
            if (!sum)
                break;
        }
        return sum;
    } else if (expr.type == kExprAvg) {
        NSInteger count = 0;
        id<GTWTerm> sum    = [[GTWLiteral alloc] initWithString:@"0" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        for (NSDictionary* result in results) {
            id<GTWLiteral,GTWTerm> t   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            sum = [self.evalctx evaluateNumericExpressionOfType:kExprPlus lhs:sum rhs:t];
            if (!sum)
                break;
            count++;
        }
        if (sum) {
            id<GTWLiteral,GTWTerm> total   = [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%ld", count] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            id<GTWTerm> avg = [self.evalctx evaluateNumericExpressionOfType:kExprDiv lhs:sum rhs:total];
            return avg;
        } else {
            return sum;
        }
    } else if (expr.type == kExprSample) {
        id<GTWTerm> term = nil;
        for (NSDictionary* result in results) {
            term   = [self.evalctx evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result usingModel: model];
            break;
        }
        return term;
    } else {
        // Handle more aggregate types
        NSLog(@"Cannot compute aggregate %@", expr.type);
        return nil;
    }
}

- (NSEnumerator*) evaluateGraphPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> graph   = plan.value;
    id<GTWTerm> term    = graph.value;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSMutableArray* graphs  = [NSMutableArray array];
    [model enumerateGraphsUsingBlock:^(id<GTWTerm> g) {
        [graphs addObject: g];
    } error:nil];
    if ([graphs count]) {
        NSMutableArray* results = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            GTWTree* list   = [[GTWTree alloc] initWithType:kTreeList arguments:@[
                                  [[GTWTree alloc] initWithType:kTreeNode value:g arguments:@[]],
                                  [[GTWTree alloc] initLeafWithType:kTreeNode value:term pointer:NULL],
                              ]];
            id<GTWTree, GTWQueryPlan> extend    = (id<GTWTree, GTWQueryPlan>) [[GTWTree alloc] initWithType:kPlanExtend treeValue:list arguments:@[subplan]];
            NSEnumerator* rhs   = [self evaluateExtend:extend withModel:model];
            [results addObjectsFromArray:[rhs allObjects]];
        }
        return [results objectEnumerator];
    } else {
        return [@[] objectEnumerator];
    }
}

- (NSEnumerator*) evaluateFilter:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> expr       = plan.treeValue;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSArray* results    = [[self _evaluateQueryPlan:subplan withModel:model] allObjects];
    NSMutableArray* filtered   = [NSMutableArray arrayWithCapacity:[results count]];
    for (id result in results) {
        id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:result usingModel: model];
        if ([f respondsToSelector:@selector(booleanValue)] && [(id<GTWLiteral>)f booleanValue]) {
            [filtered addObject:result];
        }
    }
    return [filtered objectEnumerator];
}

- (NSEnumerator*) evaluateExtend:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> list    = plan.treeValue;
    id<GTWTree> expr    = list.arguments[0];
    id<GTWTree> node    = list.arguments[1];
    
    id<GTWVariable> v   = node.value;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSEnumerator* results    = [self _evaluateQueryPlan:subplan withModel:model];
    NSMutableArray* extended   = [NSMutableArray array];
    for (id result in results) {
        id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:result usingModel: model];
        if (f) {
            NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
            id<GTWTerm> value   = [e objectForKey:v.value];
            if (!value || [value isEqual:f]) {
                [e setValue:f forKey:v.value];
                [extended addObject:e];
            }
        } else {
            [extended addObject:result];
        }
    }
    return [extended objectEnumerator];
}

- (NSEnumerator*) evaluateZeroOrOnePathPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> list        = plan.treeValue;
    id<GTWTree> s           = list.arguments[0];
    id<GTWTree> o           = list.arguments[1];
    id<GTWTree> ts          = list.arguments[2];
    id<GTWTree> to          = list.arguments[3];
    id<GTWTree> graphs      = list.arguments[4];
    id<GTWTerm> subj        = s.value;
    id<GTWTerm> obj         = o.value;
    NSEnumerator* r         = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSArray* pathResults    = [r allObjects];
    
    NSMutableSet* results = [NSMutableSet set];
    {
        BOOL subjVar    = [subj isKindOfClass:[GTWVariable class]];
        BOOL objVar     = [obj isKindOfClass:[GTWVariable class]];
        if (subjVar && objVar) {
            // results map both (subj, obj) to each graph node in current graph
            NSMutableSet* nodes = [NSMutableSet set];
            for (id<GTWTree> graphTree in graphs.arguments) {
                [model enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:graphTree.value usingBlock:^(id<GTWQuad> q) {
                    [nodes addObject:q.subject];
                    [nodes addObject:q.object];
                } error:nil];
            }
            for (id<GTWTerm> t in nodes) {
                NSDictionary* result    = @{subj.value: t, obj.value: t};
                [results addObject:result];
            }
        } else if (subjVar) {
            // one result: { subj -> obj }
            NSDictionary* result    = @{subj.value: obj};
            [results addObject:result];
        } else if (objVar) {
            // one result: { obj -> subj }
            NSDictionary* result    = @{obj.value: subj};
            [results addObject:result];
        } else {
            // TODO: one result (the join identity)
            [results addObject:@{}];
        }
    }
    
    for (NSDictionary* result in pathResults) {
        NSMutableDictionary* newResult  = [NSMutableDictionary dictionary];
        id<GTWTerm> subjTerm    = [self.evalctx evaluateExpression:ts withResult:result usingModel: model];
        id<GTWTerm> objTerm     = [self.evalctx evaluateExpression:to withResult:result usingModel: model];
        
        BOOL ok             = YES;
        if ([subj isKindOfClass:[GTWVariable class]]) {
            newResult[subj.value]   = subjTerm;
        } else if (![subjTerm isEqual:subj]) {
            // the subject of this property path is a Term (not a variable) that doesn't match this result
            ok  = NO;
        }
        
        if ([obj isKindOfClass:[GTWVariable class]]) {
            newResult[obj.value]   = objTerm;
        } else if (![objTerm isEqual:obj]) {
            // the object of this property path is a Term (not a variable) that doesn't match this result
            ok  = NO;
        }
        
        if (ok) {
            [results addObject:newResult];
        }
    }

    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateMorePathPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model includeZeroLengthResults: (BOOL) zeroLength {
    id<GTWTree> list        = plan.treeValue;
    id<GTWTree> s           = list.arguments[0];
    id<GTWTree> o           = list.arguments[1];
    id<GTWTree> ts          = list.arguments[2];
    id<GTWTree> to          = list.arguments[3];
    id<GTWTree> graphs      = list.arguments[4];
    id<GTWTerm> subj        = s.value;
    id<GTWTerm> obj         = o.value;
    NSEnumerator* r         = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSArray* pathResults    = [r allObjects];
    NSArray* loopResults    = pathResults;
    
    NSMutableSet* results = [NSMutableSet set];
    if (zeroLength) {
        BOOL subjVar    = [subj isKindOfClass:[GTWVariable class]];
        BOOL objVar     = [obj isKindOfClass:[GTWVariable class]];
        if (subjVar && objVar) {
            // results map both (subj, obj) to each graph node in current graph
            NSMutableSet* nodes = [NSMutableSet set];
            for (id<GTWTree> graphTree in graphs.arguments) {
                [model enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:graphTree.value usingBlock:^(id<GTWQuad> q) {
                    [nodes addObject:q.subject];
                    [nodes addObject:q.object];
                } error:nil];
            }
            for (id<GTWTerm> t in nodes) {
                NSDictionary* result    = @{subj.value: t, obj.value: t};
                [results addObject:result];
            }
        } else if (subjVar) {
            // one result: { subj -> obj }
            NSDictionary* result    = @{subj.value: obj};
            [results addObject:result];
        } else if (objVar) {
            // one result: { obj -> subj }
            NSDictionary* result    = @{obj.value: subj};
            [results addObject:result];
        } else {
            // TODO: one result (the join identity)
            [results addObject:@{}];
        }
    }
    NSUInteger loop         = 1;
    while (YES) {
        loopResults    = [self resultsForMorePathPlan:plan withResults:loopResults forLength:loop withModel:model]; //zeroOrMorePathResults:pathResults forLength: loop];
        NSUInteger lastCount    = [results count];
        for (NSDictionary* result in loopResults) {
            NSMutableDictionary* newResult  = [NSMutableDictionary dictionary];
            id<GTWTerm> subjTerm    = [self.evalctx evaluateExpression:ts withResult:result usingModel: model];
            id<GTWTerm> objTerm     = [self.evalctx evaluateExpression:to withResult:result usingModel: model];
            
            BOOL ok             = YES;
            if ([subj isKindOfClass:[GTWVariable class]]) {
                newResult[subj.value]   = subjTerm;
            } else if (![subjTerm isEqual:subj]) {
                // the subject of this property path is a Term (not a variable) that doesn't match this result
                ok  = NO;
            }
            
            if ([obj isKindOfClass:[GTWVariable class]]) {
                newResult[obj.value]   = objTerm;
            } else if (![objTerm isEqual:obj]) {
                // the object of this property path is a Term (not a variable) that doesn't match this result
                ok  = NO;
            }
            
            if (ok) {
                [results addObject:newResult];
            }
        }
        if ([results count] == lastCount)
            break;
        loop++;
    }
//    NSLog(@"ZeroOrMore path results: %@", results);
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateNPSPathPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWTree> s   = plan.arguments[0];
    id<GTWTree> set = plan.arguments[1];
    NSSet* pset     = set.value;
    id<GTWTree> o   = plan.arguments[2];
    id<GTWTree> g   = plan.arguments[3];
    id<GTWTerm> p   = [[GTWVariable alloc] initWithValue:@".nps"];
    NSMutableSet* results = [NSMutableSet set];
    [model enumerateBindingsMatchingSubject:s.value predicate:p object:o.value graph:g.value usingBlock:^(NSDictionary* r) {
        id<GTWTerm> p   = r[@".nps"];
        if (![pset containsObject:p]) {
            NSMutableDictionary* nr    = [NSMutableDictionary dictionaryWithDictionary:r];
            [nr removeObjectForKey:@".nps"];
            [results addObject:[NSDictionary dictionaryWithDictionary:nr]];
        }
    } error:nil];
    return [results objectEnumerator];
}

- (NSArray*) resultsForMorePathPlan: (id<GTWTree, GTWQueryPlan>)plan withResults: (NSArray*) pathResults forLength: (NSUInteger) length withModel:(id<GTWModel>)model  {
    id<GTWTree> list        = plan.treeValue;
    id<GTWTree> ts          = list.arguments[2];
    id<GTWTree> to          = list.arguments[3];
    id<GTWTerm> temps       = ts.value;
    id<GTWTerm> tempo       = to.value;

    if (length == 1) {
//        NSLog(@"ZeroOrMore path results for loop #%lu: %@", length, pathResults);
        return pathResults;
    } else {
        NSEnumerator* newPathResults   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
        
        NSMutableArray* rhsResults  = [NSMutableArray array];
        NSMutableArray* lhsResults  = [NSMutableArray array];
        GTWVariable* b = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zmr%lu", self.bnodeCounter++]];
        for (NSDictionary* result in newPathResults) {
            // rename temp object to b
            NSMutableDictionary* newResult  = [NSMutableDictionary dictionaryWithDictionary:result];
            id<GTWTerm> term    = result[tempo.value];
            if (term) {
                [newResult removeObjectForKey:tempo.value];
                newResult[b.value]  = term;
            }
            [lhsResults addObject:newResult];
        }
        for (NSDictionary* result in pathResults) {
            // rename subject to b
            NSMutableDictionary* newResult  = [NSMutableDictionary dictionaryWithDictionary:result];
            id<GTWTerm> term    = result[temps.value];
            if (term) {
                [newResult removeObjectForKey:temps.value];
                newResult[b.value]  = term;
            }
            [rhsResults addObject:newResult];
        }
        NSEnumerator* e = [self joinResultsEnumerator:[lhsResults objectEnumerator] withResults:rhsResults leftJoin:NO];
        NSArray* a      = [e allObjects];
//        NSLog(@"ZeroOrMore path results for loop #%lu: %@", length, a);
        return a;
    }
}

- (NSEnumerator*) evaluateConstructPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSMutableArray* triples = [NSMutableArray array];
    NSArray* template       = plan.value;
    for (NSDictionary* result in results) {
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (NSString* varname in result) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:varname];
            mapping[v]    = result[varname];
        }
        for (id<GTWRewriteable> pattern in template) {
            id<GTWTriple, GTWRewriteable> triple   = [pattern copyReplacingValues:mapping];
            if (triple) {
                if ([triple isGround]) {
                    [triples addObject:triple];
                }
            }
        }
    }
    return [triples objectEnumerator];
}

- (NSEnumerator*) evaluateSlice:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    id<GTWTree> offsetNode  = plan.arguments[1];
    id<GTWTree> limitNode   = plan.arguments[2];
    id<GTWLiteral> offset  = offsetNode.value;
    id<GTWLiteral> limit   = limitNode.value;
    NSInteger o = [offset integerValue];
    NSInteger l = [limit integerValue];
    int i;
    if (o > 0) {
        for (i = 0; i < o; i++) {
            [results nextObject];
        }
    }
    if (l < 0) {
        return results;
    } else {
        NSMutableArray* slice   = [NSMutableArray array];
        NSUInteger count    = 0;
        for (id r in results) {
            count++;
            [slice addObject:r];
            if (count >= l)
                break;
        }
        return [slice objectEnumerator];
    }
}

- (NSEnumerator*) _evaluateQueryPlan: (id<GTWTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
    GTWTreeType type    = plan.type;
//    switch (type) {
//        case kPlanNLjoin:
//        case kPlanDistinct:
//        case kPlanProject:
//        case kTreeTriple:
//        case kTreeQuad:
//        case kPlanOrder:
//        case kPlanUnion:
//        case kPlanFilter:
//        case kPlanExtend:
//        case kPlanSlice:
//    }
    if (type == kPlanAsk) {
        return [self evaluateAsk:plan withModel:model];
    } else if (type == kPlanNLjoin) {
        return [self evaluateNLJoin:plan withModel:model];
    } else if (type == kPlanDistinct) {
        return [self evaluateDistinct:plan withModel:model];
    } else if (type == kPlanProject) {
        return [self evaluateProject:plan withModel:model];
    } else if (type == kTreeTriple) {
        return [self evaluateTriple:plan withModel:model];
    } else if (type == kTreeQuad) {
        return [self evaluateQuad:plan withModel:model];
    } else if (type == kPlanOrder) {
        return [self evaluateOrder:plan withModel:model];
    } else if (type == kPlanUnion) {
        return [self evaluateUnion:plan withModel:model];
    } else if (type == kPlanFilter) {
        return [self evaluateFilter:plan withModel:model];
    } else if (type == kPlanExtend) {
        return [self evaluateExtend:plan withModel:model];
    } else if (type == kPlanSlice) {
        return [self evaluateSlice:plan withModel:model];
    } else if (type == kPlanGraph) {
        return [self evaluateGraphPlan:plan withModel:model];
    } else if (type == kPlanGroup) {
        return [self evaluateGroupPlan:plan withModel:model];
    } else if (type == kPlanEmpty) {
        return [@[ @{} ] objectEnumerator];
    } else if (type == kPlanZeroOrOnePath) {
        return [self evaluateZeroOrOnePathPlan:plan withModel:model];
    } else if (type == kPlanOneOrMorePath) {
        return [self evaluateMorePathPlan:plan withModel:model includeZeroLengthResults:NO];
    } else if (type == kPlanZeroOrMorePath) {
        return [self evaluateMorePathPlan:plan withModel:model includeZeroLengthResults:YES];
    } else if (type == kPlanNPSPath) {
        return [self evaluateNPSPathPlan:plan withModel:model];
    } else if (type == kPlanConstruct) {
        return [self evaluateConstructPlan:plan withModel:model];
    } else if (type == kTreeResultSet) {
        NSArray* resultsTree    = plan.arguments;
        NSMutableArray* results = [NSMutableArray arrayWithCapacity:[resultsTree count]];
        for (id<GTWTree> r in resultsTree) {
            NSDictionary* rt  = r.value;
            NSMutableDictionary* result = [NSMutableDictionary dictionary];
            for (id<GTWTerm> k in rt) {
                id<GTWTree> v   = rt[k];
                id<GTWTerm> t   = v.value;
                result[k.value]       = t;
            }
            [results addObject:result];
        }
        NSLog(@"DATA results: %@", results);
        return [results objectEnumerator];
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

- (NSEnumerator*) evaluateQueryPlan: (id<GTWTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
    self.evalctx    = [[GTWExpressionEvaluationContext alloc] init];
    self.evalctx.queryengine    = self;
    return [self _evaluateQueryPlan:plan withModel:model];
}

@end
