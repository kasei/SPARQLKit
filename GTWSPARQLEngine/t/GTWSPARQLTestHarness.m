//
//  GTWSPARQLTestHarness.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 5/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWQuadModel.h"
#import "GTWRedlandParser.h"
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import "GTWRasqalSPARQLParser.h"
#import "GTWQueryPlanner.h"

extern raptor_world* raptor_world_ptr;
extern rasqal_world* rasqal_world_ptr;
static const NSString* kFailingSyntaxTests  = @"Failing Syntax Tests";
static const NSString* kFailingEvalTests  = @"Failing Eval Tests";

@implementation GTWSPARQLTestHarness

- (GTWSPARQLTestHarness*) init {
    if (self = [super init]) {
        self.runEvalTests   = YES;
        self.runSyntaxTests = YES;
        self.testData       = [NSMutableDictionary dictionary];
        self.testData[kFailingEvalTests]     = [NSMutableSet set];
        self.testData[kFailingSyntaxTests]   = [NSMutableSet set];
    }
    return self;
}

- (NSArray*) arrayFromModel: (id<GTWModel>) model withList: (id<GTWTerm>) list {
    NSMutableArray* array   = [NSMutableArray array];
    id<GTWTerm> head    = list;
    GTWIRI* first       = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rest       = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
    while (head) {
        NSArray* objects    = [model objectsForSubject:head predicate:first graph:nil];
        [array addObjectsFromArray:objects];
        NSArray* heads  = [model objectsForSubject:head predicate:rest graph:nil];
        if (heads && [heads count]) {
            head    = heads[0];
        } else {
            head    = nil;
        }
    }
    return array;
}

- (BOOL) runTestsFromManifest: (NSString*) manifest {
    NSLog(@"Running manifest tests");
    __block NSError* error          = nil;
    GTWIRI* base                = [[GTWIRI alloc] initWithIRI:[NSString stringWithFormat:@"file://%@", manifest]];
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    
    NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:manifest];
    NSData* data                = [fh readDataToEndOfFile];
    id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" WithRaptorWorld:raptor_world_ptr];
    parser.baseURI              = base.value;
    [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
        GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
        [store addQuad:q error:&error];
    } error:&error];
    
    GTWVariable* v  = [[GTWVariable alloc] initWithName:@"o"];
    GTWIRI* include = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#include"];
    NSMutableArray* manifests   = [NSMutableArray array];
    [model enumerateBindingsMatchingSubject:nil predicate:include object:v graph:nil usingBlock:^(NSDictionary *q) {
        id<GTWTerm> list    = q[@"o"];
        [manifests addObjectsFromArray:[self arrayFromModel: model withList: list]];
    } error:nil];
    
    for (id<GTWTerm> file in manifests) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:file.value] error:nil];
        NSData* data                = [fh readDataToEndOfFile];
        id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" WithRaptorWorld:raptor_world_ptr];
        parser.baseURI              = file.value;
        __block NSUInteger count    = 0;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
            [store addQuad:q error:&error];
            count++;
        } error:&error];
    }
    
    GTWIRI* type = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* mantype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#Manifest"];
    __block BOOL ok = YES;
    [model enumerateQuadsMatchingSubject:nil predicate:type object:mantype graph:nil usingBlock:^(id<GTWQuad> q) {
        ok &= [self runTestsFromManifest:q.subject withModel: model];
    } error:nil];

    NSLog(@"%lu/%lu passing tests", self.testsPassing, self.testsCount);
    if (self.runSyntaxTests) {
        NSLog(@"-> %lu/%lu passing syntax tests", self.passingSyntaxTests, self.syntaxTests);
        if (self.passingSyntaxTests < self.syntaxTests) {
//            NSLog(@"%@", self.testData[kFailingSyntaxTests]);
        }
    }
    if (self.runEvalTests) {
        NSLog(@"-> %lu/%lu passing eval tests", self.passingEvalTests, self.evalTests);
        if (self.passingEvalTests < self.evalTests) {
//            NSLog(@"%@", self.testData[kFailingEvalTests]);
        }
    }

    return YES;
}

- (BOOL) runTestsFromManifest: (id<GTWTerm>) manifest withModel: (id<GTWModel>) model {
//    NSLog(@"%@", manifest);
    NSMutableArray* tests   = [NSMutableArray array];
    id<GTWTerm> entries = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#entries"];
    [model enumerateQuadsMatchingSubject:manifest predicate:entries object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
        id<GTWTerm> list    = q.object;
        NSArray* array      = [self arrayFromModel:model withList:list];
        [tests addObjectsFromArray:array];
    } error:nil];
    
    __block BOOL ok = YES;
    for (id<GTWTerm> test in tests) {
        ok &= [self runTest: test withModel: model];
    }
    return ok;
}

- (BOOL) runTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
    GTWIRI* type = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    NSArray* testtypes  = [model objectsForSubject:test predicate:type graph:nil];
    if (testtypes && [testtypes count]) {
        id<GTWTerm> testtype    = testtypes[0];
//        NSLog(@"%@\t%@", testtype.value, test.value);
        if ([testtype.value isEqual:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest11"]) {
            if (self.runSyntaxTests) {
                return [self runQuerySyntaxTest: test withModel: model expectSuccess: YES];
            } else {
                return YES;
            }
        } else if ([testtype.value isEqual:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest11"]) {
            if (self.runSyntaxTests) {
                return [self runQuerySyntaxTest: test withModel: model expectSuccess: NO];
            } else {
                return YES;
            }
        } else if ([testtype.value isEqual:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#QueryEvaluationTest"]) {
            if (self.runEvalTests) {
                return [self runQueryEvalTest: test withModel: model];
            } else {
                return YES;
            }
        } else {
//            NSLog(@"can't handle tests of type %@", testtype.value);
            return NO;
        }
    } else {
        NSLog(@"no test type for %@", test.value);
        return NO;
    }
    return YES;
}

- (id<GTWQueryPlan>) queryPlanForEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    //    GTWIRI* mfresult = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
    
    NSArray* actions    = [model objectsForSubject:test predicate:mfaction graph:nil];
    if (actions && [actions count]) {
        id<GTWTerm> action  = actions[0];
        GTWIRI* qtquery = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#query"];
        GTWIRI* qtdata  = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#data"];
        
        id<GTWTerm> query   = [model anyObjectForSubject:action predicate:qtquery graph:nil];
        id<GTWTerm> data   = [model anyObjectForSubject:action predicate:qtdata graph:nil];
        
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:query.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        NSLog(@"query file: %@", query.value);
        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        GTWTree* algebra            = [parser parserSPARQL:sparql withBaseURI:query.value];
        if (!algebra) {
//            NSLog(@"failed to parse query: %@", query.value);
            return nil;
        }
        
        if (!data) {
            data    = [[GTWIRI alloc] initWithIRI:@"http://base.example.org/"];
        }
        
//        NSLog(@"query:\n%@", algebra);
        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[data.value]];
        id<GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
        if (!plan) {
            NSLog(@"failed to plan query: %@", query.value);
            return nil;
        }
        
        return plan;
    } else {
        NSLog(@"No action for test %@", test);
        return nil;
    }
    return nil;
}

- (id<GTWQueryPlan>) queryPlanForSyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    id<GTWTerm> action  = [model anyObjectForSubject:test predicate:mfaction graph:nil];
    if (action) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:action.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
//        NSLog(@"query file: %@", action.value);
        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        GTWTree* algebra            = [parser parserSPARQL:sparql withBaseURI:action.value];
        if (!algebra) {
//            NSLog(@"failed to parse query: %@", action.value);
            return nil;
        }
        
        GTWIRI* data    = [[GTWIRI alloc] initWithIRI:@"http://base.example.org/"];
//        NSLog(@"query:\n%@", algebra);
        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[data.value]];
        id<GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
        if (!plan) {
            NSLog(@"failed to plan query: %@", action.value);
            return nil;
        }
        
        return plan;
    } else {
        NSLog(@"No action for test %@", test);
        return nil;
    }
    return nil;
}

- (BOOL) runQuerySyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model expectSuccess: (BOOL) expect {
//    NSLog(@"--> %@", test);
    self.testsCount++;
    self.syntaxTests++;
    id<GTWQueryPlan> plan   = [self queryPlanForSyntaxTest: test withModel: model];
    BOOL ok = (BOOL) plan;
    if (!expect)
        ok  = !ok;
    
    if (ok) {
        self.testsPassing++;
        self.passingSyntaxTests++;
        return YES;
    } else {
        self.testsFailing++;
        [self.testData[kFailingSyntaxTests] addObject:test];
        return NO;
    }
}

- (BOOL) runQueryEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
//    NSLog(@"--> %@", test);
    self.testsCount++;
    self.evalTests++;
    id<GTWQueryPlan> plan   = [self queryPlanForEvalTest: test withModel: model];
    if (plan) {
//        self.testsPassing++;
//        self.passingEvalTests++;
        self.testsFailing++;
        return NO; // TODO implement evaluation tests
    } else {
        self.testsFailing++;
        [self.testData[kFailingEvalTests] addObject:test];
        return NO;
    }
    
    self.testsPassing++;
    return YES;
}

@end
