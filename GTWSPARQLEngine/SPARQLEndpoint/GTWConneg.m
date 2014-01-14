//
//  GTWConneg.m
//  GTWConneg
//
//  Created by Gregory Williams on 1/13/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import "GTWConneg.h"

NSString* __strong const kSPKConnegQuality      = @"Quality";
NSString* __strong const kSPKConnegType         = @"Content-Type";
NSString* __strong const kSPKConnegEncoding     = @"Encoding";
NSString* __strong const kSPKConnegCharacterSet = @"Character-Set";
NSString* __strong const kSPKConnegLanguage     = @"Language";
NSString* __strong const kSPKConnegSize         = @"Size";

@implementation GTWConneg

NSDictionary* GTWMakeVariant(double qv, NSString* contentType, id encoding, NSString* characterSet, NSString* langauge, NSInteger size) {
    NSMutableDictionary* v  = [@{
                                kSPKConnegQuality:@(qv),
                                kSPKConnegSize:@(size)
                                } mutableCopy];
    if (contentType)
        v[kSPKConnegType]           = contentType;
    if (encoding)
        v[kSPKConnegEncoding]       = encoding;
    if (encoding)
        v[kSPKConnegCharacterSet]   = characterSet;
    if (langauge)
        v[kSPKConnegLanguage]       = langauge;
    return [v copy];
}

- (NSArray*) negotiateWithRequest:(NSURLRequest*)req withVariants:(NSDictionary*)variants {
    NSDictionary* headers       = [req allHTTPHeaderFields];
    NSMutableDictionary* accept = [NSMutableDictionary dictionary];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* val, BOOL *stop) {
        NSString* type;
        if ([key hasPrefix:@"Accept-"]) {
            type  = [[key substringFromIndex:7] lowercaseString];
        } else if ([key isEqualToString:@"Accept"]) {
            type    = @"type";
        } else {
            return;
        }
        
        val = [[val componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
//        val = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double default_q = 1.0;
        NSArray* array  = [val componentsSeparatedByString:@","];
        for (NSString* name in array) {
            NSString* lcname;
            NSMutableDictionary* param  = [NSMutableDictionary dictionary];
            NSRange range   = [name rangeOfString:@";"];
            if (range.location != NSNotFound) {
                NSString* p = [name substringFromIndex:range.location+1];
                NSArray* params = [p componentsSeparatedByString:@";"];
                for (NSString* string in params) {
                    NSArray* pair   = [string componentsSeparatedByPattern:@"=" maximumItems:2];
                    NSString* pk    = pair[0];
                    NSString* pv    = pair[1];
                    param[[pk lowercaseString]] = pv;
                }
                lcname    = [[name substringToIndex:range.location] lowercaseString];
            } else {
                lcname    = [name lowercaseString];
            }
            NSString* q         = param[@"q"];
            if (q) {
                double qv    = atof([q UTF8String]);
                if (qv > 1.0)
                    param[@"q"] = @"1.0";
                if (qv < 0.0)
                    param[@"q"] = @"0.0";
            } else {
                param[@"q"] = [NSString stringWithFormat:@"%.4lf", default_q];
                //# This makes sure that the first ones are slightly better off
                //# and therefore more likely to be chosen.
                default_q -= 0.0001;
            }
            NSMutableDictionary* d  = accept[type];
            if (!d) {
                d   = [NSMutableDictionary dictionary];
                accept[type]    = d;
            }
            d[lcname] = param;
        }
    }];
    
    BOOL any_lang   = NO;
    for (id key in variants) {
        NSDictionary* var    = variants[key];
        NSString* lang      = var[kSPKConnegLanguage];
        if (lang) {
            any_lang    = YES;
            break;
        }
    }
    
    BOOL verbose    = YES;
    if (verbose) {
        NSLog(@"Negotiation parameters in the request\n");
        for (id type in accept) {
            NSLog(@"%@:", type);
            NSDictionary* dict  = accept[type];
            for (id name in dict) {
                NSLog(@"    %@", name);
                NSDictionary* subdict   = dict[name];
                for (id pv in subdict) {
                    NSLog(@"        %@ = %@", pv, subdict[pv]);
                }
            }
        }
    }
    
    
    NSMutableArray* Q   = [NSMutableArray array];
    for (id key in variants) {
        NSDictionary* var    = variants[key];
        NSNumber* qs    = var[kSPKConnegQuality];
        NSString* ct    = var[kSPKConnegType];
        id enc          = var[kSPKConnegEncoding];
        NSString* cs    = var[kSPKConnegCharacterSet];
        id lang         = var[kSPKConnegLanguage];
        NSNumber* bs    = var[kSPKConnegSize];
        
        if (!qs || [qs doubleValue] == 0.0)
            qs  = @(1.0);
        if (!ct)
            ct  = @"";
        if (!bs)
            bs  = @(0);
        if (lang)
            lang    = [lang lowercaseString];
        
        if (verbose) {
            NSLog(@"\nEvaluating %@ (ct=%@)\n", key, ct);
            NSLog(@"  qs   = %@\n", qs);
            NSLog(@"  enc  = %@\n", enc);
            NSLog(@"  cs   = %@\n", cs);
            NSLog(@"  lang = %@\n", lang);
            NSLog(@"  bs   = %@\n", bs);
        }
        
        double qe    = 1.0;
        NSDictionary* encoding  = accept[@"encoding"];
        if (encoding && enc) {
            NSArray* encodings    = [enc isKindOfClass:[NSArray class]] ? enc : @[enc];
            for (NSString* e in encodings) {
                if (verbose)
                    NSLog(@"Is encoding %@ accepted? ", e);
                id aeval    = encoding[e];
                if (!aeval) {
                    if (verbose)
                        NSLog(@"... no");
                    qe  = 0.0;
                    break;
                } else {
                    if (verbose)
                        NSLog(@"... yes");
                }
            }
        }
        
        double qc    = 1.0;
        NSDictionary* charset  = accept[@"charset"];
        if (charset && cs && ![cs isEqualToString:@"us-ascii"]) {
            id csval    = charset[cs];
            if (!csval)
                qc  = 0.0;
        }
        
        double ql    = 1.0;
        NSDictionary* language  = accept[@"language"];
        if (lang && language && [lang length]) {
            NSArray* langArray   = [lang isKindOfClass:[NSArray class]] ? lang : @[lang];
            NSString* q;
            for (id l in langArray) {
                if (!language[l])
                    continue;
                NSString* this_q   = language[l][@"q"];
                if (!q) {
                    NSLog(@"---> language: %@", l);
                    q   = this_q;
                }
                
                double this_qv  = atof([this_q UTF8String]);
                double qv       = atof([q UTF8String]);
                
                if (this_qv > qv) {
                    NSLog(@"---> language: %@", l);
                    q   = this_q;
                }
            }
            if (q) {
                if (verbose) {
                    NSLog(@" -- Exact language match at q=%@\n", q);
                }
            } else {
                NSLog(@" -- No exact language match\n");
                id selected;
                for (id al in language) {
                    if ([al hasPrefix:[NSString stringWithFormat:@"%@-", lang]]) {
                        NSLog(@" -- %@ ISA %@\n", al, lang);
                        if (!selected) {
                            selected    = al;
                        }
                        if ([al length] > [selected length]) {
                            selected    = al;
                        }
                    } else {
                        NSLog(@" -- %@ isn't a %@\n", lang, al);
                    }
                }
                if (selected) {
                    q   = language[selected][@"q"];
                }
                if (!q) {
                    q   = @"0.001";
                }
            }
            ql  = atof([q UTF8String]);
        } else {
            if (any_lang && language) {
                ql  = 0.5;
            }
        }
        
        double q    = 1.0;
        id mbx;
        if (accept[@"type"] && ct && [ct length]) {
            ct  = [ct stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString* params = [NSMutableString string];
            NSRange semi_range   = [ct rangeOfString:@";"];
            if (semi_range.location != NSNotFound) {
                params  = [ct substringFromIndex:semi_range.location+1];
            }
            
            NSArray* pair       = [ct componentsSeparatedByPattern:@"/" maximumItems:2];
            NSString* type      = pair[0];
            NSString* subtype   = pair[1];
            NSMutableDictionary* param  = [NSMutableDictionary dictionary];
            NSArray* array  = [params componentsSeparatedByString:@";"];
            if ([array count] == 2) {
                for (NSString* p in array) {
                    NSArray* pair       = [p componentsSeparatedByPattern:@"=" maximumItems:2];
                    NSLog(@"%@ => %@", p, pair);
                    NSString* pk    = pair[0];
                    NSString* pv    = pair[1];
                    param[pk]   = pv;
                }
            }
            
            NSString* sel_q;
            NSString* sel_mbx;
            double sel_specificness = 0.0;
            // 	    ACCEPT_TYPE:
            BOOL goto_next  = NO;
            for (id at in accept[@"type"]) {
                goto_next  = NO;
                if (verbose) {
                    NSLog(@"Consider %@...\n", at);
                }
                NSArray* pair           = [at componentsSeparatedByPattern:@"/" maximumItems:2];
                NSString* at_type       = pair[0];
                NSString* at_subtype    = pair[1];
                
                if (![at_type isEqualToString:@"*"] && ![at_type isEqualToString:type])
                    continue;
                if (![at_subtype isEqualToString:@"*"] && ![at_subtype isEqualToString:subtype])
                    continue;
                
                double specificness     = 0.0;
                if (![at_type isEqualToString:@"*"])
                    specificness++;
                if (![at_subtype isEqualToString:@"*"])
                    specificness++;
                for (NSString* pk in param) {
                    NSString* pv    = param[pk];
                    if (verbose) {
                        NSLog(@"Check if %@ = %@ is true\n", pk, pv);
                    }
                    if (!accept[@"type"][at][pk])
                        continue;
                    if (![pv isEqualToString:accept[@"type"][at][pk]]) {
                        goto_next   = YES;
                    }
                    if (!goto_next) {
                        if (verbose) {
                            NSLog(@"yes it is!!\n");
                        }
                        specificness++;
                    }
                }
                
                if (!goto_next) {
                    if (verbose) {
                        NSLog(@"Hurray, type match with specificness = %.4f\n", specificness);
                    }
                    
                    if (!sel_q || (sel_specificness < specificness)) {
                        sel_q   = accept[@"type"][at][@"q"];
                        sel_mbx = accept[@"type"][at][@"mbx"];
                        sel_specificness    = specificness;
                    }
                }
            }
            NSLog(@"SEL_Q: %@", sel_q);
            q   = sel_q ? atof([sel_q UTF8String]) : 0;
            mbx = sel_mbx;
        }
        
        double qv;
        if (!mbx || (atof([mbx UTF8String]) >= [bs doubleValue])) {
            qv    = [qs doubleValue] * qe * qc * ql * q;
        } else {
            if (verbose) {
                NSLog(@"Variant's size is too large ==> Q=0\n");
            }
            qv  = 0;
        }

        if (verbose) {
            NSLog(@"Q=%.4f   (q=%.4f, qe=%.4f, qc=%.4f, ql=%.4f, qs=%@", qv, q, qe, qc, ql, qs);
        }
        
        [Q addObject:@[key, @(qv), bs]];
    }
    
    NSArray* sorted = [Q sortedArrayUsingComparator:^NSComparisonResult(NSArray* obj1, NSArray* obj2) {
        NSNumber* a = obj1[1];
        NSNumber* b = obj2[1];
        NSComparisonResult r    = [b compare:a];
        if (r != NSOrderedSame)
            return r;
        return [obj1[2] compare:obj2[2]];
    }];
    
    return sorted;
}

@end
