//
//  SPKNTriplesSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/12/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKNTriplesSerializer.h"

@implementation SPKNTriplesSerializer

+ (NSString*) nTriplesEncodingOfString: (NSString*) value {
    NSUInteger length   = [value length];
    unichar* string = alloca(1+10*length);
    NSUInteger src  = 0;
    NSUInteger dst  = 0;
    char* buffer    = alloca(9);
    int i;
    for (src = 0; src < length; src++) {
        uint32_t c = [value characterAtIndex:src];
        if ((c & 0xFC00) == 0xD800) {
            if ((1+src) < length) {
                unichar c2  = [value characterAtIndex:++src];
                c = (((c & 0x3FF) << 10) | (c2 & 0x3FF)) + 0x10000;
            } else {
                string[dst++]   = '\\';
                string[dst++]   = 'u';
                string[dst++]   = 'F';
                string[dst++]   = 'F';
                string[dst++]   = 'F';
                string[dst++]   = 'D';
                NSLog(@"inserting replacement character");
                break;
            }
        }
        
        switch (c) {
            case 0x09:
                string[dst++]   = '\\';
                string[dst++]   = 't';
                break;
            case 0x0A:
                string[dst++]   = '\\';
                string[dst++]   = 'n';
                break;
            case 0x0D:
                string[dst++]   = '\\';
                string[dst++]   = 'r';
                break;
            case 0x22:
                string[dst++]   = '\\';
                string[dst++]   = '"';
                break;
            case 0x5C:
                string[dst++]   = '\\';
                string[dst++]   = '\\';
                break;
            default:
                if (c <= 0x1F) {
                    string[dst++]   = '\\';
                    string[dst++]   = 'u';
                    sprintf(buffer, "%04X", c);
                    for (i = 0; i < 4; i++) {
                        string[dst++]   = buffer[i];
                    }
                } else if (c <= 0x7E) {
                    string[dst++]   = c;
                } else if (c <= 0xFFFF) {
                    string[dst++]   = '\\';
                    string[dst++]   = 'u';
                    sprintf(buffer, "%04X", c);
                    for (i = 0; i < 4; i++) {
                        string[dst++]   = buffer[i];
                    }
                } else {
                    string[dst++]   = '\\';
                    string[dst++]   = 'U';
                    sprintf(buffer, "%08X", c);
                    for (i = 0; i < 8; i++) {
                        string[dst++]   = buffer[i];
                    }
                }
                break;
        }
    }
    
    return [NSString stringWithCharacters:string length:dst];
}

+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term {
    NSString* serialized;
    switch (term.termType) {
        case GTWTermBlank:
            return [term description];
        case GTWTermLiteral:
            serialized   = [self nTriplesEncodingOfString: term.value];
            if (term.language) {
                return [NSString stringWithFormat:@"\"%@\"@%@", serialized, term.language];
            } else if (term.datatype) {
                return [NSString stringWithFormat:@"\"%@\"^^<%@>", serialized, term.datatype];
            } else {
                return [NSString stringWithFormat:@"\"%@\"", serialized];
            }
        case GTWTermIRI:
            return [NSString stringWithFormat:@"<%@>", [self nTriplesEncodingOfString: term.value]];
        default:
            return nil;
    }
}

- (NSData*) dataFromEnumerator: (NSEnumerator*) triples {
    return [self dataFromTriples:triples];
}

- (NSData*) dataFromTriples: (NSEnumerator*) triples {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWTriple> t in triples) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ .\n", [[self class] nTriplesEncodingOfTerm:t.subject], [[self class] nTriplesEncodingOfTerm:t.predicate], [[self class] nTriplesEncodingOfTerm:t.object]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeTriples: (NSEnumerator*) triples toHandle: (NSFileHandle*) handle {
    for (id<GTWTriple> t in triples) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ .\n", [[self class] nTriplesEncodingOfTerm:t.subject], [[self class] nTriplesEncodingOfTerm:t.predicate], [[self class] nTriplesEncodingOfTerm:t.object]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
