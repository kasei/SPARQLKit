#include <pthread.h>
#include <librdf.h>
#include <CoreFoundation/CoreFoundation.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWRedlandTripleStore.h"
#import "GTWTurtleParser.h"
#import "GTWRasqalSPARQLParser.h"
#import "GTWQuadModel.h"
#import "GTWTripleModel.h"
#import "GTWQueryPlanner.h"
#import "GTWRedlandParser.h"
#import "GTWExpression.h"
#import "NSObject+NSDictionary_QueryBindings.h"
#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLDataSourcePlugin.h"
#import "GTWSPARQLDataSourcePlugin.h"
#import "GTWSimpleQueryEngine.h"
#import "GTWSPARQLResultsTextTableSerializer.h"
#import "GTWSPARQLResultsXMLSerializer.h"
#import "GTWSPARQLParser.h"

rasqal_world* rasqal_world_ptr;
librdf_world* librdf_world_ptr;
raptor_world* raptor_world_ptr;

NSString* fileContents (NSString* filename) {
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data        = [fh readDataToEndOfFile];
    NSString* string    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

int loadRDFFromFileIntoStore (id<GTWMutableQuadStore> store, NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    GTWTurtleLexer* l   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
    
    if (NO) {
        GTWSPARQLToken* t;
        while ((t = [l getToken])) {
            NSLog(@"token: %@\n", t);
        }
        return 0;
    }
    
    //    [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
    
    
    
    GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:base];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithIRI:base];
    GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
    if (p) {
        //    NSLog(@"parser: %p\n", p);
        [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
//            NSLog(@"parsed quad: %@", q);
            [store addQuad:q error:nil];
        } error:nil];
//        NSLog(@"-- ");
    } else {
        NSLog(@"Could not construct parser");
    }
    
    return 0;
}

int run_memory_quad_store_example(NSString* filename, NSString* base) {
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    loadRDFFromFileIntoStore(store, filename, base);
    
//    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
//    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
//    GTWIRI* type  =[[GTWIRI alloc] initWithIRI:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
    
    NSLog(@"Graphs:\n");
    [store enumerateGraphsUsingBlock:^(id<GTWTerm> g){
        NSLog(@"-> %@\n", g);
    } error:nil];
    NSLog(@"\n\n");
    
    //    {
    //        __block NSUInteger count    = 0;
    //        NSLog(@"Quads:\n");
    //        [store enumerateQuadsMatchingSubject:greg predicate:rdftype object:nil graph:nil usingBlock:^(id<GTWQuad> q){
    //            count++;
    //            NSLog(@"-> %@\n", q);
    //        } error:nil];
    //        NSLog(@"%lu total quads\n", count);
    //    }
    //
    //
    //    GTWQuad* q  = [[GTWQuad alloc] initWithSubject:greg predicate:rdftype object:type graph:graph];
    //    [store removeQuad:q error:nil];
    //
    //
    //
    //    {
    //        __block NSUInteger count    = 0;
    //        NSLog(@"Quads:\n");
    //        [store enumerateQuadsMatchingSubject:greg predicate:rdftype object:nil graph:nil usingBlock:^(NSObject<GTWQuad>* q){
    //            count++;
    //            NSLog(@"-> %@\n", q);
    //            //            NSLog(@"      subject -> %@\n", [q valueForKey: @"subject"]);
    //        } error:nil];
    //        NSLog(@"%lu total quads\n", count);
    //    }
    
    //    [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
    //    [store addIndexType: @"term" value:@[@"object"] synchronous:YES error: nil];
    //    [store addIndexType: @"term" value:@[@"graph", @"subject"] synchronous:YES error: nil];
    NSLog(@"%@", store);
    //    NSLog(@"best index for S___: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:nil graph:nil]);
    //    NSLog(@"best index for ___G: %@\n", [store bestIndexForMatchingSubject:nil predicate:nil object:nil graph:greg]);
    //    NSLog(@"best index for SPO_: %@\n", [store bestIndexForMatchingSubject:greg predicate:rdftype object:type graph:nil]);
    //    NSLog(@"best index for S_O_: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:type graph:nil]);
    return 0;
}

int run_redland_triple_store_example (NSString* filename, NSString* base) {
	librdf_world* librdf_world_ptr	= librdf_new_world();
    GTWRedlandTripleStore* store    = [[GTWRedlandTripleStore alloc] initWithName:@"db1" redlandPtr:librdf_world_ptr];
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    GTWTurtleLexer* l   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
    
//    GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:@"http://graph.kasei.us/"];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithIRI:base];
    GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
    //    NSLog(@"parser: %p\n", p);
    if (p) {
        id<GTWTriple> t   = nil;
        while ((t = [p nextObject])) {
            [store addTriple:t error:nil];
        }
        //        NSLog(@"%lu total triples", count);
    } else {
        NSLog(@"Could not construct parser");
    }
    
    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
//    GTWIRI* type  =[[GTWIRI alloc] initWithIRI:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
    
    {
        __block NSUInteger count    = 0;
        NSLog(@"Quads:\n");
        [store enumerateTriplesMatchingSubject:greg predicate:rdftype object:nil usingBlock:^(id<GTWTriple> t){
            count++;
            NSLog(@"-> %@\n", t);
        } error:nil];
        NSLog(@"%lu total quads\n", count);
    }

    librdf_free_world(librdf_world_ptr);
//    NSLog(@"%@", store);
    return 0;
}

int run_redland_parser_example (NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data            = [fh readDataToEndOfFile];
    id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"turtle" base: nil WithRaptorWorld:raptor_world_ptr];
    {
        __block NSUInteger count    = 0;
        NSError* error  = nil;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            NSLog(@"-> %@\n", t);
        } error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        NSLog(@"%lu total quads\n", count);
    }
    
//    NSLog(@"%@", store);
    return 0;
}

int runQueryWithModelAndDataset (NSString* query, NSString* base, id<GTWModel> model, id<GTWDataset> dataset) {
    id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
    GTWTree* algebra    = [parser parseSPARQL:query withBaseURI:base];
    if (YES) {
        NSLog(@"query:\n%@", algebra);
    }
    
    GTWQueryPlanner* planner        = [[GTWQueryPlanner alloc] init];
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
    if (YES) {
        NSLog(@"plan:\n%@", plan);
    }
    
    [plan computeProjectVariables];
    
    NSLog(@"executing query...");
    id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
    NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
    id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsTextTableSerializer alloc] init];
//    id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsXMLSerializer alloc] init];
    NSSet* variables    = [plan annotationForKey:kProjectVariables];
    
    NSData* data        = [s dataFromResults:e withVariables:variables];
    fwrite([data bytes], [data length], 1, stdout);
//    NSArray* results    = [e allObjects];
//    printResultsTable(stdout, results, variables);
    return 0;
}

int parseQuery(NSString* query, NSString* base) {
    NSLog(@"Query string:\n%@\n\n", query);
    
    GTWIRI* graph               = [[GTWIRI alloc] initWithIRI: base];
    //    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    //    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    GTWDataset* dataset         = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
    GTWTree* algebra            = [parser parseSPARQL:query withBaseURI:base];
    NSLog(@"Query algebra:\n%@\n\n", algebra);
    
    GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
    NSLog(@"Query plan:\n%@\n\n", plan);
    
    [plan computeProjectVariables];
    return 0;
}

int lexQuery(NSString* query, NSString* base) {
    NSLog(@"Query string:\n%@\n\n", query);
    
    GTWIRI* graph               = [[GTWIRI alloc] initWithIRI: base];
    //    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    //    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    GTWDataset* dataset         = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    GTWSPARQLLexer* l           = [[GTWSPARQLLexer alloc] initWithString:query];
    
    NSLog(@"Query tokens:\n-----------------------\n");
    GTWSPARQLToken* t;
    while ((t = [l getToken])) {
        NSLog(@"%@\n", t);
    }
    return 0;
}

int runQuery(NSString* query, NSString* filename, NSString* base) {
    GTWIRI* graph = [[GTWIRI alloc] initWithIRI: base];
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];

    {
        NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
        NSData* data            = [fh readDataToEndOfFile];
        id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" base: nil WithRaptorWorld:raptor_world_ptr];
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:q error:nil];
        } error:nil];
    }
    
//    loadFile(store, filename, base, @"rdfxml");
    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
//    GTWAddressBookTripleStore* store    = [[GTWAddressBookTripleStore alloc] init];
//    GTWTripleModel* model   = [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName: graph];
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    return runQueryWithModelAndDataset(query, base, model, dataset);
}

int main(int argc, const char * argv[]) {
    srand([[NSDate date] timeIntervalSince1970]);
	rasqal_world_ptr	= rasqal_new_world();
	if(!rasqal_world_ptr || rasqal_world_open(rasqal_world_ptr)) {
		fprintf(stderr, "*** rasqal_world init failed\n");
		return(1);
	}
	librdf_world_ptr	= librdf_new_world();
    //	librdf_world_set_error(librdf_world_ptr, NULL, _librdf_error_cb);
	raptor_world_ptr = rasqal_world_get_raptor(rasqal_world_ptr);
    
    // ------------------------------------------------------------------------------------------------------------------------
    NSMutableDictionary* datasources    = [NSMutableDictionary dictionary];
    NSArray* datasourcelist = [GTWSPARQLDataSourcePlugin loadAllPlugins];
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
//        NSDictionary* dict = [NSDictionary dictionary];
//        NSLog(@"%@", [[d alloc] initWithDictionary:dict]);
    }
    // ------------------------------------------------------------------------------------------------------------------------
    
    
    if (argc == 1) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "    %s qparse QUERY-FILE\n", argv[0]);
        fprintf(stderr, "    %s query QUERY-STRING data.rdf\n", argv[0]);
        fprintf(stderr, "    %s queryfile query.rq data.rdf\n", argv[0]);
        fprintf(stderr, "    %s test triple\n", argv[0]);
        fprintf(stderr, "    %s test quad\n", argv[0]);
        fprintf(stderr, "    %s test endpoint\n", argv[0]);
        fprintf(stderr, "    %s test parser data.rdf base-uri\n", argv[0]);
        fprintf(stderr, "    %s testsuite\n", argv[0]);
        fprintf(stderr, "    %s sources\n", argv[0]);
        fprintf(stderr, "\n");
        exit(1);
    }
    
    if (!strcmp(argv[1], "query")) {
        NSString* query     = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[3]];
        runQuery(query, filename, @"http://query-base.example.com/");
    } else if (!strcmp(argv[1], "qparse")) {
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* query     = fileContents(filename);
        NSString* base      = (argc > 3) ? [NSString stringWithFormat:@"%s", argv[3]] : @"http://query-base.example.com/";
        parseQuery(query, base);
    } else if (!strncmp(argv[1], "lex", 3)) {
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* query     = fileContents(filename);
        NSString* base      = (argc > 3) ? [NSString stringWithFormat:@"%s", argv[3]] : @"http://query-base.example.com/";
        lexQuery(query, base);
    } else if (!strcmp(argv[1], "queryfile")) {
        NSString* query     = fileContents([NSString stringWithFormat:@"%s", argv[2]]);
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[3]];
        runQuery(query, filename, @"http://query-base.example.com/");
    } else if (!strcmp(argv[1], "sources")) {
        fprintf(stdout, "Available data sources:\n");
        for (id s in datasources) {
            fprintf(stdout, "- %s\n", [[datasources[s] description] UTF8String]);
        }
    } else if (!strcmp(argv[1], "test")) {
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* base      = [NSString stringWithFormat:@"%s", argv[3]];
        if (!strcmp(argv[2], "parser")) {
            run_redland_parser_example(filename, base);
        } else if (!strcmp(argv[2], "endpoint")) {
            NSDictionary* dict              = @{@"endpoint": @"http://myrdf.us/sparql11"};
            id<GTWTripleStore> store        = [[[datasources objectForKey:@"GTWSPARQLProtocolStore"] alloc] initWithDictionary:dict];
            GTWVariable* s  = [[GTWVariable alloc] initWithName:@"s"];
            GTWVariable* o  = [[GTWVariable alloc] initWithName:@"o"];
            GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            NSError* error  = nil;
            [store enumerateTriplesMatchingSubject:s predicate:rdftype object:o usingBlock:^(id<GTWTriple> t) {
                ;
            } error:&error];
            if (error) {
                NSLog(@"error: %@", error);
            }
        } else if (!strcmp(argv[2], "triple")) {
            run_redland_triple_store_example(filename, base);
        } else {
            run_memory_quad_store_example(filename, base);
        }
    } else if (!strcmp(argv[1], "testsuite")) {
        GTWSPARQLTestHarness* harness   = [[GTWSPARQLTestHarness alloc] init];
        NSString* pattern   = (argc > 2) ? [NSString stringWithFormat:@"%s", argv[2]] : nil;
        harness.runEvalTests    = NO;
        harness.runSyntaxTests  = YES;
        if (pattern) {
            [harness runTestsMatchingPattern: pattern fromManifest:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg11/manifest-all.ttl" ];
        } else {
            [harness runTestsFromManifest:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg11/manifest-all.ttl"];
        }
    } else if (!strcmp(argv[1], "-")) {
        NSString* filenamea  = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* filenameb  = [NSString stringWithFormat:@"%s", argv[3]];
        NSString* base      = [NSString stringWithFormat:@"%s", argv[4]];
        GTWMemoryQuadStore* storea   = [[GTWMemoryQuadStore alloc] init];
        GTWMemoryQuadStore* storeb   = [[GTWMemoryQuadStore alloc] init];
        loadRDFFromFileIntoStore(storea, filenamea, base);
        loadRDFFromFileIntoStore(storeb, filenameb, base);
        GTWQuadModel* modela         = [[GTWQuadModel alloc] initWithQuadStore:storea];
        GTWQuadModel* modelb         = [[GTWQuadModel alloc] initWithQuadStore:storeb];
        [modela isEqual:modelb];
    }
}

