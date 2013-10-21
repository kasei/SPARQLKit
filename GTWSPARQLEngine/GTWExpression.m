//
//  GTWExpression.m
//  SPARQLEngine
//
//  Created by Gregory Williams on 5/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#include <CommonCrypto/CommonDigest.h>
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

+ (id<GTWTerm>) evaluateExpression: (id<GTWTree>) expr withResult: (NSDictionary*) result {
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
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprAnd) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([((GTWLiteral*) lhs) booleanValue] && [((GTWLiteral*) rhs) booleanValue]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprEq) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([lhs isEqual:rhs]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsURI) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result];
        NSLog(@"ISIRI(%@)", lhs);
        if ([lhs conformsToProtocol:@protocol(GTWIRI)]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprGe) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value >= cmpvalue) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprLe) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value <= cmpvalue) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprLt) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value < cmpvalue) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprGt) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWLiteral,GTWTerm> cmp = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result];
        if (isNumeric(term)) {
            double value    = [term doubleValue];
            double cmpvalue = [cmp doubleValue];
            if (value > cmpvalue) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
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
            if (![lhs isKindOfClass:[GTWLiteral class]])
                return nil;
            if (![rhs isKindOfClass:[GTWLiteral class]])
                return nil;
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
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
        return nil;
    } else if (expr.type == kExprStrLen) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (term && [term isKindOfClass:[GTWLiteral class]]) {
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%lu", [term.value length]] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprSHA1 || expr.type == kExprSHA224 || expr.type == kExprSHA256 || expr.type == kExprSHA512) {
        NSUInteger dataLength   = 0;
        unsigned char* (*SHA_FUNC)(const void *data, CC_LONG len, unsigned char *md)    = NULL;
        if (expr.type == kExprSHA1) {
            SHA_FUNC    = CC_SHA1;
            dataLength  = CC_SHA1_DIGEST_LENGTH;
        } else if (expr.type == kExprSHA224) {
            SHA_FUNC    = CC_SHA224;
            dataLength  = CC_SHA224_DIGEST_LENGTH;
        } else if (expr.type == kExprSHA256) {
            SHA_FUNC    = CC_SHA256;
            dataLength  = CC_SHA256_DIGEST_LENGTH;
        } else if (expr.type == kExprSHA512) {
            SHA_FUNC    = CC_SHA512;
            dataLength  = CC_SHA512_DIGEST_LENGTH;
        }
        if (dataLength == 0) {
            return nil;
        }
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        unsigned char digest[dataLength];
        NSData *stringBytes = [term.value dataUsingEncoding: NSUTF8StringEncoding]; /* or some other encoding */
        
        if (SHA_FUNC([stringBytes bytes], (CC_LONG) [stringBytes length], digest)) {
            NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
            for (int i = 0; i < dataLength; ++i)
                [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)digest[i]]];
            return [[GTWLiteral alloc] initWithValue:hexString];
        } else {
            return nil;
        }
    } else if (expr.type == kExprUUID) {
//        urn:uuid:b9302fb5-642e-4d3b-af19-29a8f6d894c9
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
        return [[GTWIRI alloc] initWithValue:[NSString stringWithFormat:@"urn:uuid:%@", uuidStr]];
    } else if (expr.type == kExprStrUUID) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
        return [[GTWLiteral alloc] initWithString:uuidStr];
    } else if (expr.type == kExprSubStr) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        GTWLiteral* start = (GTWLiteral*) [self evaluateExpression:expr.arguments[1] withResult:result];
        NSUInteger startloc = [start integerValue];
        NSString* substr;
        if ([expr.arguments count] > 2) {
            GTWLiteral* l = (GTWLiteral*) [self evaluateExpression:expr.arguments[2] withResult:result];
            NSUInteger length = [l integerValue];
            NSRange range       = { .location = (startloc-1), .length = (length) };
            substr    = [term.value substringWithRange: range];
        } else {
            substr    = [term.value substringFromIndex:(startloc-1)];
        }
        
        if (term.language) {
            return [[GTWLiteral alloc] initWithString:substr language:term.language];
        } else if (term.datatype) {
            return [[GTWLiteral alloc] initWithString:substr datatype:term.datatype];
        } else {
            return [[GTWLiteral alloc] initWithString:substr];
        }
    } else if (expr.type == kExprConcat) {
        NSMutableArray* array   = [NSMutableArray array];
        BOOL seen   = NO;
        NSString* datatype      = nil;
        NSString* language      = nil;
        for (id<GTWTree> t in expr.arguments) {
            id<GTWTerm> term  = [self evaluateExpression:t withResult:result];
            if (term.datatype) {
                if (!([term.datatype isEqual: @"http://www.w3.org/1999/02/22-rdf-syntax-ns#langString"] || [term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#string"])) {
                    return nil;
                }
            }
            if (!seen) {
                language    = term.language;
                datatype    = term.datatype;
            } else {
                if (![language isEqual: term.language]) {
                    language    = nil;
                }
                if (![datatype isEqual: term.datatype]) {
                    datatype    = nil;
                }
            }
            seen    = YES;
            [array addObject:term.value];
        }
        
        if (language) {
            return [[GTWLiteral alloc] initWithString:[array componentsJoinedByString:@""] language:language];
        } else if (datatype && ![datatype isEqual: @"http://www.w3.org/1999/02/22-rdf-syntax-ns#langString"]) {
            return [[GTWLiteral alloc] initWithString:[array componentsJoinedByString:@""] datatype:datatype];
        } else {
            return [[GTWLiteral alloc] initWithString:[array componentsJoinedByString:@""]];
        }
    } else if (expr.type == kExprLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if ([term isKindOfClass:[GTWLiteral class]]) {
            GTWLiteral* l   = (GTWLiteral*) term;
            NSString* lang  = l.language;
            if (!lang)
                lang    = @"";
            return [[GTWLiteral alloc] initWithString:lang];
        }
        return [[GTWLiteral alloc] initWithString:@""];
    } else if (expr.type == kExprStrEnds) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWTerm> pat     = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([term isKindOfClass:[GTWLiteral class]] && [pat isKindOfClass:[GTWLiteral class]]) {
            if ([term.value hasSuffix:pat.value]) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprStrDT) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWTerm> dt  = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([term isKindOfClass:[GTWLiteral class]] && !(term.language) && !(term.datatype)) {
            return [[GTWLiteral alloc] initWithString:term.value datatype:dt.value];
        } else {
            return nil;
        }
    } else if (expr.type == kExprStrLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWTerm> lang  = [self evaluateExpression:expr.arguments[1] withResult:result];
        if ([term isKindOfClass:[GTWLiteral class]] && !(term.language) && !(term.datatype)) {
            return [[GTWLiteral alloc] initWithString:term.value language:lang.value];
        } else {
            return nil;
        }
    } else if (expr.type == kExprIsNumeric) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (isNumeric(term)) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsLiteral) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (term && [term isKindOfClass:[GTWLiteral class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsURI) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (term && [term isKindOfClass:[GTWIRI class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsBlank) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        if (term && [term isKindOfClass:[GTWBlank class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIRI) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result];
        id<GTWTerm> base  = [self evaluateExpression:expr.arguments[1] withResult:result];
        NSURL* url  = [[NSURL alloc] initWithString:term.value relativeToURL:[NSURL URLWithString:base.value]];
        NSString* iri   = [url absoluteString];
        if (!iri)
            return nil;
        return [[GTWIRI alloc] initWithValue:iri];
    } else {
        NSLog(@"Cannot evaluate expression %@", expr);
        return nil;
    }
    return nil;
}

- (NSString*) description {
    return [self conciseDescription];
}

@end
