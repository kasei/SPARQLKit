#import <objc/runtime.h>

#import <SPARQLKit/SPARQLKit.h>
#import <GTWSWBase/GTWQuad.h>
#import <SPARQLKit/SPKMemoryQuadStore.h>
#import <SPARQLKit/SPKTurtleParser.h>
#import <SPARQLKit/SPKQuadModel.h>
#import <SPARQLKit/SPKTripleModel.h>
#import <SPARQLKit/SPKSPARQLPluginHandler.h>
#import <SPARQLKit/SPKTree.h>
#import <SPARQLKit/SPKQuery.h>

// Shared user-agent to load prefixes from prefix.cc
#import <SPARQLKit/SPKMutableURLRequest.h>

// Parsers
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>
#import <GTWSWBase/GTWSPARQLResultsJSONParser.h>

// Serializers
#import <SPARQLKit/SPKSPARQLResultsCSVSerializer.h>
#import <SPARQLKit/SPKSPARQLResultsTSVSerializer.h>
#import <SPARQLKit/SPKSPARQLResultsXMLSerializer.h>
#import <SPARQLKit/SPKSPARQLResultsTextTableSerializer.h>
#import <SPARQLKit/SPKNQuadsSerializer.h>
#import "SPKNTriplesSerializer.h"
#import "SPKPrefixNameSerializerDelegate.h"

#include <sys/stat.h>

// SPARQL Endpoint
#import "GTWSPARQLConnection.h"
#import "GTWSPARQLServer.h"
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

#import "linenoise.h"

static NSString* PRODUCT_NAME   = @"gtwsparql";
static NSString* kDefaultBase   = @"http://base.example.com/";

NSString* fileContents (NSString* filename) {
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data        = [fh readDataToEndOfFile];
    NSString* string    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

int usage(int argc, const char * argv[]) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "    %s [-s config-json-string] [SPARQL-STRING]\n", argv[0]);
    fprintf(stderr, "    %s --help\n", argv[0]);
    fprintf(stderr, "    %s --version\n", argv[0]);
    fprintf(stderr, "\n");
    fprintf(stderr, "Example:\n");
    fprintf(stderr, "    %s [-s config-json-string] ''\n", argv[0]);
    return 0;
}

int version(int argc, const char * argv[]) {
    NSString* s = [NSString stringWithFormat:@"%@ %@ v%@", PRODUCT_NAME, SPARQLKIT_NAME, SPARQLKIT_VERSION];
    fprintf(stderr, "%s\n\n", [s UTF8String]);
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

GTWSPARQLServer* startEndpoint (id<GTWModel,GTWMutableModel> model, id<GTWDataset> dataset, UInt16 port) {
    // Initalize our http server
    GTWSPARQLServer* httpServer = [[GTWSPARQLServer alloc] initWithModel:model dataset:dataset base:kDefaultBase];
    
    // Tell server to use our custom MyHTTPConnection class.
    [httpServer setConnectionClass:[GTWSPARQLConnection class]];
    
    // Tell the server to broadcast its presence via Bonjour.
    // This allows browsers such as Safari to automatically discover our service.
    [httpServer setType:@"_sparql._tcp."];
    [httpServer setTXTRecordDictionary:@{ @"path": @"/sparql" }];
    
    // Normally there's no need to run our server on any specific port.
    // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
    // However, for easy testing you may want force a certain port so you can just hit the refresh button.
    if (port) {
        [httpServer setPort:port];
    }
    
    // Serve files from our embedded Web folder
    //        NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    NSString *webPath = @"/Users/greg/Sites/kasei.us/";
    //    NSLog(@"Setting document root: %@", webPath);
    
    [httpServer setDocumentRoot:webPath];
    
    // Start the server (and check for problems)
    
    NSError *error;
    BOOL success = [httpServer start:&error];
    
    if(!success) {
        NSLog(@"Error starting HTTP Server: %@", error);
        return nil;
    }
    return httpServer;
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
//                NSLog(@"Failed to create triple store from config '%@'", dict);
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
//            NSLog(@"Failed to create triple store from config '%@'", storeDict);
            return nil;
        }
        if ([store conformsToProtocol:@protocol(GTWTripleStore)]) {
            return [[SPKTripleModel alloc] initWithTripleStore:(id<GTWTripleStore>)store usingGraphName:defaultGraph];
        } else {
            return [[SPKQuadModel alloc] initWithQuadStore:(id<GTWQuadStore>)store];
        }
    }
}

NSString* cacheDirectory (void) {
    NSString* cachePath     = [NSString stringWithFormat:@"Caches/us.kasei.%@", PRODUCT_NAME];
    NSArray* searchPaths    = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
    //    NSLog(@"search paths: %@", searchPaths);
    NSString* cacheFullPath;
    if ([searchPaths count]) {
        for (NSString* curPath in searchPaths) {
            NSString* path  = [curPath stringByAppendingPathComponent:cachePath];
            //            NSLog(@"checking: %@", path);
            if ([[NSFileManager defaultManager] fileExistsAtPath: path]) {
                //                NSLog(@"-> ok");
                cacheFullPath   = path;
                break;
            }
        }
        if (!cacheFullPath) {
            NSString* curPath   = [searchPaths objectAtIndex:0];
            NSString* path  = [curPath stringByAppendingPathComponent:cachePath];
            //            NSLog(@"-> creating %@", path);
            if (!mkdir([path UTF8String], S_IRUSR|S_IXUSR|S_IWUSR|S_IRGRP|S_IXGRP)) {
                cacheFullPath   = path;
            } else {
                perror("Failed to create cache directory: ");
            }
        }
    }
    return cacheFullPath;
}

NSDictionary* loadCachedPrefixes (void) {
    NSString* fileName      = @"Prefixes.json";
    NSString* cacheFullPath = cacheDirectory();
    if (cacheFullPath) {
        NSError* error;
        NSString* cacheFile = [cacheFullPath stringByAppendingPathComponent:fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath: cacheFile]) {
            NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:cacheFile];
            NSData* data        = [fh readDataToEndOfFile];
            return [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        }
    }
    
    return nil;
}

BOOL storeCachedPrefixes (NSDictionary* prefixes) {
    NSString* fileName      = @"Prefixes.json";
    NSString* cacheFullPath = cacheDirectory();
    if (cacheFullPath) {
        NSError* error;
        NSString* cacheFile = [cacheFullPath stringByAppendingPathComponent:fileName];
        //        NSLog(@"writing prefixes data to cache file %@", cacheFile);
        int fd              = open([cacheFile UTF8String], O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP);
        if (fd == -1) {
            perror("Failed to open prefix cache file for writing: ");
            return NO;
        }
        //        NSFileHandle* fh    = [NSFileHandle fileHandleForWritingAtPath:cacheFile];
        NSFileHandle* fh    = [[NSFileHandle alloc] initWithFileDescriptor:fd];
        if (fh) {
            NSData* data        = [NSJSONSerialization dataWithJSONObject:prefixes options:NSJSONWritingPrettyPrinted error:&error];
            if (error) {
                NSLog(@"Error writing prefixes cache file: %@", error);
                return NO;
            }
            [fh writeData:data];
            return YES;
        }
    }
    
    return NO;
}

NSDictionary* prefixes (void) {
    static NSDictionary* prefixes;
	static dispatch_once_t onceToken;
    prefixes    = loadCachedPrefixes();
    if (prefixes)
        return prefixes;
	dispatch_once(&onceToken, ^{
        NSError* error;
        NSURL* url  = [NSURL URLWithString:@"http://prefix.cc/popular/all.file.json"];
        SPKMutableURLRequest* req   = [SPKMutableURLRequest requestWithURL:url];
        [req setValue:@"text/json" forHTTPHeaderField:@"Accept"];
        NSHTTPURLResponse* resp	= nil;
        //        NSLog(@"sending request for prefixes");
        NSData* data	= [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&error];
        if (resp) {
            NSInteger code	= [resp statusCode];
            if (code >= 200 && code < 300) {
                prefixes = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            }
        }
    });
    if (prefixes)
        storeCachedPrefixes(prefixes);
    return prefixes;
}

void completion(const char *buf, linenoiseCompletions *lc) {
    NSError* error;
    NSString* s = [NSString stringWithFormat:@"%s", buf];
    NSRegularExpression* regex  = [NSRegularExpression regularExpressionWithPattern:@"PREFIX (\\w+):$" options:0 error:&error];
    NSRange rangeOfFirstMatch   = [regex rangeOfFirstMatchInString:s options:0 range:NSMakeRange(0, [s length])];
    if (rangeOfFirstMatch.location != NSNotFound) {
        NSDictionary* p = prefixes();
        if (p) {
            NSString* substr    = [s substringWithRange:rangeOfFirstMatch];
            NSString* substr2   = [substr substringFromIndex:7];
            NSString* ns        = [substr2 substringToIndex:[substr2 length]-1];
            if (p[ns]) {
                NSString* c = [NSString stringWithFormat:@"%@ <%@> ", s, p[ns]];
                linenoiseAddCompletion(lc,(char*)[c UTF8String]);
            }
        }
    }
    
    static NSArray* keywords;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSMutableArray* kw  = [SPKSPARQLKeywords() mutableCopy];
        [kw addObject:@"endpoint"];
        [kw addObject:@"kill"];
        [kw addObject:@"jobs"];
        keywords    = [kw copy];
    });
    NSRegularExpression* kwregex    = [NSRegularExpression regularExpressionWithPattern:@"(\\w+)$" options:0 error:&error];
    NSRange rangeOfKW               = [kwregex rangeOfFirstMatchInString:s options:0 range:NSMakeRange(0, [s length])];
    if (rangeOfKW.location != NSNotFound) {
        NSString* kwPrefix    = [[s substringWithRange:rangeOfKW] uppercaseString];
        for (NSString* kw in keywords) {
            NSString* uckw    = [kw uppercaseString];
            if ([uckw hasPrefix:kwPrefix]) {
                NSString* prefix    = [s substringToIndex:rangeOfKW.location];
                linenoiseAddCompletion(lc,(char*)[[NSString stringWithFormat:@"%@%@", prefix, kw] UTF8String]);
            }
        }
    }
}

BOOL print_sources ( NSDictionary* datasources ) {
    NSUInteger counter  = 1;
    for (id s in datasources) {
        Class c = datasources[s];
        fprintf(stdout, "[%lu] %s\n", counter++, [[c description] UTF8String]);
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
                fprintf(stdout, "    Protocols: %s\n", [str UTF8String]);
            }
            NSString* usage = [pluginClass usage];
            if (usage) {
                fprintf(stdout, "    Configuration template: %s\n\n", [usage UTF8String]);
            }
        }
    }
    return YES;
}

BOOL run_command ( NSString* cmd, NSDictionary* datasources, id<GTWModel,GTWMutableModel> model, id<GTWDataset> dataset, NSMutableArray* jobs, dispatch_queue_t queue, NSString* format, NSUInteger verbose, BOOL quiet, BOOL wait ) {
    @autoreleasepool {
        NSString* sparql    = cmd;
        if ([sparql hasPrefix:@"endpoint"]) {
            UInt16 port = 8080;
            NSRange range   = [sparql rangeOfString:@"^endpoint (\\d+)$" options:NSRegularExpressionSearch];
            if (range.location != NSNotFound) {
                const char* s   = [sparql UTF8String];
                port    = atoi(s+9);
            }
            GTWSPARQLServer* httpServer = startEndpoint(model, dataset, port);
            if (httpServer) {
                if (!quiet)
                    printf("Endpoint started on port %d\n", port);
                jobs[[jobs count]]  = @[ httpServer, @(port) ];
                __weak GTWSPARQLServer* server  = httpServer;
                
                void (*dispatch)(dispatch_queue_t, void(^)())   = wait ? dispatch_sync : dispatch_async;
                dispatch(queue, ^{
                    while (server) {
                        sleep(1);
                    }
                });
            }
            return YES;
        } else if ([sparql hasPrefix:@"sources"]) {
            return print_sources(datasources);
        } else if ([sparql hasPrefix:@"jobs"]) {
            NSUInteger i   = 0;
            for (i = 0; i < [jobs count]; i++) {
                NSArray* pair   = jobs[i];
                if (![pair isKindOfClass:[NSNull class]]) {
                    NSNumber* port  = pair[1];
                    printf("[%lu] Endpoint on port %d\n", i+1, [port intValue]);
                }
            }
            return YES;
        } else if ([sparql rangeOfString:@"^kill (\\d+)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            const char* s   = [sparql UTF8String];
            NSUInteger job  = atoi(s+5);
            if (job > [jobs count]) {
                if (!quiet)
                    printf("No such job %lu (%lu).\n", job, [jobs count]);
                return YES;
            }
            NSArray* pair   = jobs[job-1];
            if (pair && ![pair isKindOfClass:[NSNull class]]) {
                GTWSPARQLServer* httpServer = pair[0];
                //                    NSLog(@"stopping server %@", httpServer);
                [httpServer stop];
                jobs[job-1]     = [NSNull null];
                if (!quiet)
                    printf("OK\n");
            }
            return YES;
        } else if ([sparql isEqualToString:@"exit"]) {
            return NO;
        } else if ([sparql hasPrefix:@"parse "]) {
            NSString* s = [sparql substringFromIndex:6];
            NSError* error;
            SPKQuery* query = [[SPKQuery alloc] initWithQueryString:s baseURI:kDefaultBase];
            query.verbose   = verbose;
            
            id<SPKTree> algebra = [query parseWithError:&error];
            if (error || !algebra) {
                NSLog(@"parser error: %@", error);
                return YES;
            }
            
            printf("Query Algebra:\n%s\n", [[algebra longDescription] UTF8String]);
            NSDictionary* prefixes  = query.prefixes;
            for (id ns in prefixes) {
                NSLog(@"%@ -> %@", ns, prefixes[ns]);
            }
            return YES;
        } else if ([sparql hasPrefix:@"explain "]) {
            NSString* s = [sparql substringFromIndex:8];
            NSError* error;
            SPKQuery* query = [[SPKQuery alloc] initWithQueryString:s baseURI:kDefaultBase];
            query.verbose   = verbose;
            
            SPKTree<SPKTree,GTWQueryPlan>* plan   = (SPKTree<SPKTree,GTWQueryPlan>*) [query planWithModel:model error:&error];
            if (!plan)
                return YES;
            
            printf("Query Plan:\n%s\n", [[plan longDescription] UTF8String]);
            return YES;
        } else if ([sparql isEqualToString:@"help"]) {
            printf("Commands:\n");
            printf("    endpoint [PORT]        Start  SPARQL endpoint on PORT (defaults to 8080).\n");
            printf("    jobs                   Show the running endpoints.\n");
            printf("    kill N                 Kill a running endpoint by number (from `jobs`).\n");
            printf("    help                   Show this help information.\n");
            printf("    parse [SPARQL]         Print the parsed algebra for the SPARQL 1.1 query/update.\n");
            printf("    explain [SPARQL]       Explain the execution plan for the SPARQL 1.1 query/update.\n");
            printf("    SELECT ...             Execute the SPARQL 1.1 query.\n");
            printf("    ASK ...                Execute the SPARQL 1.1 query.\n");
            printf("    CONSTRUCT ...          Execute the SPARQL 1.1 query.\n");
            printf("    DESCRIBE ...           Execute the SPARQL 1.1 query.\n");
            printf("    INSERT ...             Execute the SPARQL 1.1 update.\n");
            printf("    DELETE ...             Execute the SPARQL 1.1 update.\n");
            printf("    LOAD <uri>             Execute the SPARQL 1.1 update.\n");
            printf("    CLEAR ...              Execute the SPARQL 1.1 update.\n");
            printf("    COPY ...               Execute the SPARQL 1.1 update.\n");
            printf("    MOVE ...               Execute the SPARQL 1.1 update.\n");
            printf("\n");
            return YES;
        }
        
        NSError* error;
        SPKQuery* query = [[SPKQuery alloc] initWithQueryString:sparql baseURI:kDefaultBase];
        query.verbose   = verbose;
        NSEnumerator* e = [query executeWithModel:model error:&error];
        NSSet* variables= query.variables;
        
        Class resultClass   = query.resultClass;
        if ([resultClass isEqual:[NSNumber class]]) {
            NSNumber* result    = [e nextObject];
            if (!quiet) {
                if ([result boolValue]) {
                    printf("OK\n");
                } else {
                    printf("Not OK\n");
                }
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
            id<GTWSPARQLResultsSerializer> s;
            if ([format isEqualToString:@"csv"]) {
                s   = [[SPKSPARQLResultsCSVSerializer alloc] init];
            } else if ([format isEqualToString:@"tsv"]) {
                s   = [[SPKSPARQLResultsTSVSerializer alloc] init];
            } else {
//                NSLog(@"Serializing with prefixes: %@", query.prefixes);
                SPKPrefixNameSerializerDelegate* d  = [[SPKPrefixNameSerializerDelegate alloc] initWithNamespaceDictionary:query.prefixes];
                SPKSPARQLResultsTextTableSerializer* ser   = [[SPKSPARQLResultsTextTableSerializer alloc] init];
                ser.delegate    = d;
                s   = ser;
            }
            NSData* data        = [s dataFromResults:e withVariables:variables];
            fwrite([data bytes], [data length], 1, stdout);
        }
        return YES;
    }
}

int main(int argc, const char * argv[]) {
    //    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    srand([[NSDate date] timeIntervalSince1970]);
    
    // ------------------------------------------------------------------------------------------------------------------------
    NSMutableDictionary* datasources    = [NSMutableDictionary dictionary];
    NSArray* plugins    = [SPKSPARQLPluginHandler dataSourceClasses];
    NSMutableArray* datasourcelist  = [NSMutableArray arrayWithArray:plugins];
    [datasourcelist addObject:[SPKMemoryQuadStore class]];
    
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
    }
    // ------------------------------------------------------------------------------------------------------------------------
    
    if (argc == 2) {
        if (!strcmp(argv[1], "--help")) {
            return usage(argc, argv);
        } else if (!strcmp(argv[1], "--version") || !strcmp(argv[1], "-v")) {
            return version(argc, argv);
        }
    }
    
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsXMLParser class]];
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsJSONParser class]];
    [SPKSPARQLPluginHandler registerClass:[SPKTurtleParser class]];
    [SPKSPARQLPluginHandler registerClass:[SPKNQuadsSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKNTriplesSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKSPARQLResultsCSVSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKSPARQLResultsTSVSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKSPARQLResultsTextTableSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKSPARQLResultsXMLSerializer class]];
    [SPKSPARQLPluginHandler registerClass:[SPKNQuadsSerializer class]];
    
    BOOL wait           = NO;
    BOOL quiet          = NO;
    NSUInteger verbose  = 0;
    NSUInteger argi     = 1;
    NSString* config    = nil;
    NSString* output    = nil;
    BOOL readline       = YES;
    NSMutableArray* ops = [NSMutableArray array];
    
    while (argc > argi && argv[argi][0] == '-') {
        if (!strcmp(argv[argi], "-s")) {
            argi++;
            config  = [NSString stringWithFormat:@"%s", argv[argi++]];
            if (verbose) {
                NSLog(@"Setting up a quadstore based on the configuration string: %@", config);
            }
        } else if (!strcmp(argv[argi], "--results")) {
            argi++;
            output  = [NSString stringWithFormat:@"%s", argv[argi++]];
        } else if (!strcmp(argv[argi], "--query")) {
            argi++;
            NSString* qfile = [NSString stringWithFormat:@"%s", argv[argi++]];
            NSString* sparql    = fileContents(qfile);
            [ops addObject:sparql];
        } else if (!strcmp(argv[argi], "-v")) {
            verbose     = 1;
            argi++;
        } else if (!strcmp(argv[argi], "-w")) {
            wait    = YES;
            argi++;
        } else if (!strcmp(argv[argi], "-r")) {
            readline    = NO;
            argi++;
        } else if (!strcmp(argv[argi], "-q")) {
            quiet   = YES;
            argi++;
        } else {
            break;
        }
    }
    
    if (quiet) {
        verbose = 0;
    }
    
    Class c;
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue: kDefaultBase];
    if (!config) {
        config        = @"SPKMemoryQuadStore";
        if (verbose) {
            NSLog(@"Setting up an empty in-memory quadstore");
        }
    }
    id<GTWModel,GTWMutableModel> model      = (id<GTWModel,GTWMutableModel>) modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
    if (!model) {
        NSLog(@"Failed to construct model for query");
        return 1;
    }
    NSMutableArray* jobs    = [NSMutableArray array];
    GTWDataset* dataset     = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
    dispatch_queue_t queue = dispatch_queue_create("us.kasei.sparql.repl", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        prefixes();
    });
    
    if ([ops count] == 0 && argc > argi) {
        quiet   = YES;
        NSUInteger i;
        for (i = argi; i < argc; i++) {
            NSString* sparql    = [NSString stringWithFormat:@"%s", argv[i]];
            [ops addObject:sparql];
        }
    }
    
    if ([ops count]) {
        for (NSString* sparql in ops) {
            BOOL wait   = YES;
            BOOL ok = run_command(sparql, datasources, model, dataset, jobs, queue, output, verbose, quiet, wait);
            if (!ok) {
                return 1;
            }
        }
        return 0;
    }
    const char *line;
    NSString* historyPath       = [NSString stringWithFormat:@"Application Support/us.kasei.%@", PRODUCT_NAME];
    NSString* lnHistoryFileName = @"history.linenoise";
    NSArray* prefsPaths         = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
    NSString* prefsPath;
    if ([prefsPaths count]) {
        for (NSString* curPath in prefsPaths) {
            NSString* path  = [curPath stringByAppendingPathComponent:historyPath];
            if ([[NSFileManager defaultManager] fileExistsAtPath: path]) {
                prefsPath   = path;
                break;
            }
        }
        if (!prefsPath) {
            NSString* curPath   = [prefsPaths objectAtIndex:0];
            if (!mkdir([curPath UTF8String], S_IRUSR|S_IXUSR|S_IWUSR|S_IRGRP|S_IXGRP)) {
                NSString* path  = [curPath stringByAppendingPathComponent:historyPath];
                prefsPath   = path;
            }
        }
    }
    
    const char* (^rl)(const char* prompt) = ^const char*(const char* prompt) {
        if (readline) {
            return linenoise(prompt);
        } else {
            fprintf(stdout, "%s", prompt);
            fflush(stdout);
            NSMutableString* input  = [NSMutableString string];
            char c  = fgetc(stdin);
            while (c != EOF && c != '\n') {
                [input appendFormat:@"%c", c];
                c  = fgetc(stdin);
            }
            if (c == EOF)
                return NULL;
            return [input UTF8String];
        }
    };
    
    NSString* lnHistoryFile;
    if (readline) {
        if (prefsPath) {
            lnHistoryFile = [prefsPath stringByAppendingPathComponent:lnHistoryFileName];
            linenoiseHistoryLoad((char*) [lnHistoryFile UTF8String]);
        }
        linenoiseSetCompletionCallback(completion);
    }
    
    while ((line = rl("sparql> ")) != NULL) {
        NSString* sparql    = [NSString stringWithFormat:@"%s", line];
        if (readline)
            free((void*)line);
        if (![sparql length])
            continue;
        if (readline) {
            linenoiseHistoryAdd([sparql UTF8String]);
            if (lnHistoryFile) {
                linenoiseHistorySave((char*) [lnHistoryFile UTF8String]);
            }
        }
        
        BOOL wait   = NO;
        BOOL ok = run_command(sparql, datasources, model, dataset, jobs, queue, output, verbose, quiet, wait);
        if (!ok) {
            goto REPL_EXIT;
        }
    }
    printf("\n");
REPL_EXIT:
    while (wait) sleep(1);
    return 0;
}
