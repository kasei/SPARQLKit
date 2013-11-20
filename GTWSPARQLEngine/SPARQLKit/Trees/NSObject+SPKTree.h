//
//  NSObject+SPKTree.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/14/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (SPKTree)

- (NSSet*) projectableAggregateVariables;
- (NSSet*) projectableAggregateVariableswithExtendedVariables: (BOOL) withExtended;

@end
