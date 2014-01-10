//
//  NSObject+SPKTree.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/14/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "NSObject+SPKTree.h"
#import "SPARQLKit.h"
#import "SPKTree.h"

@implementation NSObject (SPKTree)

/**
 Returns a set of variable objects that may be included in projection.
 If @c withExtended is true, the set includes variables that are created
 in an extend operation in this or sub- algebra trees.
 */
- (NSSet*) spk_projectableAggregateVariableswithExtendedVariables: (BOOL) withExtended {
    if ([self conformsToProtocol:@protocol(SPKTree)]) {
        id<SPKTree> tree    = (id<SPKTree>) self;
        if ([tree.type isEqual:kAlgebraGroup]) {
            id<SPKTree> grouping    = [tree.treeValue arguments][0];
            NSArray* groups         = grouping.arguments;
            NSMutableSet* groupVars = [NSMutableSet set];
            for (id<SPKTree> g in groups) {
                if ([g.type isEqual:kTreeNode]) {
                    [groupVars addObject:g.value];
                } else if ([g.type isEqual:kAlgebraExtend]) {
                    id<SPKTree> list    = g.treeValue;
                    id<SPKTree> var     = list.arguments[1];
                    [groupVars addObject:var.value];
                }
            }
            return groupVars;
        } else if (withExtended && [tree.type isEqual:kAlgebraExtend]) {
            id<SPKTree> list    = tree.treeValue;
            id<SPKTree> var = list.arguments[1];
            NSMutableSet* groupVars = [NSMutableSet setWithObject:var.value];
            for (id t in tree.arguments) {
                NSSet* subVars  = [t spk_projectableAggregateVariableswithExtendedVariables:withExtended];
                [groupVars addObjectsFromArray:[subVars allObjects]];
            }
            return groupVars;
        } else if ([tree.type isEqual:kTreeNode]) {
            NSMutableSet* groupVars = [NSMutableSet set];
            [groupVars addObject:tree.value];
            return groupVars;
        } else {
            NSMutableSet* groupVars = [NSMutableSet set];
            if (tree.arguments) {
                for (id t in tree.arguments) {
                    NSSet* subVars  = [t spk_projectableAggregateVariableswithExtendedVariables:withExtended];
                    [groupVars addObjectsFromArray:[subVars allObjects]];
                }
            }
            return groupVars;
        }
    }
    return nil;
}

/**
 Returns a set of variable objects that may be included in projection.
 */
- (NSSet*) spk_projectableAggregateVariables {
    return [self spk_projectableAggregateVariableswithExtendedVariables:YES];
}

- (NSSet*) spk_accessPatterns {
    if ([self conformsToProtocol:@protocol(SPKTree)]) {
        id<SPKTree> tree    = (id<SPKTree>) self;
        if ([tree.type isEqual:kPlanGraph]) {
            return [NSSet setWithObject:self];
        } else if ([tree.type isEqual:kTreeQuad]) {
            return [NSSet setWithObject:self];
        } else {
            NSMutableSet* aps = [NSMutableSet set];
            if (tree.arguments) {
                for (id t in tree.arguments) {
                    NSSet* ap  = [t spk_accessPatterns];
                    [aps addObjectsFromArray:[ap allObjects]];
                }
            }
            return aps;
        }
    }
    return nil;
}

@end
