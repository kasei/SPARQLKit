//
//  SPKNTriplesSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/12/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKNTriplesSerializer.h"

@implementation SPKNTriplesSerializer

+ (unsigned)interfaceVersion {
    return 0;
}

+ (NSSet*) handledSerializerMediaTypes {
    return [NSSet setWithObject:@"application/n-triples"];
}

+ (NSString*) preferredMediaTypes {
    return @"application/n-triples";
}

+ (NSDictionary*) classesImplementingProtocols {
    return @{ (id)self: [self implementedProtocols] };
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWTriplesSerializer), nil];
}

+ (NSString*) nTriplesEncodingOfString: (NSString*) value escapingUnicode:(BOOL)escape {
    NSUInteger length   = [value length];
//    unichar* string = alloca(1+10*length);
    char* string = alloca(1+10*length);
    NSUInteger src  = 0;
    NSUInteger dst  = 0;
    char buffer[9]  = {0,0,0,0,0,0,0,0,0};
//    char* buffer    = calloc(1,9);
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
                if (escape) {
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
                } else {
                    if (c<0x80) {
                        string[dst++]=c;
                    }
                    else if (c<0x800) {
                        string[dst++]=192+c/64;
                        string[dst++]=128+c%64;
                    }
                    else if (c-0xd800u<0x800) {
                        return nil;
                    }
                    else if (c<0x10000) {
                        string[dst++]=224+c/4096;
                        string[dst++]=128+c/64%64;
                        string[dst++]=128+c%64;
                    }
                    else if (c<0x110000) {
                        string[dst++]=240+c/262144;
                        string[dst++]=128+c/4096%64;
                        string[dst++]=128+c/64%64;
                        string[dst++]=128+c%64;
                    }
                }
                break;
        }
    }
//    free(buffer);
    
    NSData* data    = [NSData dataWithBytes:string length:dst];
//    NSLog(@"%@ -> %@", value, data);
    NSString* s     = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
//    NSString* s     = [NSString stringWithCharacters:string length:dst];
//    free(string);
    return s;
}

+ (NSString*) nTriplesEncodingOfString: (NSString*) value {
    return [self nTriplesEncodingOfString:value escapingUnicode:YES];
}

+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term escapingUnicode:(BOOL)escape {
    NSString* serialized;
    switch (term.termType) {
        case GTWTermBlank:
            return [term description];
        case GTWTermLiteral:
            serialized   = [self nTriplesEncodingOfString: term.value escapingUnicode:escape];
            if (term.language) {
                return [NSString stringWithFormat:@"\"%@\"@%@", serialized, term.language];
            } else if (term.datatype) {
                return [NSString stringWithFormat:@"\"%@\"^^<%@>", serialized, term.datatype];
            } else {
                return [NSString stringWithFormat:@"\"%@\"", serialized];
            }
        case GTWTermIRI:
            return [NSString stringWithFormat:@"<%@>", [self nTriplesEncodingOfString:term.value escapingUnicode:escape]];
        default:
            return nil;
    }
}

+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term {
    return [self nTriplesEncodingOfTerm:term escapingUnicode:YES];
}

- (SPKNTriplesSerializer*) init {
    if (self = [super init]) {
        self.escapeUnicode  = YES;
    }
    return self;
}

- (NSData*) dataFromEnumerator: (NSEnumerator*) triples {
    return [self dataFromTriples:triples];
}

- (NSData*) dataFromTriples: (NSEnumerator*) triples {
    NSMutableData* data = [NSMutableData data];
    for (id<GTWTriple> t in triples) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ .\n", [[self class] nTriplesEncodingOfTerm:t.subject escapingUnicode:self.escapeUnicode], [[self class] nTriplesEncodingOfTerm:t.predicate escapingUnicode:self.escapeUnicode], [[self class] nTriplesEncodingOfTerm:t.object escapingUnicode:self.escapeUnicode]];
        [data appendData: [string dataUsingEncoding:NSASCIIStringEncoding]];
    }
    return data;
}

- (void) serializeTriples: (NSEnumerator*) triples toHandle: (NSFileHandle*) handle {
    for (id<GTWTriple> t in triples) {
        NSMutableString* string = [NSMutableString stringWithFormat:@"%@ %@ %@ .\n", [[self class] nTriplesEncodingOfTerm:t.subject escapingUnicode:self.escapeUnicode], [[self class] nTriplesEncodingOfTerm:t.predicate escapingUnicode:self.escapeUnicode], [[self class] nTriplesEncodingOfTerm:t.object escapingUnicode:self.escapeUnicode]];
        [handle writeData:[string dataUsingEncoding:NSASCIIStringEncoding]];
    }
}

@end
