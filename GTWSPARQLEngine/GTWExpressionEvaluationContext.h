//
//  GTWExpressionEvaluationContext.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GTWExpression.h"
#import "GTWSPARQLEngine.h"

@interface GTWExpressionEvaluationContext : NSObject

@property NSUInteger bnodeID;

- (id<GTWTerm>) evaluateExpression: (id<GTWTree>) expr withResult: (NSDictionary*) result usingModel: (id<GTWModel>) model;

@end
