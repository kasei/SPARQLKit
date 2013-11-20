//
//  SPKNQuadsSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKNQuadsSerializer.h"

@implementation SPKNQuadsSerializer

- (NSData*) dataFromEnumerator: (NSEnumerator*) quads {
    return [self dataFromQuads:quads];
}

- (NSData*) dataFromQuads: (NSEnumerator*) quads {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.subject], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.predicate], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.object], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.graph]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeQuads: (NSEnumerator*) quads toHandle: (NSFileHandle*) handle {
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.subject], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.predicate], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.object], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.graph]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
