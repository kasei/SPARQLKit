//
//  SPKSPARQLResultsTSVSerializer.m
//  SPARQLKit
//
//  Created by Gregory Williams on 12/6/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKSPARQLResultsTSVSerializer.h"

@implementation SPKSPARQLResultsTSVSerializer

- (NSData*) dataFromResults: (NSEnumerator*) results withVariables: (NSSet*) variables {
    NSMutableData* data = [NSMutableData data];
    NSMutableArray* vars    = [NSMutableArray array];
    for (id<GTWTerm> t in variables) {
        [vars addObject:t.value];
    }
    NSString* header  = [vars componentsJoinedByString:@"\t"];
    NSData* headerData    = [header dataUsingEncoding:NSUTF8StringEncoding];
    [data appendData:headerData];
    NSString* invalid   = [NSString stringWithUTF8String:"\xEF\xBF\xAF"];
    [data appendBytes:"\n" length:1];
    for (NSDictionary* r in results) {
        NSMutableArray* cols    = [NSMutableArray array];
        for (NSString* v in vars) {
            id<GTWTerm> term    = r[v];
            if (term) {
                NSString* value;
                if (self.delegate) {
                    value   = [self.delegate stringFromObject:term];
                }
                if (!value) {
                    value = term.value;
                }
                if ([value rangeOfString:@"\t"].location != NSNotFound) {
                    value   = [value stringByReplacingOccurrencesOfString:@"\t" withString:invalid];
                }
                [cols addObject:value];
            } else {
                [cols addObject:@""];
            }
        }
        NSString* line  = [cols componentsJoinedByString:@"\t"];
        NSData* lineData    = [line dataUsingEncoding:NSUTF8StringEncoding];
        [data appendData:lineData];
        [data appendBytes:"\n" length:1];
    }
    return [data copy];
}

- (void) serializeResults: (NSEnumerator*) results withVariables: (NSSet*) variables toHandle: (NSFileHandle*) handle {
    NSData* data    = [self dataFromResults:results withVariables:variables];
    [handle writeData:data];
}

@end
