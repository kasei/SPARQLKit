//
//  SPKExpressionEvaluationContext.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPKExpression.h"
#import "SPARQLKit.h"

@interface SPKExpressionEvaluationContext : NSObject

@property NSUInteger bnodeID;
@property NSDictionary* functionImplementations;
@property __weak id<GTWQueryEngine> queryengine;

- (SPKExpressionEvaluationContext*) initWithFunctionImplementations: (NSDictionary*) impls;
- (id<GTWTerm>) evaluateExpression: (id<SPKTree>) expr withResult: (NSDictionary*) result usingModel: (id<GTWModel>) model;
- (id<GTWTerm>) evaluateExpression: (id<SPKTree>) expr withResult: (NSDictionary*) result usingModel: (id<GTWModel>) model resultIdentity: (id) rident;
- (id<GTWTerm>) evaluateNumericExpressionOfType: (SPKTreeType) type lhs: (id<GTWLiteral,GTWTerm>) lhs rhs: (id<GTWLiteral,GTWTerm>) rhs;

@end
