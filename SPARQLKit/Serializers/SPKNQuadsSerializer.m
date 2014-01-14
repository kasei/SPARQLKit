//
//  SPKNQuadsSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKNQuadsSerializer.h"

@implementation SPKNQuadsSerializer

+ (unsigned)interfaceVersion {
    return 0;
}

+ (NSSet*) handledSerializerMediaTypes {
    return [NSSet setWithObject:@"application/n-quads"];
}

+ (NSString*) preferredMediaTypes {
    return @"application/n-quads";
}

+ (NSDictionary*) classesImplementingProtocols {
    return @{ (id)self: [self implementedProtocols] };
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWQuadsSerializer), @protocol(GTWMixedSerializer), nil];
}

- (SPKNQuadsSerializer*) init {
    if (self = [super init]) {
        self.escapeUnicode  = YES;
    }
    return self;
}

- (NSData*) dataFromEnumerator: (NSEnumerator*) quads {
    return [self dataFromQuads:quads];
}

- (NSData*) dataFromQuads: (NSEnumerator*) quads {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.subject escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.predicate escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.object escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.graph escapingUnicode:self.escapeUnicode]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeQuads: (NSEnumerator*) quads toHandle: (NSFileHandle*) handle {
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.subject escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.predicate escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.object escapingUnicode:self.escapeUnicode], [SPKNTriplesSerializer nTriplesEncodingOfTerm:q.graph escapingUnicode:self.escapeUnicode]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
