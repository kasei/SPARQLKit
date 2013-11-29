#import <objc/runtime.h>
#import <SPARQLKit/SPARQLKit.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>
#import <GTWSWBase/GTWSPARQLResultsJSONParser.h>

#import <SPARQLKit/SPKMemoryQuadStore.h>
#import <SPARQLKit/SPKTurtleParser.h>
#import <SPARQLKit/SPKSPARQLParser.h>
#import <SPARQLKit/SPKQuadModel.h>
#import <SPARQLKit/SPKTripleModel.h>
#import <SPARQLKit/SPKQueryPlanner.h>
#import <SPARQLKit/SPKSPARQLPluginHandler.h>
#import <SPARQLKit/SPKSimpleQueryEngine.h>
#import <SPARQLKit/SPKSPARQLResultsTextTableSerializer.h>
#import <SPARQLKit/SPKNQuadsSerializer.h>

#import "GTWSPARQLTestHarness.h"
#import "SPKNTriplesSerializer.h"

#import <readline/readline.h>

// SPARQL Endpoint
#import "GTWSPARQLConnection.h"
#import "GTWSPARQLServer.h"
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

static NSString* kDefaultBase    = @"http://base.example.com/";

NSString* fileContents (NSString* filename) {
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data        = [fh readDataToEndOfFile];
    NSString* string    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

int loadRDFFromFileIntoStore (id<GTWMutableQuadStore> store, NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    SPKSPARQLLexer* l   = [[SPKSPARQLLexer alloc] initWithFileHandle:fh];
    
    if (NO) {
        SPKSPARQLToken* t;
        NSError* error;
        while ((t = [l getTokenWithError:&error])) {
            NSLog(@"token: %@\n", t);
        }
        if (error) {
            NSLog(@"Error parsing RDF: %@", error);
        }
        return 0;
    }
    
    //    [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
    
    GTWIRI* graph       = [[GTWIRI alloc] initWithValue:base];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithValue:base];
    SPKTurtleParser* p  = [[SPKTurtleParser alloc] initWithLexer:l base: baseuri];
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
    SPKMemoryQuadStore* store   = [[SPKMemoryQuadStore alloc] init];
    loadRDFFromFileIntoStore(store, filename, base);
    
    NSLog(@"Graphs:\n");
    [store enumerateGraphsUsingBlock:^(id<GTWTerm> g){
        NSLog(@"-> %@\n", g);
    } error:nil];
    NSLog(@"\n\n");
    
    if (NO) {
        GTWIRI* rdftype = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        GTWIRI* greg    = [[GTWIRI alloc] initWithValue:@"http://kasei.us/about/foaf.xrdf#greg"];
        GTWIRI* type  =[[GTWIRI alloc] initWithValue:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];

        [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
        [store addIndexType: @"term" value:@[@"object"] synchronous:YES error: nil];
        [store addIndexType: @"term" value:@[@"graph", @"subject"] synchronous:YES error: nil];

        NSLog(@"%@", store);
        NSLog(@"best index for S___: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:nil graph:nil]);
        NSLog(@"best index for ___G: %@\n", [store bestIndexForMatchingSubject:nil predicate:nil object:nil graph:greg]);
        NSLog(@"best index for SPO_: %@\n", [store bestIndexForMatchingSubject:greg predicate:rdftype object:type graph:nil]);
        NSLog(@"best index for S_O_: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:type graph:nil]);
    }
    return 0;
}

int run_redland_triple_store_example (NSString* filename, NSString* base) {
    Class GTWRedlandTripleStore = [SPKSPARQLPluginHandler pluginClassWithName:@"GTWRedlandTripleStore"];
    if (!GTWRedlandTripleStore) {
        NSLog(@"Redland triple store plugin not available.");
        return 1;
    }
    id<GTWTripleStore,GTWMutableTripleStore> store    = [[GTWRedlandTripleStore alloc] initWithDictionary:@{@"store_name": @"db1"}];
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    SPKSPARQLLexer* l   = [[SPKSPARQLLexer alloc] initWithFileHandle:fh];
    
//    GTWIRI* graph       = [[GTWIRI alloc] initWithValue:@"http://graph.kasei.us/"];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithValue:base];
    SPKTurtleParser* p  = [[SPKTurtleParser alloc] initWithLexer:l base: baseuri];
    //    NSLog(@"parser: %p\n", p);
    if (p) {
        [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            [store addTriple:t error:nil];
        } error:nil];
//        NSLog(@"%lu total triples", count);
    } else {
        NSLog(@"Could not construct parser");
    }
    
    
    GTWIRI* g = [[GTWIRI alloc] initWithValue:@"http://example.org/"];
    SPKTripleModel* model = [[SPKTripleModel alloc] initWithTripleStore:store usingGraphName:g];
    id<GTWTriplesSerializer> s    = [[SPKNTriplesSerializer alloc] init];
//    NSLog(@"model: %@\n--------------\n", model);
    NSEnumerator* e = [model quadsMatchingSubject:nil predicate:nil object:nil graph:nil error:nil];
    NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
    [s serializeTriples:e toHandle:out];
    
    
//    GTWIRI* rdftype = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
//    GTWIRI* greg    = [[GTWIRI alloc] initWithValue:@"http://kasei.us/about/foaf.xrdf#greg"];
////    GTWIRI* type  =[[GTWIRI alloc] initWithValue:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
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

//    librdf_free_world(librdf_world_ptr);
//    NSLog(@"%@", store);
    return 0;
}

int run_redland_parser_example (NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data            = [fh readDataToEndOfFile];

    Class GTWRedlandParser = [SPKSPARQLPluginHandler pluginClassWithName:@"GTWRedlandParser"];
    if (!GTWRedlandParser) {
        NSLog(@"Redland parser plugin not available.");
        return 1;
    }
    id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data base:nil];
//    id<GTWRDFParser> parser = [[SPKRedlandParser alloc] initWithData:data inFormat:@"turtle" base: nil WithRaptorWorld:raptor_world_ptr];
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
    id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
    NSError* error;
    id<SPKTree> algebra    = [parser parseSPARQLQuery:query withBaseURI:base error:&error];
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
    id<GTWSPARQLResultsSerializer> s    = [[SPKSPARQLResultsTextTableSerializer alloc] init];
    
    NSData* data        = [s dataFromResults:e withVariables:variables];
    fwrite([data bytes], [data length], 1, stdout);
    return 0;
}

int parseQuery(NSString* query, NSString* base) {
    NSLog(@"Query string:\n%@\n\n", query);
    
    GTWIRI* graph               = [[GTWIRI alloc] initWithValue: base];
    GTWDataset* dataset         = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
    NSError* error;
    id<SPKTree> algebra         = [parser parseSPARQLQuery:query withBaseURI:base error:&error];
    if (error) {
        NSLog(@"Parse error: %@", error);
        return 1;
    }
    NSLog(@"Query algebra:\n%@\n\n", algebra);
    
    id<GTWQuadStore> store      = [[SPKMemoryQuadStore alloc] init];
    id<GTWModel> model          = [[SPKQuadModel alloc] initWithQuadStore:store];
    SPKQueryPlanner* planner    = [[SPKQueryPlanner alloc] init];
    id<SPKTree,GTWQueryPlan> plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model options:nil];
    NSLog(@"Query plan:\n%@\n\n", plan);
    return 0;
}

int lexQuery(NSString* query, NSString* base) {
    NSLog(@"Query string:\n%@\n\n", query);
    SPKSPARQLLexer* l           = [[SPKSPARQLLexer alloc] initWithString:query];
    
    NSLog(@"Query tokens:\n-----------------------\n");
    SPKSPARQLToken* t;
    NSError* error;
    while ((t = [l getTokenWithError:&error])) {
        NSLog(@"%@\n", t);
    }
    if (error) {
        NSLog(@"Error parsing query: %@", error);
    }
    return 0;
}

int runQuery(NSString* query, NSString* filename, NSString* base, NSUInteger verbose) {
    GTWIRI* graph = [[GTWIRI alloc] initWithValue: base];
    SPKMemoryQuadStore* store   = [[SPKMemoryQuadStore alloc] init];

    {
//        NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
//        NSData* data            = [fh readDataToEndOfFile];
//        id<GTWRDFParser> parser = [[SPKRedlandParser alloc] initWithData:data inFormat:@"guess" base: nil WithRaptorWorld:raptor_world_ptr];
//        id<GTWRDFParser> parser = [[SPKRedlandParser alloc] initWithData:data inFormat:@"guess" base: nil WithRaptorWorld:raptor_world_ptr];
//        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
//            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
//            [store addQuad:q error:nil];
//        } error:nil];
        loadRDFFromFileIntoStore(store, filename, base);
    }
    
    SPKQuadModel* model         = [[SPKQuadModel alloc] initWithQuadStore:store];
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    return runQueryWithModelAndDataset(query, base, model, dataset, verbose);
}

int usage(int argc, const char * argv[]) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "    %s endpoint config-json-string\n", argv[0]);
    fprintf(stderr, "    %s qparse QUERY-FILE\n", argv[0]);
    fprintf(stderr, "    %s dparse DATA-FILE\n", argv[0]);
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
    fprintf(stderr, "    %s parsers\n", argv[0]);
    fprintf(stderr, "\n");
    return 0;
}

id<GTWDataSource> storeFromSourceWithConfigurationString(NSDictionary* datasources, NSDictionary* dict, GTWIRI* defaultGraph, Class* class) {
    NSString* sourceName    = dict[@"storetype"];
    Class c = [datasources objectForKey:sourceName];
    if (!c) {
        NSLog(@"No data source class found with config: %@", dict);
        return nil;
    }

    NSDictionary* pluginClasses = [c classesImplementingProtocols];
    for (Class pluginClass in pluginClasses) {
        NSSet* protocols    = pluginClasses[pluginClass];
        if ([protocols containsObject:@protocol(GTWTripleStore)]) {
            id<GTWDataSource,GTWTripleStore> store = [[pluginClass alloc] initWithDictionary:dict];
            if (!store) {
                NSLog(@"Failed to create triple store from source '%@'", pluginClass);
                return nil;
            }
            *class  = pluginClass;
            return store;
        } else if ([protocols containsObject:@protocol(GTWQuadStore)]) {
            id<GTWDataSource,GTWQuadStore> store = [[pluginClass alloc] initWithDictionary:dict];
            if (!store) {
                NSLog(@"Failed to create triple store from source '%@'", pluginClass);
                return nil;
            }
            *class  = pluginClass;
            return store;
        }
    }
    return nil;
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
    
    if ([sourceName isEqualToString:@"SPKTripleModel"]) {
        NSDictionary* data  = dict[@"graphs"];
        SPKTripleModel* model  = [[SPKTripleModel alloc] init];
        for (NSString* graphName in data) {
            NSDictionary* storeDict = data[graphName];
            GTWIRI* iri = [[GTWIRI alloc] initWithValue:graphName];
            id<GTWDataSource> store = storeFromSourceWithConfigurationString(datasources, storeDict, defaultGraph, class);
            if (!store) {
                NSLog(@"Failed to create triple store from config '%@'", dict);
                return nil;
            }
            [model addStore:(id<GTWTripleStore>)store usingGraphName:iri];
        }
        return model;
    } else {
        NSMutableDictionary* storeDict  = [dict mutableCopy];
        storeDict[@"storetype"]  = sourceName;
        id<GTWDataSource> store = storeFromSourceWithConfigurationString(datasources, storeDict, defaultGraph, class);
        if (!store) {
            NSLog(@"Failed to create triple store from config '%@'", storeDict);
            return nil;
        }
        if ([store conformsToProtocol:@protocol(GTWTripleStore)]) {
            return [[SPKTripleModel alloc] initWithTripleStore:(id<GTWTripleStore>)store usingGraphName:defaultGraph];
        } else {
            return [[SPKQuadModel alloc] initWithQuadStore:(id<GTWQuadStore>)store];
        }
    }
}

int main(int argc, const char * argv[]) {
    srand([[NSDate date] timeIntervalSince1970]);
//	librdf_world_ptr	= librdf_new_world();
//    raptor_world_ptr    = raptor_new_world();
    
    // ------------------------------------------------------------------------------------------------------------------------
    NSMutableDictionary* datasources    = [NSMutableDictionary dictionary];
    NSArray* plugins    = [SPKSPARQLPluginHandler dataSourceClasses];
    NSMutableArray* datasourcelist  = [NSMutableArray arrayWithArray:plugins];
    [datasourcelist addObject:[SPKMemoryQuadStore class]];
    
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
    }
    // ------------------------------------------------------------------------------------------------------------------------
    
    
    if (argc == 1) {
        return usage(argc, argv);
    } else if (argc == 2 && !strcmp(argv[1], "--help")) {
        return usage(argc, argv);
    }
    
    
    
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsXMLParser class]];
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsJSONParser class]];
    [SPKSPARQLPluginHandler registerClass:[SPKTurtleParser class]];
//    NSLog(@"registered classes: %@", [SPKSPARQLPluginHandler registeredClasses]);
    
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
        NSString* config        = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* query         = [NSString stringWithFormat:@"%s", argv[argi++]];

        Class c;
        GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue: kDefaultBase];
        id<GTWModel> model      = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
        if (!model) {
            NSLog(@"Failed to construct model for query");
            return 1;
        }
        GTWDataset* dataset     = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        return runQueryWithModelAndDataset(query, kDefaultBase, model, dataset, verbose);
    } else if ([op isEqual: @"repl"]) {
        Class c;
        GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue: kDefaultBase];
        NSString* config        = [NSString stringWithFormat:@"%s", argv[argi++]];
        id<GTWModel> model      = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
        if (!model) {
            NSLog(@"Failed to construct model for query");
            return 1;
        }
        GTWDataset* dataset     = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        SPKQueryPlanner* planner        = [[SPKQueryPlanner alloc] init];
        
        char *line;
        while ((line = readline("sparql> ")) != NULL) {
            NSError* error      = nil;
            NSString* sparql    = [NSString stringWithFormat:@"%s", line];
//            NSLog(@"SPARQL:\n----------------\n%@\n----------------\n", sparql);
            if (![sparql length])
                continue;
            SPKSPARQLParser* parser = [[SPKSPARQLParser alloc] init];
            id<SPKTree> algebra     = [parser parseSPARQLQuery:sparql withBaseURI:kDefaultBase error:&error];
            if (error) {
                NSLog(@"parser error: %@", error);
                continue;
            }
            if (verbose) {
                NSLog(@"query:\n%@", algebra);
            }
            
            SPKTree<SPKTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model options:nil];
            if (verbose) {
                NSLog(@"plan:\n%@", plan);
            }
            
            if (!plan) {
                continue;
            }
            
            NSSet* variables    = [plan inScopeVariables];
            if (verbose) {
                NSLog(@"executing query...");
            }
            id<GTWQueryEngine> engine   = [[SPKSimpleQueryEngine alloc] init];
            NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
            
            Class resultClass   = [plan planResultClass];
            if ([resultClass isEqual:[NSNumber class]]) {
                NSNumber* result    = [e nextObject];
                if ([result boolValue]) {
                    printf("ok\n");
                } else {
                    printf("not ok\n");
                }
            } else if ([resultClass isEqual:[GTWTriple class]]) {
                id<GTWTriplesSerializer> s    = [[SPKNTriplesSerializer alloc] init];
                NSData* data        = [s dataFromTriples:e];
                fwrite([data bytes], [data length], 1, stdout);
            } else if ([resultClass isEqual:[GTWQuad class]]) {
                id<GTWQuadsSerializer> s    = [[SPKNQuadsSerializer alloc] init];
                NSData* data        = [s dataFromQuads:e];
                fwrite([data bytes], [data length], 1, stdout);
            } else {
                id<GTWSPARQLResultsSerializer> s    = [[SPKSPARQLResultsTextTableSerializer alloc] init];
                NSData* data        = [s dataFromResults:e withVariables:variables];
                fwrite([data bytes], [data length], 1, stdout);
            }
        }
        return 0;
    } else if ([op isEqual: @"endpoint"]) {
        if (argc < (argi+1)) {
            NSLog(@"endpoint operation must be supplied with a data source configuration string.");
            return 1;
        }
        Class c;
        NSString* config        = [NSString stringWithFormat:@"%s", argv[argi++]];
        GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue: kDefaultBase];
        id<GTWModel> model      = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
        if (!model) {
            NSLog(@"Failed to construct model for query");
            return 1;
        }
        GTWDataset* dataset     = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        // Configure our logging framework.
        // To keep things simple and fast, we're just going to log to the Xcode console.
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        // Initalize our http server
        GTWSPARQLServer* httpServer = [[GTWSPARQLServer alloc] initWithModel:model dataset:dataset base:kDefaultBase];
        
        // Tell server to use our custom MyHTTPConnection class.
        [httpServer setConnectionClass:[GTWSPARQLConnection class]];
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [httpServer setType:@"_http._tcp."];
        
        // Normally there's no need to run our server on any specific port.
        // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
        // However, for easy testing you may want force a certain port so you can just hit the refresh button.
        [httpServer setPort:12345];
        
        // Serve files from our embedded Web folder
//        NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
        NSString *webPath = @"/Users/greg/Sites/kasei.us/";
        NSLog(@"Setting document root: %@", webPath);
        
        [httpServer setDocumentRoot:webPath];
        
        // Start the server (and check for problems)
        
        NSError *error;
        BOOL success = [httpServer start:&error];
        
        if(!success)
        {
            NSLog(@"Error starting HTTP Server: %@", error);
        }
        
        while (YES) {
            sleep(1);
        }
    } else if ([op isEqual: @"dparse"]) {
        NSString* filename      = [NSString stringWithFormat:@"%s", argv[argi++]];
        NSString* base          = (argc > argi) ? [NSString stringWithFormat:@"%s", argv[argi++]] : kDefaultBase;
        NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
        SPKSPARQLLexer* l       = [[SPKSPARQLLexer alloc] initWithFileHandle:fh];
//        GTWIRI* graph         = [[GTWIRI alloc] initWithValue:base];
        GTWIRI* baseuri         = [[GTWIRI alloc] initWithValue:base];
        SPKTurtleParser* p      = [[SPKTurtleParser alloc] initWithLexer:l base: baseuri];
        NSError* error;
        if (p) {
            [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
//                GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
                fprintf(stdout, "%s\n", [[t description] UTF8String]);
            } error:&error];
            if (error) {
                NSLog(@"Error parsing RDF: %@", error);
            }
        } else {
            NSLog(@"Could not construct parser");
        }
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
        NSString* config;
        if (argc > argi) {
            config    = [NSString stringWithFormat:@"%s", argv[argi++]];
        } else {
            config      = @"{}";
        }
        
        Class c;
        GTWIRI* defaultGraph   = [[GTWIRI alloc] initWithValue: kDefaultBase];
        id<GTWModel> model  = modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
        if (!model) {
            NSLog(@"Failed to construct model for query");
            return 1;
        }
        
        GTWVariable* s  = [[GTWVariable alloc] initWithValue:@"s"];
        GTWVariable* p  = [[GTWVariable alloc] initWithValue:@"p"];
        GTWVariable* o  = [[GTWVariable alloc] initWithValue:@"o"];
        GTWVariable* g  = [[GTWVariable alloc] initWithValue:@"g"];
        NSError* error  = nil;
        
        NSDictionary* pluginClasses = [c classesImplementingProtocols];
        for (Class pluginClass in pluginClasses) {
            NSSet* protocols    = pluginClasses[pluginClass];
            if ([protocols containsObject:@protocol(GTWTripleStore)]) {
                NSEnumerator* e = [model quadsMatchingSubject:s predicate:p object:o graph:defaultGraph error:&error];
                if (error) {
                    NSLog(@"*** %@", error);
                    return 1;
                }
                id<GTWTriplesSerializer> ser    = [[SPKNTriplesSerializer alloc] init];
                NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
                [ser serializeTriples:e toHandle:out];
                return 0;
            } else if ([protocols containsObject:@protocol(GTWQuadStore)]) {
                NSEnumerator* e = [model quadsMatchingSubject:s predicate:p object:o graph:g error:&error];
                if (error) {
                    NSLog(@"*** %@", error);
                    return 1;
                }
                id<GTWQuadsSerializer> ser    = [[SPKNQuadsSerializer alloc] init];
                NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
                [ser serializeQuads:e toHandle:out];
                return 0;
            }
        }
        
        NSLog(@"No triple/quad store found in plugin %@.", c);
        return -1;
    } else if ([op isEqual: @"parsers"]) {
        fprintf(stdout, "Available RDF parsers:\n");
        NSArray* parsers    = [SPKSPARQLPluginHandler parserClasses];
        for (Class c in parsers) {
            fprintf(stdout, "%s\n", [[c description] UTF8String]);
            NSDictionary* pluginClasses = [c classesImplementingProtocols];
            for (Class pluginClass in pluginClasses) {
                NSSet* protocols    = pluginClasses[pluginClass];
                if ([protocols count]) {
                    NSMutableArray* array   = [NSMutableArray array];
                    for (Protocol* p in protocols) {
                        const char* name = protocol_getName(p);
                        [array addObject:[NSString stringWithFormat:@"%s", name]];
                    }
                    NSString* str   = [array componentsJoinedByString:@", "];
                    fprintf(stdout, "  Protocols: %s\n", [str UTF8String]);
                }
            }
        }
    } else if ([op isEqual: @"sources"]) {
        fprintf(stdout, "Available data sources:\n");
        for (id s in datasources) {
            Class c = datasources[s];
            fprintf(stdout, "%s\n", [[c description] UTF8String]);
            NSDictionary* pluginClasses = [c classesImplementingProtocols];
            for (Class pluginClass in pluginClasses) {
                NSSet* protocols    = pluginClasses[pluginClass];
                if ([protocols count]) {
                    NSMutableArray* array   = [NSMutableArray array];
                    for (Protocol* p in protocols) {
                        const char* name = protocol_getName(p);
                        [array addObject:[NSString stringWithFormat:@"%s", name]];
                    }
                    NSString* str   = [array componentsJoinedByString:@", "];
                    fprintf(stdout, "  Protocols: %s\n", [str UTF8String]);
                }
                NSString* usage = [pluginClass usage];
                if (usage) {
                    fprintf(stdout, "  Configuration template: %s\n\n", [usage UTF8String]);
                }
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
        if (NO) {
        } else if ([testtype isEqual: @"endpoint"]) {
            NSDictionary* dict              = @{@"endpoint": @"http://myrdf.us/sparql11"};
            id<GTWTripleStore> store        = [[[datasources objectForKey:@"GTWSPARQLProtocolStore"] alloc] initWithDictionary:dict];
            GTWIRI* graph = [[GTWIRI alloc] initWithValue: kDefaultBase];
            SPKTripleModel* model           = [[SPKTripleModel alloc] initWithTripleStore:store usingGraphName:graph];
            GTWVariable* s  = [[GTWVariable alloc] initWithValue:@"s"];
            GTWVariable* o  = [[GTWVariable alloc] initWithValue:@"o"];
            GTWIRI* rdftype = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            NSError* error  = nil;
            NSEnumerator* e = [model quadsMatchingSubject:s predicate:rdftype object:o graph:graph error:&error];
            id<GTWTriplesSerializer> ser    = [[SPKNTriplesSerializer alloc] init];
            NSFileHandle* out    = [[NSFileHandle alloc] initWithFileDescriptor: fileno(stdout)];
            [ser serializeTriples:e toHandle:out];
        } else if ([testtype isEqual: @"parser"]) {
            run_redland_parser_example(filename, base);
        } else if ([testtype isEqual: @"triple"]) {
            run_redland_triple_store_example(filename, base);
        } else {
            run_memory_quad_store_example(filename, base);
        }
    } else if ([op isEqual: @"testsuite"]) {
        NSMutableArray* manifests   = [NSMutableArray array];
        while (argc > (argi+1) && !strcmp(argv[argi], "-m")) {
            ++argi;
            NSString* manifest    = [NSString stringWithFormat:@"%s", argv[argi++]];
            [manifests addObject:manifest];
        }
        NSString* pattern   = (argc > argi) ? [NSString stringWithFormat:@"%s", argv[argi++]] : nil;
        
        if ([manifests count] == 0) {
            // Defaults
            [manifests addObject:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg11/manifest-all.ttl"];
            [manifests addObject:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg/data-r2/manifest-syntax.ttl"];
            [manifests addObject:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg/data-r2/manifest-evaluation.ttl"];
            if (!pattern)
                pattern = @"#(?!construct-)";
        }
        
        while (YES) {
            GTWSPARQLTestHarness* harness   = [[GTWSPARQLTestHarness alloc] initWithConcurrency:(concurrent ? YES : NO)];
            harness.verbose         = verbose;
            harness.runEvalTests    = YES;
            harness.runSyntaxTests  = YES;
            if (pattern) {
                [harness runTestsMatchingPattern:pattern fromManifests:manifests];
            } else {
                [harness runTestsFromManifests:manifests];
            }
            [harness printSummary];
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
        SPKMemoryQuadStore* storea   = [[SPKMemoryQuadStore alloc] init];
        SPKMemoryQuadStore* storeb   = [[SPKMemoryQuadStore alloc] init];
        loadRDFFromFileIntoStore(storea, filenamea, base);
        loadRDFFromFileIntoStore(storeb, filenameb, base);
        SPKQuadModel* modela         = [[SPKQuadModel alloc] initWithQuadStore:storea];
        SPKQuadModel* modelb         = [[SPKQuadModel alloc] initWithQuadStore:storeb];
        [modela isEqual:modelb];
    }
}
