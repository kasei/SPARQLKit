//
//  NSObject+GTWTree.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/14/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "NSObject+GTWTree.h"
#import "GTWSPARQLEngine.h"
#import "GTWTree.h"

@implementation NSObject (GTWTree)

/**
 Returns a set of variable objects that may be included in projection.
 If @c withExtended is true, the set includes variables that are created
 in an extend operation in this or sub- algebra trees.
 */
- (NSSet*) projectableAggregateVariableswithExtendedVariables: (BOOL) withExtended {
    if ([self conformsToProtocol:@protocol(GTWTree)]) {
        id<GTWTree> tree    = (id<GTWTree>) self;
        if (tree.type == kAlgebraGroup) {
            id<GTWTree> grouping    = [tree.treeValue arguments][0];
            NSArray* groups         = grouping.arguments;
            NSMutableSet* groupVars = [NSMutableSet set];
            for (id<GTWTree> g in groups) {
                if (g.type == kTreeNode) {
                    [groupVars addObject:g.value];
                } else if (g.type == kAlgebraExtend) {
                    id<GTWTree> list    = g.treeValue;
                    id<GTWTree> var     = list.arguments[1];
                    [groupVars addObject:var.value];
                }
            }
            return groupVars;
        } else if (withExtended && tree.type == kAlgebraExtend) {
            id<GTWTree> list    = tree.treeValue;
            id<GTWTree> var = list.arguments[1];
            NSMutableSet* groupVars = [NSMutableSet setWithObject:var.value];
            for (id t in tree.arguments) {
                NSSet* subVars  = [t projectableAggregateVariableswithExtendedVariables:withExtended];
                [groupVars addObjectsFromArray:[subVars allObjects]];
            }
            return groupVars;
        } else if (tree.type == kTreeNode) {
            NSMutableSet* groupVars = [NSMutableSet set];
            [groupVars addObject:tree.value];
            return groupVars;
        } else {
            NSMutableSet* groupVars = [NSMutableSet set];
            if (tree.arguments) {
                for (id t in tree.arguments) {
                    NSSet* subVars  = [t projectableAggregateVariableswithExtendedVariables:withExtended];
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
- (NSSet*) projectableAggregateVariables {
    return [self projectableAggregateVariableswithExtendedVariables:YES];
}


@end
