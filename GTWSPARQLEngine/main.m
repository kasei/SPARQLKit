#include <pthread.h>
#include <librdf.h>
#include <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWRedlandTripleStore.h"
#import "GTWTurtleParser.h"
#import "GTWRasqalSPARQLParser.h"
#import "GTWSPARQLParser.h"
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
#import "GTWNTriplesSerializer.h"
#import "GTWNQuadsSerializer.h"

rasqal_world* rasqal_world_ptr;
librdf_world* librdf_world_ptr;
raptor_world* raptor_world_ptr;

static NSString* kDefaultBase    = @"http://base.example.com/";

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
    
    
    GTWIRI* g = [[GTWIRI alloc] initWithIRI:@"http://example.org/"];
    GTWTripleModel* model = [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName:g];
    id<GTWTriplesSerializer> s    = [[GTWNTriplesSerializer alloc] init];
//    NSLog(@"model: %@\n--------------\n", model);
    NSEnumerator* e = [model quadsMatchingSubject:nil predicate:nil object:nil graph:nil error:nil];
    NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
    [s serializeTriples:e toHandle:out];
    
    
//    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
//    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
////    GTWIRI* type  =[[GTWIRI alloc] initWithIRI:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
//    
//    {
//        __block NSUInteger count    = 0;
//        NSLog(@"Quads:\n");
//        [store enumerateTriplesMatchingSubject:greg predicate:rdftype object:nil usingBlock:^(id<GTWTriple> t){
//            count++;
//            NSLog(@"-> %@\n", t);
//        } error:nil];
//        NSLog(@"%lu total quads\n", count);
//    }

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

int runQueryWithModelAndDataset (NSString* query, NSString* base, id<GTWModel> model, id<GTWDataset> dataset, NSUInteger verbose) {
    id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
    NSError* error;
    id<GTWTree> algebra    = [parser parseSPARQL:query withBaseURI:base error:&error];
    if (verbose) {
        NSLog(@"query:\n%@", algebra);
    }
    
    GTWQueryPlanner* planner        = [[GTWQueryPlanner alloc] init];
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model optimize: YES];
    if (verbose) {
        NSLog(@"plan:\n%@", plan);
    }
    
    NSSet* variables    = [plan inScopeVariables];
    if (verbose) {
        NSLog(@"executing query...");
    }
    id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
    NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
    id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsTextTableSerializer alloc] init];
//    id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsXMLSerializer alloc] init];
    
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
    NSError* error;
    id<GTWTree> algebra            = [parser parseSPARQL:query withBaseURI:base error:&error];
    if (error) {
        NSLog(@"Parse error: %@", error);
        return 1;
    }
    NSLog(@"Query algebra:\n%@\n\n", algebra);
    
    id<GTWQuadStore> store      = [[GTWMemoryQuadStore alloc] init];
    id<GTWModel> model          = [[GTWQuadModel alloc] initWithQuadStore:store];
    GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
    GTWTree<GTWTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model optimize: YES];
    NSLog(@"Query plan:\n%@\n\n", plan);
    return 0;
}

int lexQuery(NSString* query, NSString* base) {
    NSLog(@"Query string:\n%@\n\n", query);
    
//    GTWIRI* graph               = [[GTWIRI alloc] initWithIRI: base];
//    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
//    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
//    GTWDataset* dataset         = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    GTWSPARQLLexer* l           = [[GTWSPARQLLexer alloc] initWithString:query];
    
    NSLog(@"Query tokens:\n-----------------------\n");
    GTWSPARQLToken* t;
    while ((t = [l getToken])) {
        NSLog(@"%@\n", t);
    }
    return 0;
}

int runQuery(NSString* query, NSString* filename, NSString* base, NSUInteger verbose) {
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
    return runQueryWithModelAndDataset(query, base, model, dataset, verbose);
}

int usage(int argc, const char * argv[]) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "    %s qparse QUERY-FILE\n", argv[0]);
    fprintf(stderr, "    %s query config-json-string QUERY-STRING\n", argv[0]);
    fprintf(stderr, "    %s queryfile query.rq data.rdf\n", argv[0]);
    fprintf(stderr, "    %s test triple\n", argv[0]);
    fprintf(stderr, "    %s test quad\n", argv[0]);
    fprintf(stderr, "    %s test endpoint\n", argv[0]);
    fprintf(stderr, "    %s test parser data.rdf base-uri\n", argv[0]);
    fprintf(stderr, "    %s testsuite [-m path/to/manifest.ttl] [PATTERN]\n", argv[0]);
    fprintf(stderr, "    %s grapheq data1.rdf data2.rdf base-uri\n", argv[0]);
    fprintf(stderr, "    %s dump [config-json-string]\n", argv[0]);
    fprintf(stderr, "    %s sources\n", argv[0]);
    fprintf(stderr, "\n");
    return 0;
}

id<GTWModel> modelFromSourceWithConfigurationString(NSDictionary* datasources, NSString* config, GTWIRI* defaultGraph, Class* class) {
    NSData* data        = [config dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error      = nil;
    
    NSString* sourceName;
    NSDictionary* dict  = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSRange range       = [config rangeOfString:@"^\\s*[A-Za-z0-9]+$" options:NSRegularExpressionSearch];
        if (range.location == 0 && range.length == [config length]) {
            sourceName  = config;
            dict        = @{};
        } else {
            NSLog(@"Error parsing data source configuration string: %@", error);
            return nil;
        }
    }
    
    if (!sourceName)
        sourceName  = dict[@"storetype"];
    
    Class c = [datasources objectForKey:sourceName];
    *class  = c;
    if (!c) {
        NSLog(@"No data source class found with ID '%@'", sourceName);
        return nil;
    }
    
    NSSet* protocols    = [c implementedProtocols];
    if ([protocols containsObject:@protocol(GTWTripleStore)]) {
        id<GTWTripleStore> store = [[c alloc] initWithDictionary:dict];
        if (!store) {
            NSLog(@"Failed to create triple store from source '%@'", c);
            return nil;
        }
        return [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName:defaultGraph];
    } else {
        id<GTWQuadStore> store = [[c alloc] initWithDictionary:dict];
        if (!store) {
            NSLog(@"Failed to create triple store from source '%@'", c);
            return nil;
        }
        return [[GTWQuadModel alloc] initWithQuadStore:store];
    }
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
    NSArray* plugins    = [GTWSPARQLDataSourcePlugin loadAllPlugins];
    NSMutableArray* datasourcelist  = [NSMutableArray arrayWithArray:plugins];
    [datasourcelist addObject:[GTWMemoryQuadStore class]];
    
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
//        NSDictionary* dict = [NSDictionary dictionary];
//        NSLog(@"%@", [[d alloc] initWithDictionary:dict]);
    }
    // ------------------------------------------------------------------------------------------------------------------------
    
    
    if (argc == 1) {
        return usage(argc, argv);
    } else if (argc == 2 && !strcmp(argv[1], "--help")) {
        return usage(argc, argv);
    }
    
    NSUInteger stress   = 0;
    NSUInteger concurrent   = 0;
    NSUInteger verbose  = 0;
    NSUInteger argi     = 1;
    NSString* op        = [NSString stringWithFormat:@"%s", argv[argi++]];
    
    while (argc > argi && argv[argi][0] == '-') {
        if (!strcmp(argv[argi], "-v")) {
            verbose     = 1;
            argi++;
        } else if (!strcmp(argv[argi], "-j")) {
            concurrent  = 1;
            argi++;
        } else if (!strcmp(argv[argi], "-J")) {
            concurrent  = 1;
            stress      = 1;
            argi++;
        } else {
            break;
        }
    }
    
    if (verbose) {
        fprintf(stdout, "# %s\n", argv[0]);
    }
    
    if ([op isEqual: @"query"]) {
        if (argc < (argi+2)) {
            NSLog(@"query operation must be supplied with both a data source configuration string and a query.");
            return 1;
        }
        NSString* config    = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* query     = [NSString stringWithFormat:@"%s", argv[argi++]];
//        NSString* filename  = [NSString stringWithFormat:@"%s", argv[argi++]];

        Class c;
        GTWIRI* defaultGraph   = [[GTWIRI alloc] initWithIRI: kDefaultBase];
        id<GTWModel> model  = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        return runQueryWithModelAndDataset(query, kDefaultBase, model, dataset, verbose);
    } else if ([op isEqual: @"qparse"]) {
        if (argc < (argi+1)) {
            NSLog(@"qparse operation must be supplied with a query filename.");
            return 1;
        }
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* query     = fileContents(filename);
        NSString* base      = (argc > argi) ? [NSString stringWithFormat:@"%s", argv[argi++]] : kDefaultBase;
        parseQuery(query, base);
    } else if ([op isEqual: @"lex"]) {
        if (argc < (argi+1)) {
            NSLog(@"lex operation must be supplied a query filename.");
            return 1;
        }
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* query     = fileContents(filename);
        NSString* base      = (argc > argi) ? [NSString stringWithFormat:@"%s", argv[argi++]] : kDefaultBase;
        lexQuery(query, base);
    } else if ([op isEqual: @"queryfile"]) {
        if (argc < (argi+2)) {
            NSLog(@"queryfile operation must be supplied both query and data filenames.");
            return 1;
        }
        NSString* query     = fileContents([NSString stringWithFormat:@"%s", argv[argi++]]);
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[argi++]];
        runQuery(query, filename, kDefaultBase, verbose);
    } else if ([op isEqual: @"dump"]) {
        if (argc < (argi+1)) {
            NSLog(@"dump operation must be supplied with a data source configuration string.");
            return 1;
        }
//        NSString* sourceName    = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* config;
        if (argc > argi) {
            config    = [NSString stringWithFormat:@"%s", argv[argi++]];
        } else {
            config      = @"{}";
        }
        
        Class c;
        GTWIRI* defaultGraph   = [[GTWIRI alloc] initWithIRI: kDefaultBase];
        id<GTWModel> model  = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);

        GTWVariable* s  = [[GTWVariable alloc] initWithName:@"s"];
        GTWVariable* p  = [[GTWVariable alloc] initWithName:@"p"];
        GTWVariable* o  = [[GTWVariable alloc] initWithName:@"o"];
        GTWVariable* g  = [[GTWVariable alloc] initWithName:@"g"];
        NSError* error  = nil;

        NSSet* protocols    = [c implementedProtocols];
        if ([protocols containsObject:@protocol(GTWTripleStore)]) {
            NSEnumerator* e = [model quadsMatchingSubject:s predicate:p object:o graph:defaultGraph error:&error];
            if (error) {
                NSLog(@"*** %@", error);
                return 1;
            }
            id<GTWTriplesSerializer> ser    = [[GTWNTriplesSerializer alloc] init];
            NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
            [ser serializeTriples:e toHandle:out];
        } else {
            NSEnumerator* e = [model quadsMatchingSubject:s predicate:p object:o graph:g error:&error];
            if (error) {
                NSLog(@"*** %@", error);
                return 1;
            }
            id<GTWQuadsSerializer> ser    = [[GTWNQuadsSerializer alloc] init];
            NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
            [ser serializeQuads:e toHandle:out];
        }
    } else if ([op isEqual: @"sources"]) {
        fprintf(stdout, "Available data sources:\n");
        for (id s in datasources) {
            Class c = datasources[s];
            fprintf(stdout, "%s\n", [[c description] UTF8String]);
            NSSet* protocols    = [c implementedProtocols];
            if ([protocols count]) {
                NSMutableArray* array   = [NSMutableArray array];
                for (Protocol* p in protocols) {
                    const char* name = protocol_getName(p);
                    [array addObject:[NSString stringWithFormat:@"%s", name]];
                }
                NSString* str   = [array componentsJoinedByString:@", "];
                fprintf(stdout, "  Protocols: %s\n", [str UTF8String]);
            }
            NSString* usage = [c usage];
            if (usage) {
                fprintf(stdout, "  Configuration template: %s\n\n", [usage UTF8String]);
            }
            
        }
    } else if ([op isEqual: @"test"]) {
        if (argc < (argi+3)) {
            NSLog(@"test operation must be supplied a test type, a data filename, and a base URI.");
            return 1;
        }
        NSString* testtype  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* base      = [NSString stringWithFormat:@"%s", argv[argi++]];
        if ([testtype isEqual: @"parser"]) {
            run_redland_parser_example(filename, base);
        } else if ([testtype isEqual: @"endpoint"]) {
            NSDictionary* dict              = @{@"endpoint": @"http://myrdf.us/sparql11"};
            id<GTWTripleStore> store        = [[[datasources objectForKey:@"GTWSPARQLProtocolStore"] alloc] initWithDictionary:dict];
            GTWIRI* graph = [[GTWIRI alloc] initWithIRI: kDefaultBase];
            GTWTripleModel* model           = [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName:graph];
            GTWVariable* s  = [[GTWVariable alloc] initWithName:@"s"];
            GTWVariable* o  = [[GTWVariable alloc] initWithName:@"o"];
            GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            NSError* error  = nil;
            NSEnumerator* e = [model quadsMatchingSubject:s predicate:rdftype object:o graph:graph error:&error];
            id<GTWTriplesSerializer> ser    = [[GTWNTriplesSerializer alloc] init];
            NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
            [ser serializeTriples:e toHandle:out];
        } else if ([testtype isEqual: @"triple"]) {
            run_redland_triple_store_example(filename, base);
        } else {
            run_memory_quad_store_example(filename, base);
        }
    } else if ([op isEqual: @"testsuite"]) {
        NSString* manifest  = @"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg11/manifest-all.ttl";
        if (argc > (argi+1) && !strcmp(argv[argi], "-m")) {
            ++argi;
            manifest    = [NSString stringWithFormat:@"%s", argv[argi++]];
        }
        NSString* pattern   = (argc > argi) ? [NSString stringWithFormat:@"%s", argv[argi++]] : nil;
        while (YES) {
            GTWSPARQLTestHarness* harness   = [[GTWSPARQLTestHarness alloc] initWithConcurrency:(concurrent ? YES : NO)];
            harness.verbose         = verbose;
            harness.runEvalTests    = YES;
            harness.runSyntaxTests  = YES;
            if (pattern) {
                [harness runTestsMatchingPattern:pattern fromManifest:manifest ];
            } else {
                [harness runTestsFromManifest:manifest];
            }
            if (!stress)
                break;
        }
    } else if ([op isEqual: @"grapheq"]) {
        if (argc < (argi+3)) {
            NSLog(@"grapheq operation must be supplied two data filenames and a base URI.");
            return 1;
        }
        NSString* filenamea  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* filenameb  = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* base      = [NSString stringWithFormat:@"%s", argv[argi++]];
        GTWMemoryQuadStore* storea   = [[GTWMemoryQuadStore alloc] init];
        GTWMemoryQuadStore* storeb   = [[GTWMemoryQuadStore alloc] init];
        loadRDFFromFileIntoStore(storea, filenamea, base);
        loadRDFFromFileIntoStore(storeb, filenameb, base);
        GTWQuadModel* modela         = [[GTWQuadModel alloc] initWithQuadStore:storea];
        GTWQuadModel* modelb         = [[GTWQuadModel alloc] initWithQuadStore:storeb];
        [modela isEqual:modelb];
    }
}
