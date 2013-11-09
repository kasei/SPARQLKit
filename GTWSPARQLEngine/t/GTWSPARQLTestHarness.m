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
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>
#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWTripleModel.h"
#import "GTWQuadModel.h"
#import "GTWRedlandParser.h"
//#import "GTWRasqalSPARQLParser.h"
#import "GTWQueryPlanner.h"
#import "GTWSimpleQueryEngine.h"
#import "GTWSPARQLResultsTextTableSerializer.h"
#import "GTWTurtleParser.h"
#import "GTWSPARQLParser.h"
#import "GTWSPARQLTestHarnessURLProtocol.h"
#import <GTWSWBase/GTWSPARQLResultsJSONParser.h>
#import "GTWNTriplesSerializer.h"

extern raptor_world* raptor_world_ptr;
//extern rasqal_world* rasqal_world_ptr;
static const NSString* kFailingSyntaxTests  = @"Failing Syntax Tests";
static const NSString* kFailingEvalTests  = @"Failing Eval Tests";

@implementation GTWSPARQLTestHarness


- (GTWSPARQLTestHarness*) initWithConcurrency: (BOOL) concurrent {
    if (self = [super init]) {
        self.RDFLoadCount   = 0;
        self.runEvalTests   = YES;
        self.runSyntaxTests = YES;
        self.testData       = [NSMutableDictionary dictionary];
        self.testData[kFailingEvalTests]     = [NSMutableSet set];
        self.testData[kFailingSyntaxTests]   = [NSMutableSet set];
        self.failingTests   = [NSMutableArray array];
        dispatch_queue_attr_t attr;
        if (concurrent) {
            attr    = DISPATCH_QUEUE_CONCURRENT;
        } else {
            attr    = DISPATCH_QUEUE_SERIAL;
        }
        self.jobs_queue     = dispatch_queue_create("us.kasei.sparql.sparql11-testsuite.tests", attr);
        self.results_queue  = dispatch_queue_create("us.kasei.sparql.sparql11-testsuite.results", DISPATCH_QUEUE_SERIAL);
        self.raptor_queue   = dispatch_queue_create("us.kasei.sparql.sparql11-testsuite.raptor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (GTWSPARQLTestHarness*) init {
    return [self initWithConcurrency:NO];
}

- (NSArray*) arrayFromModel: (id<GTWModel>) model withList: (id<GTWTerm>) list {
    NSMutableArray* array   = [NSMutableArray array];
    id<GTWTerm> head    = list;
    GTWIRI* first       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rest       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
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
    if (pattern) {
        NSLog(@"Running manifest tests with pattern '%@'", pattern);
    }
    __block NSError* error          = nil;
    GTWIRI* base                = [[GTWIRI alloc] initWithValue:[NSString stringWithFormat:@"file://%@", manifest]];
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    
    NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:manifest];
    NSData* data                = [fh readDataToEndOfFile];
    dispatch_sync(self.raptor_queue, ^{
        id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" base: base WithRaptorWorld:raptor_world_ptr];
        NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
        GTWBlankNodeRenamer* renamer    = [[GTWBlankNodeRenamer alloc] init];
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
            [store addQuad:[renamer renameObject:q inContext:ctx] error:&error];
        } error:&error];
    });
    
    GTWVariable* v  = [[GTWVariable alloc] initWithValue:@"o"];
    GTWIRI* include = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#include"];
    NSMutableArray* manifests   = [NSMutableArray array];
    [model enumerateBindingsMatchingSubject:nil predicate:include object:v graph:nil usingBlock:^(NSDictionary *q) {
        id<GTWTerm> list    = q[@"o"];
        NSArray* files      = [self arrayFromModel:model withList:list];
        NSMutableArray* matchingFiles   = [NSMutableArray array];
        for (id<GTWTerm> f in files) {
            // Skip entailment tests as well as the protocol and SD manifests which don't contain tests we can run
            if ([f.value rangeOfString:@"entailment"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"protocol"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"service-description"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"csv-tsv-res"].location != NSNotFound)
                continue;

            
            
            if ([f.value rangeOfString:@"add"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"update"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"clear"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"copy"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"delete"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"drop"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"move"].location != NSNotFound)
                continue;

            
            
            
            
            
            
            if ([f.value rangeOfString:@"service"].location != NSNotFound)
                continue;
            if ([f.value rangeOfString:@"syntax-fed"].location != NSNotFound)
                continue;
//            NSLog(@"Manifest --> %@", f);
            [matchingFiles addObject:f];
        }
        [manifests addObjectsFromArray:matchingFiles];
    } error:nil];
    
    for (id<GTWIRI> file in manifests) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:file.value] error:nil];
        NSData* data                = [fh readDataToEndOfFile];
        dispatch_sync(self.raptor_queue, ^{
            id<GTWRDFParser> parser     = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" base: file WithRaptorWorld:raptor_world_ptr];
            __block NSUInteger count    = 0;
            NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
            GTWBlankNodeRenamer* renamer    = [[GTWBlankNodeRenamer alloc] init];
            [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
                [store addQuad:[renamer renameObject:q inContext:ctx] error:&error];
                count++;
            } error:&error];
        });
    }
    
    GTWIRI* type = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* mantype = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#Manifest"];
    
    NSMutableArray* manifestTerms   = [NSMutableArray array];
    [model enumerateQuadsMatchingSubject:nil predicate:type object:mantype graph:nil usingBlock:^(id<GTWQuad> q) {
        [manifestTerms addObject:q.subject];
    } error:nil];
    
    for (id<GTWTerm> t in manifestTerms) {
        [self runTestsMatchingPattern: pattern fromManifest:t withModel: model];
    }
    
    NSLog(@"Failing tests: %@", self.failingTests);
    NSLog(@"%lu/%lu passing tests (%.1f%%)", self.testsPassing, self.testsCount, (100.0 * (float) self.testsPassing / (float) self.testsCount));
    if (self.runSyntaxTests) {
        NSLog(@"-> %lu/%lu passing syntax tests (%.1f%%)", self.passingSyntaxTests, self.syntaxTests, (100.0 * (float) self.passingSyntaxTests / (float) self.syntaxTests));
        if (self.passingSyntaxTests < self.syntaxTests) {
            //            NSLog(@"%@", self.testData[kFailingSyntaxTests]);
        }
    }
    if (self.runEvalTests) {
        NSLog(@"-> %lu/%lu passing eval tests (%.1f%%)", self.passingEvalTests, self.evalTests, (100.0 * (float) self.passingEvalTests / (float) self.evalTests));
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
    id<GTWTerm> entries = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#entries"];
    [model enumerateQuadsMatchingSubject:manifest predicate:entries object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
        id<GTWTerm> list    = q.object;
        NSArray* array      = [self arrayFromModel:model withList:list];
        for (id<GTWTerm> test in array) {
            if (pattern && [test.value rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound) {
                [tests addObject:test];
            } else if (!pattern) {
                [tests addObject:test];
            }
        }
    } error:nil];
    
    for (id<GTWTerm> test in tests) {
        void (*dispatch_async_func)(dispatch_queue_t queue, dispatch_block_t block) = dispatch_async;
        NSRange range   = [test.value rangeOfString:@"/service/"];
        if (range.location != NSNotFound) {
            // since service tests use the global GTWSPARQLTestHarnessURLProtocol object, they need to run by themselves
            dispatch_async_func = dispatch_barrier_async;
        }
        
        dispatch_async_func(self.jobs_queue, ^{
            [self runTest: test withModel: model];
        });
    }
    dispatch_barrier_sync(self.jobs_queue, ^{});
    return YES;
}

- (BOOL) runTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
    GTWIRI* type = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    NSArray* testtypes  = [model objectsForSubject:test predicate:type graph:nil];
    if (testtypes && [testtypes count]) {
        id<GTWTerm> testtype    = testtypes[0];
        if (self.verbose) {
            NSLog(@"%@ - %@", testtype.value, test.value);
        }
        if ([testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest11"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest"]) {
            if (self.runSyntaxTests) {
                return [self runQuerySyntaxTest: test withModel: model expectSuccess: YES];
            } else {
                return YES;
            }
        } else if ([testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest11"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest"]) {
//            return YES; // XXXXXXXXXXXXX
            if (self.runSyntaxTests) {
                return [self runQuerySyntaxTest: test withModel: model expectSuccess: NO];
            } else {
                return YES;
            }
        } else if ([testtype.value isEqual:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#QueryEvaluationTest"]) {
            if (self.runEvalTests) {
                BOOL ok     = [self runQueryEvalTest: test withModel: model];
                [NSURLProtocol unregisterClass:[GTWSPARQLTestHarnessURLProtocol class]];
                return ok;
            } else {
                return YES;
            }
        } else {
            NSLog(@"can't handle tests of type %@", testtype.value);
            return NO;
        }
    } else {
        NSLog(@"no test type for %@", test.value);
        return NO;
    }
    return YES;
}

- (void) loadFile:(NSString*) filename intoStore: (id<GTWMutableQuadStore>) store withGraph: (id<GTWIRI>) graph base: (id<GTWIRI>) base {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    if (!fh) {
        NSLog(@"no file handle for string: %@", filename);
    }
    NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
    GTWBlankNodeRenamer* renamer    = [[GTWBlankNodeRenamer alloc] init];
    if ([filename hasSuffix:@".ttl"] || [filename hasSuffix:@".nt"]) {
//      GTWIRI* base     = [[GTWIRI alloc] initWithValue:filename];
        GTWSPARQLLexer* lexer   = [[GTWSPARQLLexer alloc] initWithFileHandle:fh];
        id<GTWRDFParser> parser  = [[GTWTurtleParser alloc] initWithLexer:lexer base:base];
        //  NSLog(@"parsing data with %@", parser);
        __block NSUInteger count    = 0;
        NSError* error  = nil;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            GTWQuad* q   = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:[renamer renameObject:q inContext:ctx] error:nil];
        } error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        //  NSLog(@"%lu total quads\n", count);
    } else {
        NSData* data            = [fh readDataToEndOfFile];
        dispatch_sync(self.raptor_queue, ^{
            NSError* error  = nil;
            id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"rdfxml" base: base WithRaptorWorld:raptor_world_ptr];
            //  NSLog(@"parsing data with %@", parser);
            __block NSUInteger count    = 0;
            [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
                count++;
                GTWQuad* q   = [GTWQuad quadFromTriple:t withGraph:graph];
                [store addQuad:[renamer renameObject:q inContext:ctx] error:nil];
            } error:&error];
            //  NSLog(@"%lu total quads\n", count);
            if (error) {
                NSLog(@"parser error: %@", error);
            }
        });
    }
}

- (void) loadDatasetFromAlgebra: (id<GTWTree>) algebra intoStore: (id<GTWQuadStore, GTWMutableQuadStore>) store defaultGraph: (GTWIRI*) defaultGraph base: (id<GTWIRI>) base {
    if (algebra.type == kAlgebraDataset) {
        id<GTWTree> pair        = algebra.treeValue;
        id<GTWTree> defSet      = pair.arguments[0];
        id<GTWTree> namedSet    = pair.arguments[1];
        NSSet* defaultGraphs    = defSet.value;
        NSSet* namedGraphs      = namedSet.value;
        for (GTWIRI* g in defaultGraphs) {
            [self loadFile:[[NSURL URLWithString:g.value] path] intoStore:store withGraph:g base: base];
        }
        for (GTWIRI* g in namedGraphs) {
            [self loadFile:[[NSURL URLWithString:g.value] path] intoStore:store withGraph:g base: base];
        }
    } else {
        if (algebra.treeValue) {
            [self loadDatasetFromAlgebra:algebra.treeValue intoStore:store defaultGraph: defaultGraph base:base];
        }
        if (algebra.arguments) {
            for (id<GTWTree> t in algebra.arguments) {
                [self loadDatasetFromAlgebra:t intoStore:store defaultGraph: defaultGraph base:base];
            }
        }
    }
}

- (id<GTWTree,GTWQueryPlan>) queryPlanForEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model testStore: (id<GTWQuadStore, GTWMutableQuadStore>) testStore defaultGraph: (GTWIRI*) defaultGraph hasService: (BOOL*) serviceFlag {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    //    GTWIRI* mfresult = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
    
    NSArray* actions    = [model objectsForSubject:test predicate:mfaction graph:nil];
    if (actions && [actions count]) {
        id<GTWTerm> action  = actions[0];
        GTWIRI* qtquery         = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#query"];
        GTWIRI* qtdata          = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#data"];
        GTWIRI* qtgraphdata     = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#graphData"];
        GTWIRI* qtendpoint      = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#endpoint"];
        GTWIRI* qtservicedata   = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-query#serviceData"];
        
        id<GTWTerm> query   = [model anyObjectForSubject:action predicate:qtquery graph:nil];
        NSArray* data       = [model objectsForSubject:action predicate:qtdata graph:nil];
        NSArray* graphData  = [model objectsForSubject:action predicate:qtgraphdata graph:nil];
        NSArray* serviceData    = [model objectsForSubject:action predicate:qtservicedata graph:nil];
        for (id<GTWIRI> datafile in data) {
            if (self.verbose) {
                NSLog(@"data file: %@", datafile.value);
            }
            [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:defaultGraph base: datafile];
        }
        for (id<GTWIRI> datafile in graphData) {
            if (self.verbose) {
                NSLog(@"named graph data file: %@", datafile.value);
            }
            [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:datafile base: datafile];
        }
        for (id<GTWTerm> data in serviceData) {
            [NSURLProtocol registerClass:[GTWSPARQLTestHarnessURLProtocol class]];
            [GTWSPARQLTestHarnessURLProtocol mockBadEndpoint:[NSURL URLWithString:@"http://invalid.endpoint.org/sparql"]];
            *serviceFlag        = YES;
            id<GTWTerm> ep      = [model anyObjectForSubject:data predicate:qtendpoint graph:nil];
            NSArray* dataFiles  = [model objectsForSubject:data predicate:qtdata graph:nil];
            id<GTWQuadStore, GTWMutableQuadStore>   epstore   = [[GTWMemoryQuadStore alloc] init];
            for (id<GTWIRI> datafile in dataFiles) {
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:epstore withGraph:defaultGraph base: datafile];
            }
            NSURL* endpoint     = [NSURL URLWithString:ep.value];
            id<GTWModel> model  = [[GTWQuadModel alloc] initWithQuadStore:epstore];
            [GTWSPARQLTestHarnessURLProtocol mockEndpoint:endpoint withModel:model defaultGraph: defaultGraph];
        }
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:query.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        if (self.verbose)
            NSLog(@"query file: %@", query.value);

        
        
//        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
        
        if (self.verbose)
            NSLog(@"SPARQL:\n%@", sparql);
        
        NSError* error;
        id<GTWTree> algebra            = [parser parseSPARQL:sparql withBaseURI:query.value error:&error];
        if (!algebra) {
            NSLog(@"failed to parse eval query: %@", query.value);
            return nil;
        }
        
        [self loadDatasetFromAlgebra:algebra intoStore:testStore defaultGraph:defaultGraph base:defaultGraph];
        
//        GTWIRI* base    = [[GTWIRI alloc] initWithValue:@"http://base.example.org/"];
        
        if (NO) {
            NSLog(@"test model ------------------->\n");
            [testStore enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
                NSLog(@"-> %@", q);
            } error:nil];
            NSLog(@"<------------------- test model\n");
        }
        
        id<GTWModel> testModel  = [[GTWQuadModel alloc] initWithQuadStore:testStore];
        
        if (self.verbose)
            NSLog(@"query:\n%@", algebra);
        
        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        id<GTWTree, GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel:testModel optimize: YES];
        if (!plan) {
//            NSLog(@"failed to plan query: %@", query.value);
            return nil;
        }
        
        if (self.verbose)
            NSLog(@"plan:\n%@", plan);
        
        return plan;
    } else {
        NSLog(@"No action for test %@", test);
        return nil;
    }
    return nil;
}

- (id<GTWTree>) queryAlgebraForSyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model error: (NSError**) error {
    GTWIRI* mfaction = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#action"];
    id<GTWTerm> action  = [model anyObjectForSubject:test predicate:mfaction graph:nil];
    if (action) {
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:action.value] error:nil];
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        if (self.verbose) {
            NSLog(@"query file: %@", action.value);
            NSLog(@"SPARQL:\n%@", sparql);
        }

        
        
//        id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
        id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
        
        
        
        GTWTree* algebra            = [parser parseSPARQL:sparql withBaseURI:action.value error:error];
        if (!algebra) {
//            NSLog(@"failed to parse syntax query: %@", action.value);
            return nil;
        }
        
        return algebra;
        
//        GTWIRI* data    = [[GTWIRI alloc] initWithValue:@"http://base.example.org/"];
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

- (void) printResultForTest: (NSString*) test passing: (BOOL) passing {
    NSMutableString* s  = [NSMutableString string];
    NSUInteger number   = ++self.testResultCounter;
    if (passing) {
        [s appendFormat:@"ok %lu # %@\n", number, test];
    } else {
        [s appendFormat:@"not ok %lu # %@\n", number, test];
    }
    NSData* data    = [s dataUsingEncoding:NSUTF8StringEncoding];
    fwrite([data bytes], [data length], 1, stdout);
}


- (BOOL) runQuerySyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model expectSuccess: (BOOL) expect {
//    NSLog(@"--> %@", test);
    self.testsCount++;
    self.syntaxTests++;
    NSError* error  = nil;
    id<GTWTree> algebra = [self queryAlgebraForSyntaxTest: test withModel: model error:&error];
    BOOL ok = (error || algebra == nil) ? NO : YES;
    if (!expect)
        ok  = !ok;
    
    if (ok) {
//        NSLog(@"%@", algebra);
        dispatch_sync(self.results_queue, ^{
            [self printResultForTest:test.value passing:YES];
            self.testsPassing++;
            self.passingSyntaxTests++;
        });
        return YES;
    } else {
//        NSLog(@"%@", sparql);
//        NSLog(@"algebra: %@", algebra);
        NSLog(@"Parsing error: %@", error);
        dispatch_sync(self.results_queue, ^{
            [self.failingTests addObject:test];
            [self printResultForTest:test.value passing:NO];
            self.testsFailing++;
            [self.testData[kFailingSyntaxTests] addObject:test];
        });
        return NO;
    }
}

- (BOOL) runQueryEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model {
//    NSLog(@"--> %@", test);
    [GTWSPARQLTestHarnessURLProtocol clearMockedEndpoints];
    self.testsCount++;
    self.evalTests++;
    GTWMemoryQuadStore* testStore   = [[GTWMemoryQuadStore alloc] init];
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue:@"tag:kasei.us,2013;default-graph"];
    BOOL hasService = NO;
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [self queryPlanForEvalTest: test withModel: model testStore:testStore defaultGraph: defaultGraph hasService:&hasService];
    GTWQuadModel* testModel         = [[GTWQuadModel alloc] initWithQuadStore:testStore];
    if (plan) {
        id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
        
        if (NO) {
            __block NSUInteger count    = 0;
            NSLog(@"Quads:\n");
            [testModel enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q){
                count++;
                NSLog(@"-> %@\n", q);
            } error:nil];
            NSLog(@"%lu total quads\n", count);
        }
        
        NSArray* got     = [[engine evaluateQueryPlan:plan withModel:testModel] allObjects];
        id<GTWSerializer> s;
        Class resultsClass  = [(GTWTree*) plan planResultClass];
        if ([resultsClass isEqual: [NSDictionary class]]) {
            s    = [[GTWSPARQLResultsTextTableSerializer alloc] init];
        } else {
            s   = [[GTWNTriplesSerializer alloc] init];
        }
        
        GTWIRI* mfresult = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
        id<GTWTerm> result          = [model anyObjectForSubject:test predicate:mfresult graph:nil];
        NSString* resultsFilename   = [[NSURL URLWithString:result.value] path];
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:resultsFilename];
        
        NSArray* expected;
        NSMutableSet* vars      = [NSMutableSet set];
        if (self.verbose) {
            NSLog(@"Results file: %@", resultsFilename);
        }
        if ([resultsFilename hasSuffix:@".srx"]) {
            NSData* data                = [fh readDataToEndOfFile];
            id<GTWSPARQLResultsParser> parser   = [[GTWSPARQLResultsXMLParser alloc] init];
            expected    = [[parser parseResultsFromData: data settingVariables: vars] allObjects];
        } else if ([resultsFilename hasSuffix:@".ttl"] || [resultsFilename hasSuffix:@".rdf"]) {
            NSMutableArray* triples = [NSMutableArray array];
            GTWIRI* base                = [[GTWIRI alloc] initWithValue:[NSString stringWithFormat:@"file://%@", resultsFilename]];
            __block BOOL sparqlResults  = NO;
            if ([resultsFilename hasSuffix:@".ttl"]) {
                GTWSPARQLLexer* l   = [[GTWSPARQLLexer alloc] initWithFileHandle:fh];
                id<GTWRDFParser> parser = [[GTWTurtleParser alloc] initWithLexer:l base:base];
                NSError* error;
                [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                    if ([t.object.value isEqual: @"http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet"]) {
                        sparqlResults   = YES;
                    }
                    [triples addObject:t];
                } error:&error];
            } else {
                NSData* data            = [fh readDataToEndOfFile];
                dispatch_sync(self.raptor_queue, ^{
                    id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"rdfxml" base: nil WithRaptorWorld:raptor_world_ptr];
                    NSError* error;
                    [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                        if ([t.object.value isEqual: @"http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet"]) {
                            sparqlResults   = YES;
                        }
                        [triples addObject:t];
                    } error:&error];
                });
            }
            if (sparqlResults) {
                expected    = [self SPARQLResultsEnumeratorFromTriples:triples settingVariables: vars];
            } else {
                expected    = triples;
            }
        } else if ([resultsFilename hasSuffix:@".srj"]) {
            NSData* data                = [fh readDataToEndOfFile];
            id<GTWSPARQLResultsParser> parser   = [[GTWSPARQLResultsJSONParser alloc] init];
            expected    = [[parser parseResultsFromData: data settingVariables: vars] allObjects];
        } else {
            dispatch_sync(self.results_queue, ^{
                NSLog(@"*** Don't know how to parse expected results from file %@", resultsFilename);
                [self.failingTests addObject:test];
            });
            return NO;
        }
        
        NSError* reason;
        if ([GTWGraphIsomorphism graphEnumerator:[got objectEnumerator] isomorphicWith:[expected objectEnumerator] reason:&reason]) {
//            NSLog(@"eval query plan: %@", plan);
            dispatch_sync(self.results_queue, ^{
                self.testsPassing++;
                self.passingEvalTests++;
                [self printResultForTest:test.value passing:YES];
            });
            return YES;
        } else {
            if (self.verbose) {
                NSLog(@"%@", reason);
            }
//            NSLog(@"eval query plan: %@", plan);
            dispatch_sync(self.results_queue, ^{
                [self.failingTests addObject:test];
                [self printResultForTest:test.value passing:NO];
                
                if (self.verbose) {
                    {
                        NSSet* variables    = [plan inScopeVariables];
                        NSData* data;
                        if ([resultsClass isEqual: [GTWTriple class]]) {
                            data    = [(id<GTWTriplesSerializer>)s dataFromTriples:[got objectEnumerator]];
                        } else {
                            data    = [(id<GTWSPARQLResultsSerializer>)s dataFromResults:[got objectEnumerator] withVariables:variables];
                        }
                        fprintf(stderr, "got:\n");
                        fwrite([data bytes], [data length], 1, stderr);
                        
                    }
                    
                    {
                        NSMutableSet* variables = [NSMutableSet set];
                        for (NSString* v in vars) {
                            [variables addObject:[[GTWVariable alloc] initWithValue:v]];
                        }
                        NSData* data;
                        if ([resultsClass isEqual: [GTWTriple class]]) {
                            data    = [(id<GTWTriplesSerializer>)s dataFromTriples:[expected objectEnumerator]];
                        } else {
                            data    = [(id<GTWSPARQLResultsSerializer>)s dataFromResults:[expected objectEnumerator] withVariables:variables];
                        }
                        fprintf(stderr, "expected:\n");
                        fwrite([data bytes], [data length], 1, stderr);
                    }
                }
                
                self.testsFailing++;
            });
            return NO;
        }

        
    } else {
        dispatch_sync(self.results_queue, ^{
            [self.failingTests addObject:test];
            NSLog(@"failed to produce query plan");
            [self printResultForTest:test.value passing:NO];
            self.testsFailing++;
            [self.testData[kFailingEvalTests] addObject:test];
        });
        return NO;
    }
    
    dispatch_sync(self.results_queue, ^{
        self.testsPassing++;
    });
    return YES;
}

- (NSArray*) SPARQLResultsEnumeratorFromTriples: (NSArray*) triples settingVariables: (NSMutableSet*) variables {
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue:@"tag:kasei.us,2013;default-graph"];
    GTWIRI* type = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* resultset = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet"];
    GTWIRI* resultVariable  = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#resultVariable"];
    GTWIRI* rssolutions     = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#solution"];
    GTWIRI* rsbinding       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#binding"];
    GTWIRI* rsboolean       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#boolean"];
    GTWIRI* rsvariable      = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#variable"];
    GTWIRI* rsvalue         = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#value"];
    
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
    GTWBlankNodeRenamer* renamer    = [[GTWBlankNodeRenamer alloc] init];
    for (id<GTWTriple> t in triples) {
        GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:defaultGraph];
        [store addQuad:[renamer renameObject:q inContext:ctx] error:nil];
    }
    GTWQuadModel* model = [[GTWQuadModel alloc] initWithQuadStore:store];
    id<GTWTerm> rs      = [model anySubjectForPredicate:type object:resultset graph:nil];
    if (!rs)
        return nil;
    
    id<GTWTerm> boolean = [model anyObjectForSubject:rs predicate:rsboolean graph:nil];
    if (boolean) {
        return @[@{@".bool": boolean}];
    } else {
        NSArray* vars       = [model objectsForSubject:rs predicate:resultVariable graph:nil];
        for (id<GTWTerm> v in vars) {
            [variables addObject:v.value];
        }
        
        NSMutableArray* results = [NSMutableArray array];
        NSArray* solutions  = [model objectsForSubject:rs predicate:rssolutions graph:nil];
        for (id<GTWTerm> s in solutions) {
    //        NSLog(@"solution: %@", s);
            NSMutableDictionary* result = [NSMutableDictionary dictionary];
            NSArray* bindings   = [model objectsForSubject:s predicate:rsbinding graph:nil];
            for (id<GTWTerm> b in bindings) {
    //            NSLog(@"  binding: %@", b);
                id<GTWTerm> var = [model anyObjectForSubject:b predicate:rsvariable graph:nil];
                id<GTWTerm> val = [model anyObjectForSubject:b predicate:rsvalue graph:nil];
    //            NSLog(@"    var: %@", var);
    //            NSLog(@"    val: %@", val);
                result[var.value]   = val;
            }
            [results addObject:result];
        }
        //    NSLog(@"results: %@\n<<<<<<<<<<<<", results);
        return results;
    }
}

@end
