//
//  SPKQuery.h
//  SPARQLKit
//
//  Created by Gregory Williams on 12/6/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

@interface SPKQuery : NSObject

@property BOOL verbose;
@property (retain) NSString* queryString;
@property (retain) NSString* queryBase;
@property (retain) id<SPKSPARQLParser> parser;
@property (retain) id<SPKQueryPlanner> planner;
@property (retain) id<GTWQueryEngine> engine;
@property (retain) id<GTWDataset> dataset;
@property (retain) NSSet* variables;
@property (retain) Class resultClass;
@property (retain) id<SPKTree> algebra;
@property (retain) id<GTWQueryPlan> plan;

- (SPKQuery*) initWithQueryString: (NSString*) queryString baseURI: (NSString*) base;
- (NSEnumerator*) executeWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error;
- (id<SPKTree>) parseWithError: (NSError*__autoreleasing*) error;
- (id<GTWQueryPlan>) planWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error;

@end
