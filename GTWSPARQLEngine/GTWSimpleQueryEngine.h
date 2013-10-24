//
//  GTWSimpleQueryEngine.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWExpressionEvaluationContext.h"

@interface GTWSimpleQueryEngine : NSObject<GTWQueryEngine>

@property GTWExpressionEvaluationContext* evalctx;
@property NSUInteger bnodeCounter;

@end
