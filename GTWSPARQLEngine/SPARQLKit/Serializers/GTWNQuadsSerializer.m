//
//  GTWNQuadsSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWNQuadsSerializer.h"

@implementation GTWNQuadsSerializer

- (NSData*) dataFromEnumerator: (NSEnumerator*) quads {
    return [self dataFromQuads:quads];
}

- (NSData*) dataFromQuads: (NSEnumerator*) quads {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.subject], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.predicate], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.object], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.graph]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeQuads: (NSEnumerator*) quads toHandle: (NSFileHandle*) handle {
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.subject], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.predicate], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.object], [GTWNTriplesSerializer nTriplesEncodingOfTerm:q.graph]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
