//
//  GTWExpression.m
//  SPARQLEngine
//
//  Created by Gregory Williams on 5/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWExpression.h"
#import "GTWVariable.h"
#import "GTWLiteral.h"
#import "GTWIRI.h"

@implementation GTWExpression

+ (id<GTWTerm>) evaluateExpression: (GTWTree*) expr WithResult: (NSDictionary*) result {
    id<GTWTerm> lhs, rhs;
    id<GTWTerm> value;
    if (expr.type == kTreeNode) {
        if ([expr.value conformsToProtocol:@protocol(GTWVariable)]) {
            value   = [result objectForKey:[expr.value value]];
        } else {
            value   = expr.value;
        }
        return value;
    } else if (expr.type == kExprOr) {
        lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
        if ([((GTWLiteral*) lhs) booleanValue] || [((GTWLiteral*) rhs) booleanValue]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprAnd) {
        lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
        if ([((GTWLiteral*) lhs) booleanValue] && [((GTWLiteral*) rhs) booleanValue]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprEq) {
        lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
        if ([lhs isEqual:rhs]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprIsURI) {
        lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
        NSLog(@"ISIRI(%@)", lhs);
        if ([lhs conformsToProtocol:@protocol(GTWIRI)]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprRand) {
        GTWLiteral* l   = [GTWLiteral doubleLiteralWithValue:((double)rand() / RAND_MAX)];
        return l;
    } else {
        NSLog(@"Cannot evaluate expression %@", expr);
        return nil;
    }
}

- (NSString*) description {
    return [self conciseDescription];
}

@end
