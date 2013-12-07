//
//  SPKSPARQLResultsCSVSerializer.m
//  SPARQLKit
//
//  Created by Gregory Williams on 12/6/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKSPARQLResultsCSVSerializer.h"

@implementation SPKSPARQLResultsCSVSerializer

- (NSData*) dataFromResults: (NSEnumerator*) results withVariables: (NSSet*) variables {
    NSMutableData* data = [NSMutableData data];
    NSMutableArray* vars    = [NSMutableArray array];
    for (id<GTWTerm> t in variables) {
        [vars addObject:t.value];
    }
    NSString* header  = [vars componentsJoinedByString:@","];
    NSData* headerData    = [header dataUsingEncoding:NSUTF8StringEncoding];
    [data appendData:headerData];
    [data appendBytes:"\n" length:1];
    NSCharacterSet* charset = [NSCharacterSet characterSetWithCharactersInString:@"\n,\""];
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
                if ([value rangeOfCharacterFromSet:charset].location == NSNotFound) {
                    [cols addObject:value];
                } else {
                    if ([value rangeOfString:@"\""].location != NSNotFound) {
                        value   = [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
                    }
                    [cols addObject:[NSString stringWithFormat:@"\"%@\"", value]];
                }
            } else {
                [cols addObject:@""];
            }
        }
        NSString* line  = [cols componentsJoinedByString:@","];
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
