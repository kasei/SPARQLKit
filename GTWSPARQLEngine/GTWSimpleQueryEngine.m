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
            GTWVariable* v  = treenode.value;
            NSString* name  = [v value];
            if (r[name]) {
                result[name]    = r[name];
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
    GTWTree* node       = list.arguments[0];
    GTWTree* expr       = list.arguments[1];
    
    id<GTWVariable> v   = node.value;
    id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSEnumerator* results    = [self evaluateQueryPlan:subplan withModel:model];
    NSMutableArray* extended   = [NSMutableArray array];
    for (id result in results) {
        id<GTWTerm> f   = [GTWExpression evaluateExpression:expr withResult:result];
        NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
        [e setValue:f forKey:v.value];
        [extended addObject:e];
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

- (NSEnumerator*) evaluateExpr:(id<GTWTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    
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
    if (type == kPlanNLjoin) {
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
    } else if (type == kPlanEmpty) {
        return [@[ @{} ] objectEnumerator];
    } else if (type == kExprPlus) {
        return [self evaluateExpr:plan withModel:model];
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

@end
