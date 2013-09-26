//
//  GTWExpression.m
//  SPARQLEngine
//
//  Created by Gregory Williams on 5/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWExpression.h"
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWIRI.h>

static BOOL isNumeric(id<GTWTerm> term) {
    if (!term)
        return NO;
    NSString* datatype  = term.datatype;
    if (datatype && [datatype rangeOfString:@"^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double)$" options:NSRegularExpressionSearch].location == 0) {
        return YES;
    } else {
        return NO;
    }
}

@implementation GTWExpression

+ (id<GTWTerm>) evaluateExpression: (GTWTree*) expr withResult: (NSDictionary*) result {
    if (!expr)
        return nil;
    id<GTWTerm> lhs, rhs;
    id<GTWTerm> value;
    if (expr.type == kTreeNode) {
        if ([expr.value conformsToProtocol:@protocol(GTWVariable)]) {
            value   = result[[expr.value value]];
        } else {
            value   = expr.value;
        }
        return value;
    } else if (expr.type == kExprOr) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([((GTWLiteral*) lhs) booleanValue] || [((GTWLiteral*) rhs) booleanValue]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprAnd) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([((GTWLiteral*) lhs) booleanValue] && [((GTWLiteral*) rhs) booleanValue]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprEq) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([lhs isEqual:rhs]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprIsURI) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        NSLog(@"ISIRI(%@)", lhs);
        if ([lhs conformsToProtocol:@protocol(GTWIRI)]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else if (expr.type == kExprGe) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value >= cmpvalue) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        }
    } else if (expr.type == kExprLe) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value <= cmpvalue) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        }
    } else if (expr.type == kExprLt) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value < cmpvalue) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        }
    } else if (expr.type == kExprGt) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value > cmpvalue) {
                return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            } else {
                return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
            }
        }
    } else if (expr.type == kExprRand) {
        GTWLiteral* l   = [GTWLiteral doubleLiteralWithValue:((double)rand() / RAND_MAX)];
        return l;
    } else if (expr.type == kExprAbs) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        if (isNumeric(term)) {
            NSString* datatype  = term.datatype;
            if ([datatype isEqual: @"http://www.w3.org/2001/XMLSchema#integer"]) {
                NSInteger value  = [term integerValue];
                if (value < 0) {
                    value = -value;
                }
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lu", (unsigned long) value] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            } else if ([datatype isEqual: @"http://www.w3.org/2001/XMLSchema#decimal"]) {
                double value  = [term doubleValue];
                if (value < 0.0) {
                    value = -value;
                }
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lf", value] datatype:@"http://www.w3.org/2001/XMLSchema#decimal"];
            }
        } else {
            return nil;
        }
    } else if (expr.type == kExprPlus) {
        // TODO: handle double and float in addition to integer
        id<GTWLiteral,GTWTerm> lhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> rhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (lhs && rhs) {
            NSInteger lhsI  = [lhs integerValue];
            NSInteger rhsI  = [rhs integerValue];
            NSInteger sum   = lhsI + rhsI;
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lu", (unsigned long) sum] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprStr) {
        id<GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        GTWLiteral* str = [[GTWLiteral alloc] initWithString:term.value];
        return str;
    } else if (expr.type == kExprMinus) {
        // TODO: handle double and float in addition to integer
        id<GTWLiteral,GTWTerm> lhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> rhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (lhs && rhs) {
            NSInteger lhsI  = [lhs integerValue];
            NSInteger rhsI  = [rhs integerValue];
            NSInteger diff   = lhsI - rhsI;
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lu", (unsigned long) diff] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprRegex) {
//        NSLog(@"REGEX arguments: %@", expr.arguments);
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        NSString* string    = term.value;
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result];
        id<GTWTerm> args    = ([expr.arguments count] > 2) ? [self evaluateExpression:expr.arguments[2] withResult:result] : nil;
        NSInteger opt       = NSRegularExpressionSearch;
        if (args && [args.value isEqual:@"i"]) {
            opt |= NSCaseInsensitiveSearch;
        }
//        NSLog(@"regex string : '%@'", string);
//        NSLog(@"regex pattern: '%@'", pattern.value);
        NSRange range       = [string rangeOfString:pattern.value options:opt];
//        NSLog(@"regex location {%lu %lu}", range.location, range.length);
        return [[GTWLiteral alloc] initWithString:(range.location == NSNotFound ? @"false" : @"true") datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    } else if (expr.type == kExprLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        NSString* lang  = [term language];
        if (lang) {
            return [[GTWLiteral alloc] initWithValue:lang];
        } else {
            return nil;
        }
    } else if (expr.type == kExprLangMatches) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result];
        NSString* lang      = term.value;
        if (lang && [lang hasPrefix:pattern.value]) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
        return nil;
    } else if (expr.type == kExprIsNumeric) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (isNumeric(term)) {
            return [[GTWLiteral alloc] initWithString:@"true" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        } else {
            return [[GTWLiteral alloc] initWithString:@"false" datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
        }
    } else {
        NSLog(@"Cannot evaluate expression %@", expr);
        return nil;
    }
}

- (NSString*) description {
    return [self conciseDescription];
}

@end
