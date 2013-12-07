//
//  SPKSPARQLResultsTextTableSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKSPARQLResultsTextTableSerializer.h"
#import <GTWSWBase/GTWLiteral.h>

@implementation SPKSPARQLResultsTextTableSerializer

- (void) serializeResults: (NSEnumerator*) results withVariables: (NSSet*) variables toHandle: (NSFileHandle*) handle {
    NSData* data    = [self dataFromResults:results withVariables:variables];
    [handle writeData:data];
}

- (NSString*) stringForTerm: (id<GTWTerm>) term {
    if (!term)
        return @"";
    if (self.delegate) {
        NSString* value;
        if (self.delegate) {
            value   = [self.delegate stringFromObject:term];
            if (value)
                return value;
        }
    }
    
    if ([term isKindOfClass:[GTWLiteral class]]) {
        id<GTWLiteral> l    = (id<GTWLiteral>) term;
        if ([l isNumericLiteral]) {
            if ([l.datatype isEqualToString:@"http://www.w3.org/2001/XMLSchema#integer"]) {
                return [NSString stringWithFormat:@"%lld", (long long) [l integerValue]];
            }
        }
    }
    return [term description];
}

- (NSData*) dataFromResults: r withVariables: (NSSet*) variables {
    NSArray* results    = [r allObjects];
    NSMutableData* data = [NSMutableData data];
    
    NSArray* vars       = [[variables objectEnumerator] allObjects];
    int i;
    unsigned long* col_widths = alloca(sizeof(unsigned long) * [variables count]);
    NSUInteger count    = [vars count];
    
    for (i = 0; i < count; i++) {
        NSString* vname = [vars[i] value];
        col_widths[i]   = [vname length];
    }
    for (NSDictionary* r in results) {
        for (i = 0; i < count; i++) {
            NSString* vname = [vars[i] value];
            id<GTWTerm> t   = r[vname];
            if (t) {
                NSString* value = [self stringForTerm:t];
                if (col_widths[i] < [value length]) {
                    col_widths[i]   = [value length];
                }
//                col_widths[i]   = MAX(col_widths[i], [value length]);
            }
        }
    }
    
    int count_length = ([results count] == 0 ? 1 : (int)(log10([results count])+1));
    NSUInteger total    = 3 + count_length + 2;
    for (i = 0; i < count; i++) {
        total   += col_widths[i] + 3;
    }
    
    for (i = 1; i < total; i++) [data appendBytes:"-" length:1]; [data appendBytes:"\n" length:1];
    [data appendData:[[NSString stringWithFormat:@"| %*s | ", count_length, "#"] dataUsingEncoding:NSUTF8StringEncoding]];
    for (i = 0; i < count; i++) {
        NSString* vname = [vars[i] value];
        [data appendData:[[NSString stringWithFormat:@"%-*s | ", (int) col_widths[i], [vname UTF8String]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [data appendBytes:"\n" length:1];
    for (i = 1; i < total; i++) [data appendBytes:"-" length:1]; [data appendBytes:"\n" length:1];
    
    int result_count = 0;
    for (NSDictionary* r in results) {
        [data appendData:[[NSString stringWithFormat:@"| %*d | ", count_length, ++result_count] dataUsingEncoding:NSUTF8StringEncoding]];
        for (i = 0; i < count; i++) {
            NSString* vname = [vars[i] value];
            id<GTWTerm> t   = r[vname];
            NSString* value = [self stringForTerm:t];
            
            {
                NSInteger j;
                int length  = (int) [value length];
                [data appendBytes:[value UTF8String] length:[value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
                for (j = length; j < col_widths[i]; j++) {
                    [data appendBytes:" " length:1];
                }
                //        [data appendData:[[NSString stringWithFormat:@"%*s", count_length, "#"] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            [data appendBytes:" | " length:3];
        }
        [data appendBytes:"\n" length:1];
    }
    for (i = 1; i < total; i++) [data appendBytes:"-" length:1]; [data appendBytes:"\n" length:1];
    return data;
}

@end
