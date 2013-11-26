//
//  GTWSPARQLTestHarness.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 5/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import <GTWSWBase/GTWGraphIsomorphism.h>
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>
#import <GTWSWBase/GTWSPARQLResultsJSONParser.h>

#import <SPARQLKit/SPARQLKit.h>
#import <SPARQLKit/SPKMemoryQuadStore.h>
#import <SPARQLKit/SPKTripleModel.h>
#import <SPARQLKit/SPKQuadModel.h>
//#import <SPARQLKit/SPKRedlandParser.h>
#import <SPARQLKit/SPKQueryPlanner.h>
#import <SPARQLKit/SPKSimpleQueryEngine.h>
#import <SPARQLKit/SPKSPARQLResultsTextTableSerializer.h>
#import <SPARQLKit/SPKTurtleParser.h>
#import <SPARQLKit/SPKSPARQLParser.h>
#import <SPARQLKit/SPKNTriplesSerializer.h>
#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLTestHarnessURLProtocol.h"
#import "SPKSPARQLPluginHandler.h"

//extern raptor_world* raptor_world_ptr;
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

- (BOOL) runTestsMatchingPattern: (NSString*) pattern fromManifests: (NSArray*) manifestFiles {
    if (pattern) {
        NSLog(@"Running manifest tests with pattern '%@'", pattern);
    }
    __block NSError* error          = nil;
    for (NSString* manifest in manifestFiles) {
        GTWIRI* base                = [[GTWIRI alloc] initWithValue:[NSString stringWithFormat:@"file://%@", manifest]];
        SPKMemoryQuadStore* store   = [[SPKMemoryQuadStore alloc] init];
        SPKQuadModel* model         = [[SPKQuadModel alloc] initWithQuadStore:store];
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:manifest];
        NSData* data                = [fh readDataToEndOfFile];
        Class SPKRedlandParser      = [SPKSPARQLPluginHandler pluginClassWithName:@"GTWRedlandParser"];
        if (!SPKRedlandParser) {
            NSLog(@"Redland parser plugin not available.");
            return NO;
        }
        id<GTWRDFParser> parser     = [SPKRedlandParser alloc];
        parser  = [parser initWithData:data base:base];

        //            id<GTWRDFParser> parser     = [[SPKRedlandParser alloc] initWithData:data inFormat:@"guess" base: base WithRaptorWorld:raptor_world_ptr];
        NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
        SPKBlankNodeRenamer* renamer    = [[SPKBlankNodeRenamer alloc] init];
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
            [store addQuad:(id<GTWQuad>)[renamer renameObject:q inContext:ctx] error:&error];
        } error:&error];
 
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
                
                
                // Skip update tests
//                if ([f.value rangeOfString:@"add"].location != NSNotFound)
//                    continue;
//                if ([f.value rangeOfString:@"update"].location != NSNotFound) {
//                    if ([f.value rangeOfString:@"syntax"].location == NSNotFound) {
//                        continue;
//                    }
//                }
                if ([f.value rangeOfString:@"clear"].location != NSNotFound)
                    continue;
                if ([f.value rangeOfString:@"copy"].location != NSNotFound)
                    continue;
//                if ([f.value rangeOfString:@"delete"].location != NSNotFound)
//                    continue;
                if ([f.value rangeOfString:@"drop"].location != NSNotFound)
                    continue;
                if ([f.value rangeOfString:@"move"].location != NSNotFound)
                    continue;
                
                // Skip federation tests as the NSURLProtocol system used to mock requests seems to hang on recursive calls.
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
            Class SPKRedlandParser      = [SPKSPARQLPluginHandler pluginClassWithName:@"GTWRedlandParser"];
            if (!SPKRedlandParser) {
                NSLog(@"Redland parser plugin not available.");
                return NO;
            }
            id<GTWRDFParser> parser     = [SPKRedlandParser alloc];
            parser  = [parser initWithData:data base:file];
            __block NSUInteger count    = 0;
            NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
            SPKBlankNodeRenamer* renamer    = [[SPKBlankNodeRenamer alloc] init];
            [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:base];
                [store addQuad:(id<GTWQuad>)[renamer renameObject:q inContext:ctx] error:&error];
                count++;
            } error:&error];
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
    }
    
    return YES;
}

- (void) printSummary {
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
}

- (BOOL) runTestsFromManifests: (NSArray*) manifests {
    return [self runTestsMatchingPattern:nil fromManifests:manifests];
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
    GTWIRI* dtapproval      = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#approval"];
    GTWIRI* mfrequires      = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#requires"];
    NSArray* testtypes      = [model objectsForSubject:test predicate:type graph:nil];
    if (testtypes && [testtypes count]) {
        id<GTWTerm> approval    = [model anyObjectForSubject:test predicate:dtapproval graph:nil];
        NSArray* requires       = [model objectsForSubject:test predicate:mfrequires graph:nil];
        if (!approval) {
            if (self.verbose)
                NSLog(@"No approval value for test %@", test);
            return NO;
        }
        
        if ([requires count]) {
            NSMutableSet* reqs  = [NSMutableSet set];
            for (GTWIRI* req in requires) {
                [reqs addObject:req.value];
            }
            [reqs removeObject:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#LangTagAwareness"];
            [reqs removeObject:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#KnownTypesDefault2Neq"];
            [reqs removeObject:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#StringSimpleLiteralCmp"];
            if ([reqs count]) {
                if (self.verbose)
                    NSLog(@"Test requirements not satisfied: %@", reqs);
                return NO;
            }
        }
        
        if ([approval.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#Approved"]) {
            id<GTWTerm> testtype    = testtypes[0];
            if (self.verbose) {
                NSLog(@"%@ - %@", testtype.value, test.value);
            }
            if ([testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest11"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveUpdateSyntaxTest11"]) {
                if (self.runSyntaxTests) {
                    return [self runQuerySyntaxTest: test withModel: model expectSuccess: YES];
                } else {
                    return YES;
                }
            } else if ([testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest11"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeUpdateSyntaxTest11"]) {
                if (self.runSyntaxTests) {
                    return [self runQuerySyntaxTest: test withModel: model expectSuccess: NO];
                } else {
                    return YES;
                }
            } else if ([testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#QueryEvaluationTest"] || [testtype.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#UpdateEvaluationTest"]) {
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
//            NSLog(@"test not approved: %@ (%@)", test, approval);
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
    SPKBlankNodeRenamer* renamer    = [[SPKBlankNodeRenamer alloc] init];
    if ([filename hasSuffix:@".ttl"] || [filename hasSuffix:@".nt"]) {
//      GTWIRI* base     = [[GTWIRI alloc] initWithValue:filename];
        SPKSPARQLLexer* lexer   = [[SPKSPARQLLexer alloc] initWithFileHandle:fh];
        id<GTWRDFParser> parser  = [[SPKTurtleParser alloc] initWithLexer:lexer base:base];
        //  NSLog(@"parsing data with %@", parser);
        __block NSUInteger count    = 0;
        NSError* error  = nil;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            GTWQuad* q   = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:(id<GTWQuad>)[renamer renameObject:q inContext:ctx] error:nil];
        } error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        //  NSLog(@"%lu total quads\n", count);
    } else {
        NSData* data            = [fh readDataToEndOfFile];
        NSError* error  = nil;
        Class SPKRedlandParser      = [SPKSPARQLPluginHandler pluginClassWithName:@"GTWRedlandParser"];
        if (!SPKRedlandParser) {
            NSLog(@"Redland parser plugin not available.");
            return;
        }
        id<GTWRDFParser> parser     = [SPKRedlandParser alloc];
        parser  = [parser initWithData:data base:base];
//            id<GTWRDFParser> parser = [[SPKRedlandParser alloc] initWithData:data inFormat:@"rdfxml" base: base WithRaptorWorld:raptor_world_ptr];
        
        
        
        //  NSLog(@"parsing data with %@", parser);
        __block NSUInteger count    = 0;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            GTWQuad* q   = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:(id<GTWQuad>)[renamer renameObject:q inContext:ctx] error:nil];
        } error:&error];
        //  NSLog(@"%lu total quads\n", count);
        if (error) {
            NSLog(@"parser error: %@", error);
        }
    }
}

- (void) loadDatasetFromAlgebra: (id<SPKTree>) algebra intoStore: (id<GTWQuadStore, GTWMutableQuadStore>) store defaultGraph: (GTWIRI*) defaultGraph base: (id<GTWIRI>) base {
    if ([algebra.type isEqual:kAlgebraDataset]) {
        id<SPKTree> pair        = algebra.treeValue;
        id<SPKTree> defSet      = pair.arguments[0];
        id<SPKTree> namedSet    = pair.arguments[1];
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
            for (id<SPKTree> t in algebra.arguments) {
                [self loadDatasetFromAlgebra:t intoStore:store defaultGraph: defaultGraph base:base];
            }
        }
    }
}

- (id<SPKTree,GTWQueryPlan>) queryPlanForEvalTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model testStore: (id<GTWQuadStore, GTWMutableQuadStore>) testStore defaultGraph: (GTWIRI*) defaultGraph hasService: (BOOL*) serviceFlag {
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
        GTWIRI* utrequest       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#request"];
        GTWIRI* utdata          = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#data"];
        GTWIRI* utgraph         = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#graph"];
        GTWIRI* utgraphdata     = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#graphData"];
        GTWIRI* rdfslabel       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2000/01/rdf-schema#label"];
        
        id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
        
        id<GTWTerm> query   = [model anyObjectForSubject:action predicate:qtquery graph:nil];
        id<GTWTerm> update  = [model anyObjectForSubject:action predicate:utrequest graph:nil];
        NSArray* data       = [model objectsForSubject:action predicate:(update ? utdata : qtdata) graph:nil];
        NSArray* graphData  = [model objectsForSubject:action predicate:(update ? utgraphdata : qtgraphdata) graph:nil];
        NSArray* serviceData    = [model objectsForSubject:action predicate:qtservicedata graph:nil];
        for (id<GTWIRI> datafile in data) {
            if (self.verbose) {
                NSLog(@"data file: %@", datafile.value);
            }
            [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:defaultGraph base: datafile];
        }
        if (update) {
            for (id<GTWTerm> g in graphData) {
                id<GTWIRI> datafile     = (id<GTWIRI>) [model anyObjectForSubject:g predicate:utgraph graph:nil];
                id<GTWTerm> graphname   = [model anyObjectForSubject:g predicate:rdfslabel graph:nil];
                if (self.verbose) {
                    NSLog(@"named graph data file: %@ for graph %@", datafile.value, graphname.value);
                }
                GTWIRI* graph   = [[GTWIRI alloc] initWithValue:graphname.value];
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:graph base: datafile];
            }
        } else {
            for (id<GTWIRI> datafile in graphData) {
                if (self.verbose) {
                    NSLog(@"named graph data file: %@", datafile.value);
                }
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:testStore withGraph:datafile base: datafile];
            }
        }
        for (id<GTWTerm> data in serviceData) {
            [NSURLProtocol registerClass:[GTWSPARQLTestHarnessURLProtocol class]];
            [GTWSPARQLTestHarnessURLProtocol mockBadEndpoint:[NSURL URLWithString:@"http://invalid.endpoint.org/sparql"]];
            *serviceFlag        = YES;
            id<GTWTerm> ep      = [model anyObjectForSubject:data predicate:qtendpoint graph:nil];
            NSArray* dataFiles  = [model objectsForSubject:data predicate:qtdata graph:nil];
            id<GTWQuadStore, GTWMutableQuadStore>   epstore   = [[SPKMemoryQuadStore alloc] init];
            for (id<GTWIRI> datafile in dataFiles) {
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:epstore withGraph:defaultGraph base: datafile];
            }
            NSURL* endpoint     = [NSURL URLWithString:ep.value];
            id<GTWModel> model  = [[SPKQuadModel alloc] initWithQuadStore:epstore];
            [GTWSPARQLTestHarnessURLProtocol mockEndpoint:endpoint withModel:model defaultGraph: defaultGraph];
        }
        NSString* requestType   = (update ? @"update" : @"query");
        NSString* requestFile   = (update ? update.value : query.value);
        
        NSError* error;
        NSFileHandle* fh            = [NSFileHandle fileHandleForReadingFromURL:[NSURL URLWithString:requestFile] error:&error];
        if (error) {
            NSLog(@"Failed to open %@ file: %@", requestType, error);
            return nil;
        }
        NSData* contents            = [fh readDataToEndOfFile];
        NSString* sparql            = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
        if (self.verbose)
            NSLog(@"%@ file: %@", requestType, requestFile);
        
        if (self.verbose)
            NSLog(@"SPARQL:\n%@", sparql);
        
        id<SPKTree> algebra     = (update)
                                ? [parser parseSPARQLQuery:sparql withBaseURI:requestFile error:&error]
                                : [parser parseSPARQLUpdate:sparql withBaseURI:requestFile error:&error];
        if (error) {
            NSLog(@"Failed to parse eval %@ file: %@", requestType, error);
            return nil;
        }
        
        if (!algebra) {
            NSLog(@"no algebra produced by parser for %@: %@", requestType, requestFile);
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
        
        id<GTWModel> testModel  = [[SPKQuadModel alloc] initWithQuadStore:testStore];
        
        if (self.verbose)
            NSLog(@"%@:\n%@", requestType, algebra);
        
        SPKQueryPlanner* planner    = [[SPKQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        id<SPKTree, GTWQueryPlan> plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel:testModel options:nil];
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

- (id<SPKTree>) queryAlgebraForSyntaxTest: (id<GTWTerm>) test withModel: (id<GTWModel>) model error: (NSError**) error {
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

        
        
        id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
        
        
        
        id<SPKTree> algebra            = [parser parseSPARQLQuery:sparql withBaseURI:action.value error:error];
        if (!algebra) {
//            NSLog(@"failed to parse syntax query: %@", action.value);
            return nil;
        }
        
        return algebra;
        
//        GTWIRI* data    = [[GTWIRI alloc] initWithValue:@"http://base.example.org/"];
//        SPKQueryPlanner* planner    = [[SPKQueryPlanner alloc] init];
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
    id<SPKTree> algebra = [self queryAlgebraForSyntaxTest: test withModel: model error:&error];
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
    SPKMemoryQuadStore* testStore   = [[SPKMemoryQuadStore alloc] init];
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue:@"tag:kasei.us,2013;default-graph"];
    BOOL hasService = NO;
    id<SPKTree,GTWQueryPlan> plan   = [self queryPlanForEvalTest: test withModel: model testStore:testStore defaultGraph: defaultGraph hasService:&hasService];
    SPKQuadModel* testModel         = [[SPKQuadModel alloc] initWithQuadStore:testStore];
    if (plan) {
        id<GTWQueryEngine> engine   = [[SPKSimpleQueryEngine alloc] init];
        
        if (NO) {
            __block NSUInteger count    = 0;
            NSLog(@"Quads:\n");
            [testModel enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q){
                count++;
                NSLog(@"-> %@\n", q);
            } error:nil];
            NSLog(@"%lu total quads\n", count);
        }
        
        id<GTWSerializer> s;
        Class resultsClass  = [(SPKTree*) plan planResultClass];
        if ([resultsClass isEqual: [NSDictionary class]]) {
            s    = [[SPKSPARQLResultsTextTableSerializer alloc] init];
        } else if ([resultsClass isEqual: [GTWTriple class]]) {
            s   = [[SPKNTriplesSerializer alloc] init];
        } else if ([resultsClass isEqual: [NSNumber class]]) {
            // update operation
        } else {
            NSLog(@"*** Don't know how to handle results of type %@", resultsClass);
            return NO;
        }
        
        GTWIRI* mfresult = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#result"];
        id<GTWTerm> result          = [model anyObjectForSubject:test predicate:mfresult graph:nil];
        // TODO: for update tests, this is a bnode with info on the resulting graphstore, not a results filename
        
        NSArray* expected;
        NSMutableSet* vars      = [NSMutableSet set];


        NSArray* got;
        if ([result isKindOfClass:[GTWIRI class]]) {
            got     = [[engine evaluateQueryPlan:plan withModel:testModel] allObjects];

            NSString* resultsFilename   = [[NSURL URLWithString:result.value] path];
            NSFileHandle* fh            = [NSFileHandle fileHandleForReadingAtPath:resultsFilename];
            if (self.verbose) {
                NSLog(@"Results file: %@", resultsFilename);
            }
            Class RDFParserClass   = [SPKSPARQLPluginHandler parserForFilename:resultsFilename conformingToProtocol:@protocol(GTWRDFParser)];
            Class SPARQLParserClass   = [SPKSPARQLPluginHandler parserForFilename:resultsFilename conformingToProtocol:@protocol(GTWSPARQLResultsParser)];
            if (RDFParserClass) {
    //            NSLog(@"-> Parsing RDF results format from %@", resultsFilename);
                NSMutableArray* triples = [NSMutableArray array];
                GTWIRI* base                = [[GTWIRI alloc] initWithValue:[NSString stringWithFormat:@"file://%@", resultsFilename]];
                __block BOOL sparqlResults  = NO;
                NSData* data                = [fh readDataToEndOfFile];
                id<GTWRDFParser> parser = [[RDFParserClass alloc] initWithData:data base:base];
                NSError* error;
                [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                    if ([t.object.value isEqualToString:@"http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet"]) {
                        sparqlResults   = YES;
                    }
                    [triples addObject:t];
                } error:&error];
                
                if (sparqlResults) {
                    expected    = [self SPARQLResultsEnumeratorFromTriples:triples settingVariables: vars];
                } else {
                    expected    = triples;
                }
            } else if (SPARQLParserClass) {
    //            NSLog(@"-> Parsing SPARQL Results format from %@", resultsFilename);
                NSData* data                = [fh readDataToEndOfFile];
                id<GTWSPARQLResultsParser> parser   = [[SPARQLParserClass alloc] init];
                expected    = [[parser parseResultsFromData: data settingVariables: vars] allObjects];
            }
        } else {
            [[engine evaluateQueryPlan:plan withModel:testModel] allObjects];
            {
                NSMutableArray* quads   = [NSMutableArray array];
                [testModel enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
                    [quads addObject:q];
                } error:nil];
                got = [quads copy];
//                NSLog(@"------> Got %@", got);
            }
            
            GTWIRI* utdata          = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#data"];
            GTWIRI* utgraph         = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#graph"];
            GTWIRI* utgraphdata     = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2009/sparql/tests/test-update#graphData"];
            GTWIRI* rdfslabel       = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/2000/01/rdf-schema#label"];
            NSArray* data           = [model objectsForSubject:result predicate:utdata graph:nil];
            NSArray* graphData      = [model objectsForSubject:result predicate:utgraphdata graph:nil];
            SPKMemoryQuadStore* expectStore = [[SPKMemoryQuadStore alloc] init];
            for (id<GTWIRI> datafile in data) {
                if (self.verbose) {
                    NSLog(@"data file: %@", datafile.value);
                }
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:expectStore withGraph:defaultGraph base: datafile];
            }
            for (id<GTWTerm> g in graphData) {
                id<GTWIRI> datafile     = (id<GTWIRI>) [model anyObjectForSubject:g predicate:utgraph graph:nil];
                id<GTWTerm> graphname   = [model anyObjectForSubject:g predicate:rdfslabel graph:nil];
                if (self.verbose) {
                    NSLog(@"named graph data file: %@ for graph %@", datafile.value, graphname.value);
                }
                GTWIRI* graph   = [[GTWIRI alloc] initWithValue:graphname.value];
                [self loadFile:[[NSURL URLWithString:datafile.value] path] intoStore:expectStore withGraph:graph base: datafile];
            }
            
            {
                NSMutableArray* quads   = [NSMutableArray array];
                [expectStore enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
                    [quads addObject:q];
                } error:nil];
                expected    = [quads copy];
//                NSLog(@"------> Expected %@", expected);
            }
        }
        
        
        NSError* reason;
        if ([GTWGraphIsomorphism graphEnumerator:[got objectEnumerator] isomorphicWith:[expected objectEnumerator] canonicalize:YES reason:&reason]) {
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
//                        NSLog(@"plan: %@", plan);
                        NSSet* variables    = [plan inScopeVariables];
                        NSData* data;
                        if ([resultsClass isEqual: [GTWTriple class]]) {
                            data    = [(id<GTWTriplesSerializer>)s dataFromTriples:[got objectEnumerator]];
                        } else if ([resultsClass isEqual: [NSDictionary class]]) {
                            data    = [(id<GTWSPARQLResultsSerializer>)s dataFromResults:[got objectEnumerator] withVariables:variables];
                        } else {
                            data    = [[got description] dataUsingEncoding:NSUTF8StringEncoding];
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
                        } else if ([resultsClass isEqual: [NSDictionary class]]) {
                            data    = [(id<GTWSPARQLResultsSerializer>)s dataFromResults:[expected objectEnumerator] withVariables:variables];
                        } else {
                            data    = [[expected description] dataUsingEncoding:NSUTF8StringEncoding];
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
    
    SPKMemoryQuadStore* store   = [[SPKMemoryQuadStore alloc] init];
    NSString* ctx           = [NSString stringWithFormat:@"%lu", self.RDFLoadCount++];
    SPKBlankNodeRenamer* renamer    = [[SPKBlankNodeRenamer alloc] init];
    for (id<GTWTriple> t in triples) {
        GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:defaultGraph];
        [store addQuad:(id<GTWQuad>)[renamer renameObject:q inContext:ctx] error:nil];
    }
    SPKQuadModel* model = [[SPKQuadModel alloc] initWithQuadStore:store];
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
