//
//  SPKOperation.h
//  SPARQLKit
//
//  Created by Gregory Williams on 3/1/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

@interface SPKOperation : NSObject

@property BOOL verbose;
@property (retain) NSString* opString;
@property (retain) NSString* opBase;
@property (retain) id<SPKSPARQLParser> parser;
@property (retain) id<SPKQueryPlanner> planner;
@property (retain) id<GTWQueryEngine> engine;
@property (retain) id<GTWDataset> dataset;
@property (retain) NSSet* variables;
@property (retain) Class resultClass;
@property (retain) id<SPKTree> algebra;
@property (retain) id<GTWQueryPlan> plan;
@property (retain) NSMutableDictionary* prefixes;

- (SPKOperation*) initWithString: (NSString*) opString baseURI: (NSString*) base;
- (NSEnumerator*) executeWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error;
- (id<SPKTree>) parseWithError: (NSError*__autoreleasing*) error;
- (id<GTWQueryPlan>) planWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error;

@end
