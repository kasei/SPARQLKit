//
//  GTWSPARQLConnection.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLConnection.h"
#import <GTWSWBase/GTWSWBase.h>
#import "SPKSimpleQueryEngine.h"
#import "HTTPDataResponse.h"
#import "GTWSPARQLConfig.h"
#import "SPKSPARQLParser.h"
#import "SPARQLKit.h"
#import "SPKQueryPlanner.h"
#import "SPKSPARQLResultsXMLSerializer.h"
#import "SPKSPARQLResultsTextTableSerializer.h"
#import "HTTPMessage.h"

@implementation GTWSPARQLConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    
    GTWSPARQLConfig* cfg = (GTWSPARQLConfig*) config;
    id<GTWModel> model  = cfg.model;
    GTWDataset* dataset = cfg.dataset;
    
	NSString *filePath = [self filePathForURI:path];
	NSString *documentRoot = [config documentRoot];
	if (![filePath hasPrefix:documentRoot])
	{
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
//	NSLog(@"relative path: %@", relativePath);
//    HTTPMessage* req    = request;
//	NSURL* url          = [req url];
//    NSLog(@"%@", url);
    
    if ([relativePath isEqualToString:@"/sparql"]) {
//		NSLog(@"%s[%p]: Serving up dynamic content", __FILE__, self);
		
        NSDictionary* params    = [self parseGetParams];
        NSString* query         = params[@"query"];
        
        BOOL verbose    = NO;
        id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
        NSError* error;
        id<SPKTree> algebra    = [parser parseSPARQL:query withBaseURI:cfg.base error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        if (verbose) {
            NSLog(@"query:\n%@", algebra);
        }
        
        SPKQueryPlanner* planner        = [[SPKQueryPlanner alloc] init];
        id<SPKTree,GTWQueryPlan> plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model options:nil];
        if (verbose) {
            NSLog(@"plan:\n%@", plan);
        }
        
        NSSet* variables    = [plan inScopeVariables];
        if (verbose) {
            NSLog(@"executing query...");
        }
        id<GTWQueryEngine> engine   = [[SPKSimpleQueryEngine alloc] init];
        NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
//        id<GTWSPARQLResultsSerializer> s    = [[SPKSPARQLResultsTextTableSerializer alloc] init];
        id<GTWSPARQLResultsSerializer> s    = [[SPKSPARQLResultsXMLSerializer alloc] init];
        
        NSData* data        = [s dataFromResults:e withVariables:variables];
        return [[HTTPDataResponse alloc] initWithData:data];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

@end
