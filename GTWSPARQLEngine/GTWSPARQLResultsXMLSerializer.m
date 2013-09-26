//
//  GTWSPARQLResultsXMLSerializer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLResultsXMLSerializer.h"

@implementation GTWSPARQLResultsXMLSerializer

- (NSData*) dataForTerm: (id<GTWTerm>) term {
    // TODO: need to properly escape values for XML
    switch ([term termType]) {
        case GTWTermBlank:
            return [[NSString stringWithFormat:@"<bnode>%@</bnode>", [term value]] dataUsingEncoding:NSUTF8StringEncoding];
        case GTWTermIRI:
            return [[NSString stringWithFormat:@"<uri>%@</uri>", [term value]] dataUsingEncoding:NSUTF8StringEncoding];
        case GTWTermLiteral:
            if ([term language]) {
                return [[NSString stringWithFormat:@"<literal xml:lang=\"%@\">%@</literal>", [term language], [term value]] dataUsingEncoding:NSUTF8StringEncoding];
            } else if ([term datatype]) {
                return [[NSString stringWithFormat:@"<literaldatatype=\"%@\">%@</literal>", [term datatype], [term value]] dataUsingEncoding:NSUTF8StringEncoding];
            } else {
                return [[NSString stringWithFormat:@"<literal>%@</literal>", [term value]] dataUsingEncoding:NSUTF8StringEncoding];
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

/*
<binding><uri>U</uri></binding>
<binding><literal>S</literal></binding>
<binding><literal xml:lang="L">S</literal></binding>
<binding><literal datatype="D">S</literal></binding>
<binding><bnode>I</bnode></binding>
*/