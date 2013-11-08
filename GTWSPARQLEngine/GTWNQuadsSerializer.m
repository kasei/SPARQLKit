//
//  GTWNQuadsSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWNQuadsSerializer.h"

@implementation GTWNQuadsSerializer

+ (NSString*) nQuadsEncodingOfString: (NSString*) value {
    NSUInteger length   = [value length];
    unichar* string = alloca(10*length);
    NSUInteger src  = 0;
    NSUInteger dst  = 0;
    char* buffer    = alloca(9);
    int i;
    for (src = 0; src < length; src++) {
        uint32_t c = [value characterAtIndex:src];
        if ((c & 0xFC00) == 0xD800) {
            unichar c2  = [value characterAtIndex:++src];
            c = (((c & 0x3FF) << 10) | (c2 & 0x3FF)) + 0x10000;
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

+ (NSString*) nQuadsEncodingOfTerm: (id<GTWTerm>) term {
    NSString* serialized;
    switch (term.termType) {
        case GTWTermBlank:
            return [term description];
        case GTWTermLiteral:
            serialized   = [self nQuadsEncodingOfString: term.value];
            if (term.language) {
                return [NSString stringWithFormat:@"\"%@\"@%@", serialized, term.language];
            } else if (term.datatype) {
                return [NSString stringWithFormat:@"\"%@\"^^<%@>", serialized, term.datatype];
            } else {
                return [NSString stringWithFormat:@"\"%@\"", serialized];
            }
        case GTWTermIRI:
            return [NSString stringWithFormat:@"<%@>", [self nQuadsEncodingOfString: term.value]];
        default:
            return nil;
    }
}

- (NSData*) dataFromEnumerator: (NSEnumerator*) quads {
    return [self dataFromQuads:quads];
}

- (NSData*) dataFromQuads: (NSEnumerator*) quads {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [[self class] nQuadsEncodingOfTerm:q.subject], [[self class] nQuadsEncodingOfTerm:q.predicate], [[self class] nQuadsEncodingOfTerm:q.object], [[self class] nQuadsEncodingOfTerm:q.graph]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeQuads: (NSEnumerator*) quads toHandle: (NSFileHandle*) handle {
    for (id<GTWQuad> q in quads) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ %@ .\n", [[self class] nQuadsEncodingOfTerm:q.subject], [[self class] nQuadsEncodingOfTerm:q.predicate], [[self class] nQuadsEncodingOfTerm:q.object], [[self class] nQuadsEncodingOfTerm:q.graph]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
