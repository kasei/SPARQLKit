//
//  GTWSPARQLTestHarness.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 5/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import <GTWSWBase/GTWGraphIsomorphism.h>
#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWQuadModel.h"
#import "GTWRedlandParser.h"
#import "GTWRasqalSPARQLParser.h"
#import "GTWQueryPlanner.h"
#import "GTWSimpleQueryEngine.h"
#import "GTWSPARQLResultsTextTableSerializer.h"
#import "GTWTurtleParser.h"
#import "GTWSPARQLResultsXMLParser.h"
#import "GTWSPARQLParser.h"

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
        self.failingTests   = [NSMutableArray array];
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

- (BOOL) runTestsMatchingPattern: (NSString*) pattern fromManifest: (NSString*) manifest {
    NSLog(@"Running manifest tests with pattern '%@'", pattern);
    __block NSError* error          = nil;
    GTWIRI* base                = [[GTWIRI alloc] initWithIRI:[NSString stringWithFormat:@"file://%@", manifest]];
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    
    NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:manifest];
    NSData* data                = [fh readDataToEndOfFile];
    id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" WithRaptorWorld:raptor_world_ptr];
    parser.baseURI              = base;
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
    
    for (id<GTWIRI> file in manifests) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:file.value] error:nil];
        NSData* data                = [fh readDataToEndOfFile];
        id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" WithRaptorWorld:raptor_world_ptr];
        parser.baseURI              = file;
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
    
    NSMutableArray* manifestTerms   = [NSMutableArray array];
    [model enumerateQuadsMatchingSubject:nil predicate:type object:mantype graph:nil usingBlock:^(id<GTWQuad> q) {
        [manifestTerms addObject:q.subject];
    } error:nil];
    
    for (id<GTWTerm> t in manifestTerms) {
        ok &= [self runTestsMatchingPattern: pattern fromManifest:t withModel: model];
    }
    
    NSLog(@"Failing tests: %@", self.failingTests);
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

- (BOOL) runTestsFromManifest: (NSString*) manifest {
    return [self runTestsMatchingPattern:nil fromManifest:manifest];
}

- (BOOL) runTestsMatchingPattern: (NSString*) pattern fromManifest: (id<GTWTerm>) manifest withModel: (id<GTWModel>) model {
//    NSLog(@"%@", manifest);
    NSMutableArray* tests   = [NSMutableArray array];
    id<GTWTerm> entries = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#entries"];
    [model enumerateQuadsMatchingSubject:manifest predicate:entries object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
        id<GTWTerm> list    = q.object;
        NSArray* array      = [self arrayFromModel:model withList:list];
        for (id<GTWTerm> test in array) {
            if (pattern && [test.value rangeOfString:pattern].location != NSNotFound) {
                [tests addObject:test];
            } else if (!pattern) {
                [tests addObject:test];
            }
        }
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

- (void) loadFile:(NSString*) filename intoStore: (id<GTWMutableQuadStore>) store withGraph: (id<GTWIRI>) graph {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    if (!fh) {
        NSLog(@"no file handle for string: %@", filename);
    }
    id<GTWRDFParser> parser;
    if ([filename hasSuffix:@".ttl"] || [filename hasSuffix:@".nt"]) {
        GTWIRI* base     = [[GTWIRI alloc] initWithIRI:filename];
        GTWTurtleLexer* lexer   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
        parser  = [[GTWTurtleParser alloc] initWithLexer:lexer base:base];
    } else {
        NSData* data            = [fh readDataToEndOfFile];
        parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"rdfxml" WithRaptorWorld:raptor_world_ptr];
    }
    
//    NSLog(@"parsing data with %@", parser);
    {
        __block NSUInteger count    = 0;
        NSError* error  = nil;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            GTWQuad* q   = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:q error:nil];
        } error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
//        NSLog(@"%lu total quads\n", count);
    }
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model testStore: (id<GTWMutableQuadStore>) testStore defaultGraph: defaultGraph {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    //    GTWIRI* mfresult = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
    
    NSArray* actions    = [model objectsForSubject:test predicate:mfaction graph:nil];
    if (actions && [actions count]) {
        id<GTWTerm> action  = actions[0];
        GTWIRI* qtquery = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#query"];
        GTWIRI* qtdata  = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#data"];
        
        id<GTWTerm> query   = [model anyObjectForSubject:action predicate:qtquery graph:nil];
        NSArray* data       = [model objectsForSubject:action predicate:qtdata graph:nil];
        for (id<GTWTerm> datafile in data) {
            [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:defaultGraph];
        }
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:query.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        NSLog(@"query file: %@", query.value);

        
        
        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        
        GTWTree* algebra            = [parser parseSPARQL:sparql withBaseURI:query.value];
        if (!algebra) {
            NSLog(@"failed to parse query: %@", query.value);
            return nil;
        }
        
//        GTWIRI* base    = [[GTWIRI alloc] initWithIRI:@"http://base.example.org/"];
        
//        NSLog(@"query:\n%@", algebra);
        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        id<GTWTree, GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
        if (!plan) {
//            NSLog(@"failed to plan query: %@", query.value);
            return nil;
        }
        
        return plan;
    } else {
        NSLog(@"No action for test %@", test);
        return nil;
    }
    return nil;
}

- (id<GTWTree>) queryAlgebraForSyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    id<GTWTerm> action  = [model anyObjectForSubject:test predicate:mfaction graph:nil];
    if (action) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:action.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        NSLog(@"query file: %@", action.value);

        
        
//        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
        
        
        
        
        GTWTree* algebra            = [parser parseSPARQL:sparql withBaseURI:action.value];
        if (!algebra) {
//            NSLog(@"failed to parse query: %@", action.value);
            return nil;
        }
        
        return algebra;
        
//        GTWIRI* data    = [[GTWIRI alloc] initWithIRI:@"http://base.example.org/"];
//        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
//        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[data.value]];
//        id<GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
//        if (!plan) {
//            NSLog(@"failed to plan query: %@", action.value);
//            return nil;
//        }
//        
//        return plan;
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
    id<GTWTree> algebra   = [self queryAlgebraForSyntaxTest: test withModel: model];
    BOOL ok = (BOOL) algebra;
    if (!expect)
        ok  = !ok;
    
    if (ok) {
        NSLog(@"%@", algebra);
        NSLog(@"ok %lu # %@\n", self.testsCount, test);
        self.testsPassing++;
        self.passingSyntaxTests++;
        return YES;
    } else {
//        NSLog(@"%@", sparql);
        NSLog(@"%@", algebra);
        [self.failingTests addObject:test];
        NSLog(@"not ok %lu # %@\n", self.testsCount, test);
        self.testsFailing++;
        [self.testData[kFailingSyntaxTests] addObject:test];
        return NO;
    }
}

- (BOOL) runQueryEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
//    NSLog(@"--> %@", test);
    self.testsCount++;
    self.evalTests++;
    GTWMemoryQuadStore* testStore   = [[GTWMemoryQuadStore alloc] init];
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithIRI:@"tag:kasei.us,2013;default-graph"];
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [self queryPlanForEvalTest: test withModel: model testStore:testStore defaultGraph: defaultGraph];
    GTWQuadModel* testModel         = [[GTWQuadModel alloc] initWithQuadStore:testStore];
    if (plan) {
//        NSLog(@"eval query plan: %@", plan);
        [plan computeProjectVariables];
        id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
        NSArray* got     = [[engine evaluateQueryPlan:plan withModel:testModel] allObjects];
        id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsTextTableSerializer alloc] init];
        
        GTWIRI* mfresult = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
        id<GTWTerm> result    = [model anyObjectForSubject:test predicate:mfresult graph:nil];
        NSString* srxFilename   = [[NSURL URLWithString:result.value] path];
        NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:srxFilename];
        NSData* data            = [fh readDataToEndOfFile];
        
        NSMutableSet* vars      = [NSMutableSet set];
        id<GTWSPARQLResultsParser> parser   = [[GTWSPARQLResultsXMLParser alloc] init];
        NSArray* expected  = [[parser parseResultsFromData: data settingVariables: vars] allObjects];
        
        if ([GTWGraphIsomorphism graphEnumerator:[got objectEnumerator] isomorphicWith:[expected objectEnumerator]]) {
            self.testsPassing++;
            self.passingEvalTests++;
            NSLog(@"ok %lu # %@\n", self.testsCount, test);
            return YES;
        } else {
            [self.failingTests addObject:test];
            NSLog(@"not ok %lu # %@\n", self.testsCount, test);

            {
                NSSet* variables    = [plan annotationForKey:kProjectVariables];
                NSData* data        = [s dataFromResults:[got objectEnumerator] withVariables:variables];
                fprintf(stdout, "got:\n");
                fwrite([data bytes], [data length], 1, stdout);
                
            }
            
            {
                NSSet* variables    = [plan annotationForKey:kProjectVariables];
                NSData* data        = [s dataFromResults:[expected objectEnumerator] withVariables:variables];
                fprintf(stdout, "expected:\n");
                fwrite([data bytes], [data length], 1, stdout);
            }

            
            self.testsFailing++;
            return NO;
        }

        
    } else {
        [self.failingTests addObject:test];
        NSLog(@"failed to produce query plan");
        NSLog(@"not ok %lu # %@\n", self.testsCount, test);
        self.testsFailing++;
        [self.testData[kFailingEvalTests] addObject:test];
        return NO;
    }
    
    self.testsPassing++;
    return YES;
}

@end
