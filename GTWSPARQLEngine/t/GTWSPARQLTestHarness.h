//
//  GTWSPARQLTestHarness.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 5/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GTWSPARQLTestHarness : NSObject

@property NSUInteger testsCount, testsPassing, testsFailing, evalTests, passingEvalTests, syntaxTests, passingSyntaxTests;
@property NSMutableDictionary* testData;
@property BOOL runEvalTests;
@property BOOL runSyntaxTests;
@property NSMutableArray* failingTests;

- (BOOL) runTestsMatchingPattern: (NSString*) pattern fromManifest: (NSString*) manifest;
- (BOOL) runTestsFromManifest: (NSString*) manifest;

@end
