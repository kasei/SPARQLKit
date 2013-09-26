//
//  GTWSPARQLResultsXMLParser.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/23/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLResultsXMLParser.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWBlank.h>

@implementation GTWSPARQLResultsXMLParser

- (NSEnumerator*) parseResultsFromData: (NSData*) data settingVariables: (NSMutableSet*) set {
    NSXMLParser * parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    self.variables  = set;
    [parser parse];
    return [self.results objectEnumerator];
}

- (void)parserDidStartDocument:(NSXMLParser *)parser {
    self.results    = [NSMutableArray array];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqual: @"variable"]) {
        NSString* var = attributeDict[@"name"];
        if (var) {
            [self.variables addObject:var];
        }
    } else if ([elementName isEqual: @"result"]) {
        self.result = [NSMutableDictionary dictionary];
    } else if ([elementName isEqual: @"binding"]) {
        self.currentVariable    = attributeDict[@"name"];
    } else if ([elementName isEqual: @"uri"]) {
        self.currentValue   = [NSMutableString string];
    } else if ([elementName isEqual: @"bnode"]) {
        self.currentValue   = [NSMutableString string];
    } else if ([elementName isEqual: @"literal"]) {
        self.currentValue   = [NSMutableString string];
        self.datatype       = attributeDict[@"datatype"];
        self.language       = attributeDict[@"xml:lang"];
    } else {
//        NSLog(@"<%@>", elementName);
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqual: @"uri"]) {
        [self.result setObject:[[GTWIRI alloc] initWithValue:self.currentValue] forKey:self.currentVariable];
        self.currentValue   = nil;
    } else if ([elementName isEqual: @"bnode"]) {
        [self.result setObject:[[GTWBlank alloc] initWithValue:self.currentValue] forKey:self.currentVariable];
        self.currentValue   = nil;
    } else if ([elementName isEqual: @"literal"]) {
        if (self.datatype) {
            [self.result setObject:[[GTWLiteral alloc] initWithString:self.currentValue datatype:self.datatype] forKey:self.currentVariable];
        } else if (self.language) {
            [self.result setObject:[[GTWLiteral alloc] initWithString:self.currentValue language:self.language] forKey:self.currentVariable];
        } else {
            [self.result setObject:[[GTWLiteral alloc] initWithValue:self.currentValue] forKey:self.currentVariable];
        }
        self.currentValue   = nil;
    } else if ([elementName isEqual: @"result"]) {
        [self.results addObject: self.result];
    } else {
//        NSLog(@"</%@>", elementName);
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.currentValue appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
