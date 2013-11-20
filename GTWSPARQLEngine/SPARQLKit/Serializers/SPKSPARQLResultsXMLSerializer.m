//
//  SPKSPARQLResultsXMLSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKSPARQLResultsXMLSerializer.h"

@implementation SPKSPARQLResultsXMLSerializer

- (NSString*) xmlSimpleEscapeString: (NSString*) string {
    NSMutableString* value  = [NSMutableString stringWithString:string];
    [value replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    [value replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    [value replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    [value replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    [value replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    return value;
}
- (NSData*) dataForTerm: (id<GTWTerm>) term {
    NSString* value = [self xmlSimpleEscapeString:term.value];
    switch ([term termType]) {
        case GTWTermBlank:
            return [[NSString stringWithFormat:@"<bnode>%@</bnode>", value] dataUsingEncoding:NSUTF8StringEncoding];
        case GTWTermIRI:
            return [[NSString stringWithFormat:@"<uri>%@</uri>", value] dataUsingEncoding:NSUTF8StringEncoding];
        case GTWTermLiteral:
            if ([term language]) {
                return [[NSString stringWithFormat:@"<literal xml:lang=\"%@\">%@</literal>", [self xmlSimpleEscapeString:[term language]], value] dataUsingEncoding:NSUTF8StringEncoding];
            } else if ([term datatype]) {
                return [[NSString stringWithFormat:@"<literal datatype=\"%@\">%@</literal>", [self xmlSimpleEscapeString:[term datatype]], value] dataUsingEncoding:NSUTF8StringEncoding];
            } else {
                return [[NSString stringWithFormat:@"<literal>%@</literal>", value] dataUsingEncoding:NSUTF8StringEncoding];
            }
        default:
            return nil;
    }
}

- (void) serializeResults: (NSEnumerator*) results withVariables: (NSSet*) variables toHandle: (NSFileHandle*) handle {
    NSData* data    = [self dataFromResults:results withVariables:variables];
    [handle writeData:data];
}

- (NSData*) dataFromResults: (NSEnumerator*) results withVariables: (NSSet*) variables {
    NSMutableData* data = [NSMutableData data];
    [data appendData:[@"<?xml version=\"1.0\"?><sparql xmlns=\"http://www.w3.org/2005/sparql-results#\">\n<head>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSArray* vars       = [[variables objectEnumerator] allObjects];
    NSUInteger count    = [vars count];
    int i;
    for (i = 0; i < count; i++) {
        NSString* vname = [vars[i] value];
        [data appendData:[[NSString stringWithFormat:@"\t<variable name=\"%@\"/>\n", vname] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [data appendData:[@"</head>\n<results>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    for (NSDictionary* r in results) {
        [data appendData:[@"\t<result>\n" dataUsingEncoding:NSUTF8StringEncoding]];
        for (i = 0; i < count; i++) {
            NSString* vname = [vars[i] value];
            id<GTWTerm> t   = r[vname];
            if (t) {
                [data appendData:[[NSString stringWithFormat: @"\t\t<binding name=\"%@\">", vname] dataUsingEncoding:NSUTF8StringEncoding]];
                [data appendData:[self dataForTerm: t]];
                [data appendData:[@"</binding>\n" dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        [data appendData:[@"\t</result>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    for (id<GTWTerm> t in vars) {
        
    }
    for (NSDictionary* d in results) {
        
    }
    [data appendData:[@"</results>\n</sparql>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    return data;
}

@end
