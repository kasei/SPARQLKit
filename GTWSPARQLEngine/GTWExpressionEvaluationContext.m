//
//  GTWExpressionEvaluationContext.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/24/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWExpressionEvaluationContext.h"
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWVariable.h>

#include <CommonCrypto/CommonDigest.h>
#import "NSDate+W3CDTFSupport.h"

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

@implementation GTWExpressionEvaluationContext

- (id<GTWTerm>) evaluateExpression: (id<GTWTree>) expr withResult: (NSDictionary*) result usingModel: (id<GTWModel>) model {
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
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([((GTWLiteral*) lhs) booleanValue] || [((GTWLiteral*) rhs) booleanValue]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprAnd) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([((GTWLiteral*) lhs) booleanValue] && [((GTWLiteral*) rhs) booleanValue]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprEq) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        rhs = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        //        NSLog(@"%@ <=> %@", lhs, rhs);
        if ([lhs isEqual:rhs]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsURI) {
        lhs = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        //        NSLog(@"ISIRI(%@)", lhs);
        if ([lhs conformsToProtocol:@protocol(GTWIRI)]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprGe) {
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> cmp  = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
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
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> cmp  = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
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
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> cmp  = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
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
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> cmp  = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
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
        id<GTWLiteral,GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
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
        id<GTWLiteral,GTWTerm> lhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> rhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
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
    } else if (expr.type == kExprMinus) {
        // TODO: handle double and float in addition to integer
        id<GTWLiteral,GTWTerm> lhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> rhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (lhs && rhs) {
            NSInteger lhsI  = [lhs integerValue];
            NSInteger rhsI  = [rhs integerValue];
            NSInteger diff   = lhsI - rhsI;
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lu", (unsigned long) diff] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprDiv) {
        // TODO: handle double and float in addition to integer
        id<GTWLiteral,GTWTerm> lhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWLiteral,GTWTerm> rhs = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (lhs && rhs) {
            if (![lhs isKindOfClass:[GTWLiteral class]])
                return nil;
            if (![rhs isKindOfClass:[GTWLiteral class]])
                return nil;
            NSInteger lhsI  = [lhs integerValue];
            NSInteger rhsI  = [rhs integerValue];
            if (rhsI == 0)
                return nil;
            NSInteger div   = lhsI / rhsI;
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat: @"%lu", (unsigned long) div] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprStr) {
        id<GTWTerm> term = (id<GTWLiteral>)[self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        GTWLiteral* str = [[GTWLiteral alloc] initWithString:term.value];
        return str;
    } else if (expr.type == kExprReplace) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        NSString* string    = term.value;
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        id<GTWTerm> replace = [self evaluateExpression:expr.arguments[2] withResult:result usingModel: model];
        id<GTWTerm> args    = ([expr.arguments count] > 3) ? [self evaluateExpression:expr.arguments[3] withResult:result usingModel: model] : nil;
        NSInteger opt       = NSRegularExpressionSearch;
        if (args && [args.value isEqual:@"i"]) {
            opt |= NSCaseInsensitiveSearch;
        }
        NSLog(@"REPLACE string : '%@'", string);
        NSLog(@"REPLACE pattern: '%@'", pattern.value);
        NSLog(@"REPLACE value  : '%@'", replace.value);
        NSRange searchrange = { 0, [string length] };
        NSRange range       = [string rangeOfString:pattern.value options:opt range:searchrange];
        NSMutableString* newValue   = [NSMutableString stringWithString:string];
        NSMutableArray* replacements    = [NSMutableArray array];
        while (range.location != NSNotFound) {
            searchrange.location    = range.location + range.length;
            searchrange.length      = string.length - searchrange.location;
            NSLog(@"should replace '%@' => '%@'", [string substringWithRange:range], replace.value);
            
            
            // TODO: need to use capturing regex here so that instead of replace.value, we can put a new string in this array with, e.g., $1 replaced by the first capture
            [replacements addObject:@[@(range.location), @(range.length), replace.value]];
            
            
            if (searchrange.location >= [string length])
                break;
            range       = [string rangeOfString:pattern.value options:opt range:searchrange];
        }
        while ([replacements count]) {
            NSArray* r  = [replacements lastObject];
            [replacements removeLastObject];
            NSNumber* loc   = r[0];
            NSNumber* len   = r[1];
            NSRange range   = { .location = loc.integerValue, .length = len.integerValue };
            NSString* n     = r[2];
            [newValue replaceCharactersInRange:range withString:n];
        }
        return [[GTWLiteral alloc] initWithString:newValue];
    } else if (expr.type == kExprRegex) {
        //        NSLog(@"REGEX arguments: %@", expr.arguments);
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        NSString* string    = term.value;
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        id<GTWTerm> args    = ([expr.arguments count] > 2) ? [self evaluateExpression:expr.arguments[2] withResult:result usingModel: model] : nil;
        NSInteger opt       = NSRegularExpressionSearch;
        if (args && [args.value isEqual:@"i"]) {
            opt |= NSCaseInsensitiveSearch;
        }
        //        NSLog(@"regex string : '%@'", string);
        //        NSLog(@"regex pattern: '%@'", pattern.value);
        NSRange range       = [string rangeOfString:pattern.value options:opt];
        //        NSLog(@"regex location {%lu %lu}", range.location, range.length);
        if (range.location == NSNotFound) {
            return [GTWLiteral falseLiteral];
        } else {
            return [GTWLiteral trueLiteral];
        }
    } else if (expr.type == kExprLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        NSString* lang  = [term language];
        if (lang) {
            return [[GTWLiteral alloc] initWithValue:lang];
        } else {
            return nil;
        }
    } else if (expr.type == kExprLangMatches) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        NSString* lang      = term.value;
        if (lang && [lang hasPrefix:pattern.value]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
        return nil;
    } else if (expr.type == kExprStrLen) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (term && [term isKindOfClass:[GTWLiteral class]]) {
            return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%lu", [term.value length]] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else {
            return nil;
        }
    } else if (expr.type == kExprStrStarts) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (pattern.language && ![pattern.language isEqual: term.language]) {
            return nil;
        }
        
        if (term.datatype && !(term.language) && ![term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#string"]) {
            return nil;
        }
        
        NSRange range       = [term.value rangeOfString:pattern.value];
        if (range.location == 0) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprStrEnds) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (pattern.language && ![pattern.language isEqual: term.language]) {
            return nil;
        }
        
        if (term.datatype && !(term.language) && ![term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#string"]) {
            return nil;
        }
        
        NSRange range       = [term.value rangeOfString:pattern.value];
        if (range.location == NSNotFound) {
            return [GTWLiteral falseLiteral];
        } else if (range.location + range.length == [term.value length]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprStrBefore) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (pattern.language && ![pattern.language isEqual: term.language]) {
            return nil;
        }
        
        if (term.datatype && !(term.language) && ![term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#string"]) {
            return nil;
        }
        
        NSRange range       = [term.value rangeOfString:pattern.value];
        
        if (([pattern.value length] && range.location == NSNotFound) || range.location == 0) {
            return [[GTWLiteral alloc] initWithValue:@""];
        } else {
            NSString* substr;
            if ([pattern.value length] > 0) {
                NSRange before      = { .location = 0, .length = range.location };
                substr  = [term.value substringWithRange:before];
            } else {
                substr  = @"";
            }
            if (term.language) {
                return [[GTWLiteral alloc] initWithString:substr language:term.language];
            } else if (term.datatype) {
                return [[GTWLiteral alloc] initWithString:substr datatype:term.datatype];
            } else {
                return [[GTWLiteral alloc] initWithValue:substr];
            }
        }
    } else if (expr.type == kExprStrAfter) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pattern = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if (pattern.language && ![pattern.language isEqual: term.language]) {
            return nil;
        }
        
        if (term.datatype && !(term.language) && ![term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#string"]) {
            return nil;
        }
        
        NSRange range       = [term.value rangeOfString:pattern.value];
        
        if ([pattern.value length] && range.location == NSNotFound) {
            return [[GTWLiteral alloc] initWithValue:@""];
        } else {
            NSString* substr;
            if ([pattern.value length] > 0) {
                substr  = [term.value substringFromIndex:range.location+range.length];
            } else {
                return term;
            }
            if (term.language) {
                return [[GTWLiteral alloc] initWithString:substr language:term.language];
            } else if (term.datatype) {
                return [[GTWLiteral alloc] initWithString:substr datatype:term.datatype];
            } else {
                return [[GTWLiteral alloc] initWithValue:substr];
            }
        }
    } else if (expr.type == kExprSHA1 || expr.type == kExprSHA224 || expr.type == kExprSHA256 || expr.type == kExprSHA512 || expr.type == kExprMD5) {
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
        } else if (expr.type == kExprMD5) {
            SHA_FUNC    = CC_MD5;
            dataLength  = CC_MD5_DIGEST_LENGTH;
        }
        
        if (dataLength == 0) {
            return nil;
        }
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
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
    } else if (expr.type == kExprNow) {
        NSDate* date    = [[NSDate alloc] init];
        id<GTWTerm> now = [[GTWLiteral alloc] initWithString:[date getW3CDTFString] datatype:@"http://www.w3.org/2001/XMLSchema#dateTime"];
        NSLog(@"%@", now);
        return now;
    } else if (expr.type == kExprYear || expr.type == kExprMonth || expr.type == kExprDay || expr.type == kExprHours || expr.type == kExprMinutes || expr.type == kExprSeconds || expr.type == kExprTZ || expr.type == kExprTimeZone) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (term && [term isKindOfClass:[GTWLiteral class]] && [term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#dateTime"]) {
            NSTimeZone* tz  = nil;
            NSDate* date    = [NSDate dateWithW3CDTFString:term.value havingTimeZone:&tz];
            //            NSLog(@"date function date: %@ (%@)", date, term.value);
            if (!date)
                return nil;
            
            if (expr.type == kExprTZ || expr.type == kExprTimeZone) {
                if (!([term.datatype isEqual: @"http://www.w3.org/2001/XMLSchema#dateTime"])) {
                    return nil;
                }
                
                if (expr.type == kExprTimeZone) {
                    if (!tz)
                        return nil;
                    NSMutableString* value  = [NSMutableString string];
                    NSInteger seconds   = [tz secondsFromGMT];
                    if (seconds < 0) {
                        [value appendString:@"-"];
                        seconds = -seconds;
                    }
                    [value appendString:@"PT"];
                    NSInteger hours = seconds / 3600;
                    seconds    = seconds % 3600;
                    if (hours > 0) {
                        [value appendFormat:@"%dH", (int) hours];
                    }
                    
                    NSInteger minutes   = seconds / 60;
                    if (minutes > 0) {
                        [value appendFormat:@"%dM", (int) minutes];
                    }
                    if ([value isEqual: @"PT"])
                        [value appendString:@"0S"];
                    return [[GTWLiteral alloc] initWithString:value datatype:@"http://www.w3.org/2001/XMLSchema#dayTimeDuration"];
                } else {
                    if (tz) {
                        NSMutableString* value  = [NSMutableString string];
                        NSInteger seconds   = [tz secondsFromGMT];
                        if (seconds < 0) {
                            [value appendString:@"-"];
                            seconds = -seconds;
                        }
                        if (seconds > 3600) {
                            NSInteger hours = seconds / 3600;
                            seconds    = seconds % 3600;
                            [value appendFormat:@"%02d:", (int) hours];
                        } else {
                            [value appendString:@"00:"];
                        }
                        
                        NSInteger minutes   = seconds / 60;
                        [value appendFormat:@"%02d", (int) minutes];
                        if ([value isEqual: @"00:00"])
                            [value setString:@"Z"];
                        return [[GTWLiteral alloc] initWithString:value];
                    } else {
                        return [[GTWLiteral alloc] initWithString:@""];
                    }
                }
            }
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setLocale:[NSLocale systemLocale]];
            [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            NSString* format    = @"";
            NSString* datatype  = @"http://www.w3.org/2001/XMLSchema#integer";
            if (expr.type == kExprYear) {
                format= @"yyyy";
            } else if (expr.type == kExprMonth) {
                format= @"MM";
            } else if (expr.type == kExprDay) {
                format= @"dd";
            } else if (expr.type == kExprHours) {
                format= @"H";
            } else if (expr.type == kExprMinutes) {
                format= @"mm";
            } else if (expr.type == kExprSeconds) {
                format= @"ss.SSSS";
                datatype  = @"http://www.w3.org/2001/XMLSchema#decimal";
            }
            [dateFormatter setDateFormat:format];
            NSString* value;
            if (tz) {
                NSInteger seconds   = [tz secondsFromGMT];
                if (seconds != 0) {
                    date    = [NSDate dateWithTimeInterval:seconds sinceDate:date];
                    //                    NSLog(@"timezone adjusted date: %@", date);
                }
            }
            value  = [dateFormatter stringFromDate:date];
            return [[GTWLiteral alloc] initWithString:value datatype:datatype];
        }
        return nil;
    } else if (expr.type == kExprSubStr) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        GTWLiteral* start = (GTWLiteral*) [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        NSUInteger startloc = [start integerValue];
        NSString* substr;
        if ([expr.arguments count] > 2) {
            GTWLiteral* l = (GTWLiteral*) [self evaluateExpression:expr.arguments[2] withResult:result usingModel: model];
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
    } else if (expr.type == kExprIf) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (!term)
            return nil;
        if ([term respondsToSelector:@selector(booleanValue)] && [(id<GTWLiteral>)term booleanValue]) {
            return [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        } else {
            return [self evaluateExpression:expr.arguments[2] withResult:result usingModel: model];
        }
    } else if (expr.type == kExprCoalesce) {
        for (id<GTWTree> t in expr.arguments) {
            id<GTWTerm> term  = [self evaluateExpression:t withResult:result usingModel: model];
            if (term)
                return term;
        }
        return nil;
    } else if (expr.type == kExprConcat) {
        NSMutableArray* array   = [NSMutableArray array];
        BOOL seen   = NO;
        NSString* datatype      = nil;
        NSString* language      = nil;
        for (id<GTWTree> t in expr.arguments) {
            id<GTWTerm> term  = [self evaluateExpression:t withResult:result usingModel: model];
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
    } else if (expr.type == kExprDatatype) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]]) {
            GTWLiteral* l   = (GTWLiteral*) term;
            NSString* dt    = l.datatype;
            if (!dt)
                dt    = @"";
            return [[GTWIRI alloc] initWithValue:dt];
        }
        return nil;
    } else if (expr.type == kExprLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]]) {
            GTWLiteral* l   = (GTWLiteral*) term;
            NSString* lang  = l.language;
            if (!lang)
                lang    = @"";
            return [[GTWLiteral alloc] initWithString:lang];
        }
        return [[GTWLiteral alloc] initWithString:@""];
    } else if (expr.type == kExprStrEnds) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pat     = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]] && [pat isKindOfClass:[GTWLiteral class]]) {
            if ([term.value hasSuffix:pat.value]) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprStrDT) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> dt      = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]] && !(term.language) && !(term.datatype)) {
            return [[GTWLiteral alloc] initWithString:term.value datatype:dt.value];
        } else {
            return nil;
        }
    } else if (expr.type == kExprStrLang) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> lang  = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]] && !(term.language) && !(term.datatype)) {
            return [[GTWLiteral alloc] initWithString:term.value language:lang.value];
        } else {
            return nil;
        }
    } else if (expr.type == kExprIsNumeric) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (isNumeric(term)) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsLiteral) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (term && [term isKindOfClass:[GTWLiteral class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsURI) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (term && [term isKindOfClass:[GTWIRI class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprIsBlank) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        if (term && [term isKindOfClass:[GTWBlank class]]) {
            return [GTWLiteral trueLiteral];
        } else {
            return [GTWLiteral falseLiteral];
        }
    } else if (expr.type == kExprBNode) {
        if ([expr.arguments count] == 0) {
            NSUInteger ident    = self.bnodeID++;
            GTWBlank* b  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"B%lu", ident]];
            return b;
        } else {
            id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
            NSUInteger rHash    = [[result description] hash];
            NSUInteger bHash    = [term.value hash];
            GTWBlank* b  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"B%lu-%lu", rHash, bHash]];
            return b;
        }
    } else if (expr.type == kExprIRI) {
        id<GTWTerm> term  = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> base  = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        NSURL* url  = [[NSURL alloc] initWithString:term.value relativeToURL:[NSURL URLWithString:base.value]];
        NSString* iri   = [url absoluteString];
        if (!iri)
            return nil;
        return [[GTWIRI alloc] initWithValue:iri];
    } else if (expr.type == kExprUCase) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        NSString* value     = [term.value uppercaseString];
        if (term.language) {
            return [[GTWLiteral alloc] initWithString:value language:term.language];
        } else {
            return [[GTWLiteral alloc] initWithString:value datatype:term.datatype];
        }
    } else if (expr.type == kExprLCase) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        NSString* value     = [term.value lowercaseString];
        if (term.language) {
            return [[GTWLiteral alloc] initWithString:value language:term.language];
        } else {
            return [[GTWLiteral alloc] initWithString:value datatype:term.datatype];
        }
    } else if (expr.type == kExprContains) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTerm> pat     = [self evaluateExpression:expr.arguments[1] withResult:result usingModel: model];
        if ([term isKindOfClass:[GTWLiteral class]] && [pat isKindOfClass:[GTWLiteral class]]) {
            // TODO: return nil if the two terms aren't 'argument compatible'
            NSRange range       = [term.value rangeOfString:pat.value options:0];
            if (range.location != NSNotFound) {
                return [GTWLiteral trueLiteral];
            } else {
                return [GTWLiteral falseLiteral];
            }
        }
        return nil;
    } else if (expr.type == kExprExists) {
        // TODO: the EXISTS pattern isn't planned at this point.
        // needs to be planned and then have a way to call back into the query engine (not just access to the model)
        NSLog(@"Evaluating ExprExists expressions not implemented yet: %@", expr);
        return nil;
    } else if (expr.type == kExprIn) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTree> list    = expr.arguments[1];
        for (id<GTWTree> t in list.arguments) {
            id<GTWTerm> tn  = [self evaluateExpression:t withResult:result usingModel: model];
            if ([term isEqual:tn]) {
                return [GTWLiteral trueLiteral];
            }
        }
        return [GTWLiteral falseLiteral];
    } else if (expr.type == kExprNotIn) {
        id<GTWTerm> term    = [self evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
        id<GTWTree> list    = expr.arguments[1];
        for (id<GTWTree> t in list.arguments) {
            id<GTWTerm> tn  = [self evaluateExpression:t withResult:result usingModel: model];
            if ([term isEqual:tn]) {
                return [GTWLiteral falseLiteral];
            }
        }
        return [GTWLiteral trueLiteral];
    } else {
        NSLog(@"Cannot evaluate expression %@", expr);
        return nil;
    }
    return nil;
}

@end
