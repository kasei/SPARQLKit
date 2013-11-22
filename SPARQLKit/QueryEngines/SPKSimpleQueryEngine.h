//
//  SPKSimpleQueryEngine.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import "SPKExpressionEvaluationContext.h"

@interface SPKSimpleQueryEngine : NSObject<GTWQueryEngine>

@property SPKExpressionEvaluationContext* evalctx;
@property NSUInteger bnodeCounter;

@end
