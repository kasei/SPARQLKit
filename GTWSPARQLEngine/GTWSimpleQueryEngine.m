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

@implementation GTWSimpleQueryEngine

- (NSEnumerator*) evaluateNLJoin:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    BOOL leftJoin   = (plan.value && [plan.value isEqualToString:@"left"]);
    NSMutableArray* results = [NSMutableArray array];
    NSEnumerator* lhs    = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSArray* rhs    = [[self evaluateQueryPlan:plan.arguments[1] withModel:model] allObjects];
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
    NSEnumerator* results   = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSDictionary* result    = [results nextObject];
    GTWLiteral* l   = [[GTWLiteral alloc] initWithString:(result ? @"true" : @"false") datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    NSDictionary* r = @{ @".bool": l };
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateDistinct:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
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
    NSArray* results   = [[self evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    NSMutableArray* projected   = [NSMutableArray arrayWithCapacity:[results count]];
    GTWTree* listtree   = plan.value;
    NSArray* list       = listtree.arguments;
    for (id r in results) {
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        for (GTWTree* treenode in list) {
            if (treenode.type == kTreeNode) {
                GTWVariable* v  = treenode.value;
                NSString* name  = [v value];
                if (r[name]) {
                    result[name]    = r[name];
                }
            } else if (treenode.type == kAlgebraExtend) {
                id<GTWTree> list    = treenode.treeValue;
                GTWTree* expr       = list.arguments[0];
                GTWTree* node       = list.arguments[1];
                id<GTWVariable> v   = node.value;
                NSString* name  = [v value];
                id<GTWTerm> f   = [GTWExpression evaluateExpression:expr withResult:r];
                if (f) {
                    result[name]    = f;
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
    NSArray* results   = [[self evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    GTWTree* list       = plan.value;
    NSMutableArray* orderTerms  = [NSMutableArray array];
    NSInteger i;
    for (i = 0; i < [list.arguments count]; i+=2) {
        GTWTree* vtree  = list.arguments[i];
        GTWTree* dtree  = list.arguments[i+1];
        id<GTWTerm> dirterm     = dtree.value;
        id<GTWTerm> variable    = vtree.value;
        NSInteger direction     = [[dirterm value] integerValue];
        [orderTerms addObject:@{ @"variable": variable, @"direction": @(direction) }];
    }
    
    NSArray* ordered    = [results sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
        for (NSDictionary* sortdata in orderTerms) {
            id<GTWTerm> variable    = sortdata[@"variable"];
            NSNumber* direction      = sortdata[@"direction"];
            id<GTWTerm> aterm       = a[variable.value];
            id<GTWTerm> bterm       = b[variable.value];
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
    NSEnumerator* lhs    = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSEnumerator* rhs    = [self evaluateQueryPlan:plan.arguments[1] withModel:model];
    NSMutableArray* results = [NSMutableArray arrayWithArray:[lhs allObjects]];
    [results addObjectsFromArray:[rhs allObjects]];
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateGroupPlan:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
//    TreeList(
//             TreeList(TreeNode[?x]),
//             TreeList(
//                      TreeList[?.0](ExprMax[0](TreeNode[?y])),
//                      TreeList[?.1](ExprMax[0](TreeNode[?z]))
//             )
//    )
    id<GTWTree> groupData   = plan.value;
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
    NSEnumerator* results    = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    for (NSDictionary* result in results) {
        NSMutableArray* resultGroupData = [NSMutableArray array];
        NSMutableDictionary* groupKeyDict   = [NSMutableDictionary dictionary];
        for (id<GTWTree> g in groupList.arguments) {
            if (g.type == kAlgebraExtend) {
                id<GTWTree> list    = g.treeValue;
                id<GTWTree> expr    = list.arguments[0];
                id<GTWTree> tn      = list.arguments[1];
                id<GTWTerm> var = tn.value;
                id<GTWTerm> t   = [GTWExpression evaluateExpression:(GTWTree*)expr withResult:result];
                [resultGroupData addObject:t];
                groupKeyDict[var.value]   = t;
            } else {
                id<GTWTerm> var = g.value;
                id<GTWTerm> t   = [GTWExpression evaluateExpression:(GTWTree*)g withResult:result];
                [resultGroupData addObject:t];
                groupKeyDict[var.value]   = t;
            }
        }
        
//        id groupKey   = [resultGroupData componentsJoinedByString:@":"];
        id groupKey = groupKeyDict;
        
//        resultGroupTerms[groupKey]   = resultGroupData;
        
        if (!resultGroups[groupKey]) {
            resultGroups[groupKey]   = [NSMutableArray array];
        }
        [resultGroups[groupKey] addObject:result];
    }
    NSLog(@"-------------\nGroups:%@", resultGroups);
    NSMutableArray* finalResults    = [NSMutableArray array];
    for (id groupKey in resultGroups) {
        NSArray* groupResults   = resultGroups[groupKey];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:groupKey];
        for (id<GTWTree> expr in aggregates) {
            GTWVariable* v  = aggregates[expr];
            id<GTWTerm> value   = [self valueOfAggregate:expr forResults:groupResults];
            if (value) {
                result[v.value]   = value;
            }
        }
        [finalResults addObject:result];
    }
    return [finalResults objectEnumerator];
}

- (id<GTWTerm>) valueOfAggregate: (id<GTWTree>) expr forResults: (NSArray*) results {
    if (expr.type == kExprCount) {
        GTWLiteral* distinct    = expr.value;
        id counter  = ([distinct integerValue]) ? [NSMutableSet set] : [NSMutableArray array];
        for (NSDictionary* result in results) {
            if ([expr.arguments count]) {
                id<GTWTerm> f   = [GTWExpression evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result];
                [counter addObject:f];
            } else {
                [counter addObject:@(1)];
            }
        }
        return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%lu", [counter count]] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
    } else if (expr.type == kExprGroupConcat) {
        GTWLiteral* distinct    = expr.value;
        NSMutableArray* array   = [NSMutableArray array];
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [GTWExpression evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result];
            if (t)
                [array addObject:t.value];
        }
        return [[GTWLiteral alloc] initWithString:[array componentsJoinedByString:@""]];
    } else if (expr.type == kExprMax) {
        id<GTWTerm> max = nil;
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [GTWExpression evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result];
            if (!max || [t compare:max] == NSOrderedDescending) {
                max = t;
            }
        }
        return max;
    } else if (expr.type == kExprMin) {
        id<GTWTerm> min = nil;
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [GTWExpression evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result];
            if (!min || [t compare:min] == NSOrderedAscending) {
                min = t;
            }
        }
        return min;
    } else if (expr.type == kExprSample) {
        id<GTWTerm> term = nil;
        for (NSDictionary* result in results) {
            term   = [GTWExpression evaluateExpression:(GTWTree*)expr.arguments[0] withResult:result];
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
            id<GTWTree, GTWQueryPlan> extend    = (id<GTWTree, GTWQueryPlan>) [[GTWTree alloc] initWithType:kPlanExtend value:list arguments:@[subplan]];
            NSEnumerator* rhs   = [self evaluateExtend:extend withModel:model];
            [results addObjectsFromArray:[rhs allObjects]];
        }
        return [results objectEnumerator];
    } else {
        return [@[] objectEnumerator];
    }
}

- (NSEnumerator*) evaluateFilter:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    GTWTree* expr       = plan.value;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSArray* results    = [[self evaluateQueryPlan:subplan withModel:model] allObjects];
    NSMutableArray* filtered   = [NSMutableArray arrayWithCapacity:[results count]];
    for (id result in results) {
        id<GTWTerm> f   = [GTWExpression evaluateExpression:expr withResult:result];
        if ([f respondsToSelector:@selector(booleanValue)] && [(id<GTWLiteral>)f booleanValue]) {
            [filtered addObject:result];
        }
    }
    return [filtered objectEnumerator];
}

- (NSEnumerator*) evaluateExtend:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    GTWTree* list       = plan.value;
    GTWTree* expr       = list.arguments[0];
    GTWTree* node       = list.arguments[1];
    
    id<GTWVariable> v   = node.value;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSEnumerator* results    = [self evaluateQueryPlan:subplan withModel:model];
    NSMutableArray* extended   = [NSMutableArray array];
    for (id result in results) {
        id<GTWTerm> f   = [GTWExpression evaluateExpression:expr withResult:result];
        NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
        id<GTWTerm> value   = [e objectForKey:v.value];
        if (!value || [value isEqual:f]) {
            [e setValue:f forKey:v.value];
            [extended addObject:e];
        }
    }
    return [extended objectEnumerator];
}

- (NSEnumerator*) evaluateSlice:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
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

- (NSEnumerator*) evaluateQueryPlan: (id<GTWTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
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

@end
