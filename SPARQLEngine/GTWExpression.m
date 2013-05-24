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
    switch (expr.type) {
        case TREE_NODE:
            if ([expr.value isKindOfClass:[GTWVariable class]]) {
                value   = [result objectForKey:[expr.value value]];
            } else {
                value   = expr.value;
            }
            return value;
        case EXPR_OR:
            lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
            rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
            if ([((GTWLiteral*) lhs) booleanValue] || [((GTWLiteral*) rhs) booleanValue]) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        case EXPR_AND:
            lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
            rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
            if ([((GTWLiteral*) lhs) booleanValue] && [((GTWLiteral*) rhs) booleanValue]) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        case EXPR_EQ:
            lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
            rhs = [self evaluateExpression:expr.arguments[1] WithResult:result];
            if ([lhs isEqual:rhs]) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        case EXPR_NEQ:
        case EXPR_LT:
        case EXPR_GT:
        case EXPR_LE:
        case EXPR_GE:
        case EXPR_UMINUS:
        case EXPR_PLUS:
        case EXPR_MINUS:
        case EXPR_BANG:
        case EXPR_LITERAL:
        case EXPR_FUNCTION:
        case EXPR_BOUND:
        case EXPR_STR:
        case EXPR_LANG:
        case EXPR_DATATYPE:
            NSLog(@"Cannot evaluate expression %@", expr);
            return nil;
        case EXPR_ISURI:
            lhs = [self evaluateExpression:expr.arguments[0] WithResult:result];
            NSLog(@"ISIRI(%@)", lhs);
            if ([lhs isKindOfClass:[GTWIRI class]]) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        case EXPR_ISBLANK:
        case EXPR_ISLITERAL:
        case EXPR_CAST:
        case EXPR_LANGMATCHES:
        case EXPR_REGEX:
        case EXPR_COUNT:
        case EXPR_SAMETERM:
        case EXPR_SUM:
        case EXPR_AVG:
        case EXPR_MIN:
        case EXPR_MAX:
        case EXPR_COALESCE:
        case EXPR_IF:
        case EXPR_URI:
        case EXPR_IRI:
        case EXPR_STRLANG:
        case EXPR_STRDT:
        case EXPR_BNODE:
        case EXPR_GROUP_CONCAT:
        case EXPR_SAMPLE:
        case EXPR_IN:
        case EXPR_NOT_IN:
        case EXPR_ISNUMERIC:
        case EXPR_YEAR:
        case EXPR_MONTH:
        case EXPR_DAY:
        case EXPR_HOURS:
        case EXPR_MINUTES:
        case EXPR_SECONDS:
        case EXPR_TIMEZONE:
        case EXPR_CURRENT_DATETIME:
        case EXPR_NOW:
        case EXPR_FROM_UNIXTIME:
        case EXPR_TO_UNIXTIME:
        case EXPR_CONCAT:
        case EXPR_STRLEN:
        case EXPR_SUBSTR:
        case EXPR_UCASE:
        case EXPR_LCASE:
        case EXPR_STRSTARTS:
        case EXPR_STRENDS:
        case EXPR_CONTAINS:
        case EXPR_ENCODE_FOR_URI:
        case EXPR_TZ:
        case EXPR_RAND:
        case EXPR_ABS:
        case EXPR_ROUND:
        case EXPR_CEIL:
        case EXPR_FLOOR:
        case EXPR_MD5:
        case EXPR_SHA1:
        case EXPR_SHA224:
        case EXPR_SHA256:
        case EXPR_SHA384:
        case EXPR_SHA512:
        case EXPR_STRBEFORE:
        case EXPR_STRAFTER:
        case EXPR_REPLACE:
        case EXPR_UUID:
        case EXPR_STRUUID:
        default:
            NSLog(@"Cannot evaluate expression %@", expr);
            return nil;
    }
}

@end
