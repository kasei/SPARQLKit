//
//  GTWSPARQLResultsXMLParser.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/23/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWSPARQLResultsXMLParser : NSObject<GTWSPARQLResultsParser, NSXMLParserDelegate>

@property (retain) NSMutableSet* variables;
@property (retain) NSMutableDictionary* result;
@property (retain) NSMutableArray* results;
@property (retain) NSString* currentVariable;
@property (retain) NSMutableString* currentValue;
@property (retain) NSString* datatype;
@property (retain) NSString* language;

@end
