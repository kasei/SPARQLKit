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

- (NSEnumerator*) evaluateQueryPlan: (id<GTWTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
    GTWTreeType type    = plan.type;
    if (type == kPlanNLjoin) {
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
    } else if (type == kPlanDistinct) {
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
    } else if (type == kPlanProject) {
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
    } else if (type == kTreeTriple) {
        id<GTWTriple> t    = plan.value;
        NSMutableArray* results = [NSMutableArray array];
        [model enumerateBindingsMatchingSubject:t.subject predicate:t.predicate object:t.object graph:nil usingBlock:^(NSDictionary* r) {
            [results addObject:r];
        } error:nil];
        return [results objectEnumerator];
    } else if (type == kTreeQuad) {
        id<GTWQuad> q    = plan.value;
        NSMutableArray* results = [NSMutableArray array];
        [model enumerateBindingsMatchingSubject:q.subject predicate:q.predicate object:q.object graph:q.graph usingBlock:^(NSDictionary* r) {
            [results addObject:r];
        } error:nil];
        return [results objectEnumerator];
    } else if (type == kPlanOrder) {
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
    } else if (type == kPlanUnion) {
        NSEnumerator* lhs    = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
        NSEnumerator* rhs    = [self evaluateQueryPlan:plan.arguments[1] withModel:model];
        NSMutableArray* results = [NSMutableArray arrayWithArray:[lhs allObjects]];
        [results addObjectsFromArray:[rhs allObjects]];
        return [results objectEnumerator];
    } else if (type == kPlanFilter) {
        GTWTree* expr       = plan.value;
        id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
        NSArray* results    = [[self evaluateQueryPlan:subplan withModel:model] allObjects];
        NSMutableArray* filtered   = [NSMutableArray arrayWithCapacity:[results count]];
        for (id result in results) {
            id<GTWTerm> f   = [GTWExpression evaluateExpression:expr WithResult:result];
            //            NSLog(@"-> %@", f);
            if ([f respondsToSelector:@selector(booleanValue)] && [(id<GTWLiteral>)f booleanValue]) {
                [filtered addObject:result];
            }
        }
        return [filtered objectEnumerator];
    } else if (type == kPlanExtend) {
        GTWTree* list       = plan.value;
        GTWTree* node       = list.arguments[0];
        GTWTree* expr       = list.arguments[1];
        id<GTWVariable> v   = node.value;
        id<GTWTree,GTWQueryPlan> subplan    = plan.arguments[0];
        NSEnumerator* results    = [self evaluateQueryPlan:subplan withModel:model];
        NSMutableArray* extended   = [NSMutableArray array];
        for (id result in results) {
            id<GTWTerm> f   = [GTWExpression evaluateExpression:expr WithResult:result];
            NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
            [e setValue:f forKey:v.value];
            [extended addObject:e];
        }
        return [extended objectEnumerator];
    } else if (type == kPlanSlice) {
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
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

@end
