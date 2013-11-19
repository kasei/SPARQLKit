//
//  GTWSPARQLConnection.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLConnection.h"
#import <GTWSWBase/GTWSWBase.h>
#import "GTWSimpleQueryEngine.h"
#import "HTTPDataResponse.h"
#import "GTWSPARQLConfig.h"
#import "GTWSPARQLParser.h"
#import "SPARQLKit.h"
#import "GTWQueryPlanner.h"
#import "GTWSPARQLResultsXMLSerializer.h"
#import "GTWSPARQLResultsTextTableSerializer.h"
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
        id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
        NSError* error;
        id<GTWTree> algebra    = [parser parseSPARQL:query withBaseURI:cfg.base error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        if (verbose) {
            NSLog(@"query:\n%@", algebra);
        }
        
        GTWQueryPlanner* planner        = [[GTWQueryPlanner alloc] init];
        id<GTWTree,GTWQueryPlan> plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model options:nil];
        if (verbose) {
            NSLog(@"plan:\n%@", plan);
        }
        
        NSSet* variables    = [plan inScopeVariables];
        if (verbose) {
            NSLog(@"executing query...");
        }
        id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
        NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
//        id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsTextTableSerializer alloc] init];
        id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsXMLSerializer alloc] init];
        
        NSData* data        = [s dataFromResults:e withVariables:variables];
        return [[HTTPDataResponse alloc] initWithData:data];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

@end
