//
//  GTWSPARQLTestHarness.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 5/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GTWBlankNodeRenamer.h"

@interface GTWSPARQLTestHarness : NSObject

@property NSUInteger testsCount, testsPassing, testsFailing, evalTests, passingEvalTests, syntaxTests, passingSyntaxTests, testResultCounter;
@property NSUInteger RDFLoadCount;
@property NSMutableDictionary* testData;
@property BOOL runEvalTests;
@property BOOL runSyntaxTests;
@property BOOL verbose;
@property NSMutableArray* failingTests;
@property dispatch_queue_t jobs_queue;
@property dispatch_queue_t results_queue;
@property dispatch_queue_t raptor_queue;

- (GTWSPARQLTestHarness*) initWithConcurrency: (BOOL) concurrent;
- (BOOL) runTestsMatchingPattern: (NSString*) pattern fromManifest: (NSString*) manifest;
- (BOOL) runTestsFromManifest: (NSString*) manifest;

@end
