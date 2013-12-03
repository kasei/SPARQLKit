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

static NSString* OSVersionNumber ( void ) {
    static NSString* productVersion    = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSDictionary *version = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
        productVersion = version[@"ProductVersion"];
    });
    return productVersion;
}

NSString* fileContents (NSString* filename) {
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data        = [fh readDataToEndOfFile];
    NSString* string    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

int usage(int argc, const char * argv[]) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "    %s config-json-string\n", argv[0]);
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
        NSMutableURLRequest* req	= [NSMutableURLRequest requestWithURL:url];
        [req setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
        NSString* user_agent	= [NSString stringWithFormat:@"%@/%@ Darwin/%@", SPARQLKIT_NAME, SPARQLKIT_VERSION, OSVersionNumber()];
        [req setValue:user_agent forHTTPHeaderField:@"User-Agent"];
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
    
    if (argc == 2 && !strcmp(argv[1], "--help")) {
        return usage(argc, argv);
    }
    
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsXMLParser class]];
    [SPKSPARQLPluginHandler registerClass:[GTWSPARQLResultsJSONParser class]];
    [SPKSPARQLPluginHandler registerClass:[SPKTurtleParser class]];
    
    NSUInteger verbose  = 0;
    NSUInteger argi     = 1;
    
    while (argc > argi && argv[argi][0] == '-') {
        if (!strcmp(argv[argi], "-v")) {
            verbose     = 1;
            argi++;
        } else {
            break;
        }
    }
    
    Class c;
    GTWIRI* defaultGraph    = [[GTWIRI alloc] initWithValue: kDefaultBase];
    NSString* config;
    if (argc == argi) {
        config        = @"SPKMemoryQuadStore";
    } else {
        config        = [NSString stringWithFormat:@"%s", argv[argi++]];
    }
    id<GTWModel,GTWMutableModel> model      = (id<GTWModel,GTWMutableModel>) modelFromSourceWithConfigurationString(datasources, config, defaultGraph, &c);
    if (!model) {
        NSLog(@"Failed to construct model for query");
        return 1;
    }
    GTWDataset* dataset     = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
    SPKQueryPlanner* planner        = [[SPKQueryPlanner alloc] init];
    
    char *line;
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
    
    NSString* lnHistoryFile;
    if (prefsPath) {
        lnHistoryFile = [prefsPath stringByAppendingPathComponent:lnHistoryFileName];
        linenoiseHistoryLoad((char*) [lnHistoryFile UTF8String]);
    }
    
    dispatch_queue_t queue = dispatch_queue_create("us.kasei.sparql.repl", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        prefixes();
    });
    
    linenoiseSetCompletionCallback(completion);
    NSMutableArray* jobs            = [NSMutableArray array];
    
    while ((line = linenoise("sparql> ")) != NULL) {
        NSError* error      = nil;
        NSString* sparql    = [NSString stringWithFormat:@"%s", line];
        free(line);
        if (![sparql length])
            continue;
        
        linenoiseHistoryAdd([sparql UTF8String]);
        if (lnHistoryFile) {
            linenoiseHistorySave((char*) [lnHistoryFile UTF8String]);
        }
        
        if ([sparql hasPrefix:@"endpoint"]) {
            UInt16 port = 12345;
            NSRange range   = [sparql rangeOfString:@"^endpoint (\\d+)$" options:NSRegularExpressionSearch];
            if (range.location != NSNotFound) {
                const char* s   = [sparql UTF8String];
                port    = atoi(s+9);
            }
            GTWSPARQLServer* httpServer = startEndpoint(model, dataset, port);
            if (httpServer) {
                jobs[[jobs count]]  = @[ httpServer, @(port) ];
                __weak GTWSPARQLServer* server  = httpServer;
                dispatch_async(queue, ^{
                    while (server) {
                        sleep(1);
                    }
                });
            }
            continue;
        } else if ([sparql hasPrefix:@"jobs"]) {
            NSUInteger i   = 0;
            for (i = 0; i < [jobs count]; i++) {
                NSArray* pair   = jobs[i];
                if (![pair isKindOfClass:[NSNull class]]) {
                    NSNumber* port  = pair[1];
                    printf("[%lu] Endpoint on port %d\n", i+1, [port intValue]);
                }
            }
            continue;
        } else if ([sparql rangeOfString:@"^kill (\\d+)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            const char* s   = [sparql UTF8String];
            NSUInteger job  = atoi(s+5);
            if (job >= [jobs count]) {
                printf("No such job.\n");
                continue;
            }
            NSArray* pair   = jobs[job-1];
            if (pair && ![pair isKindOfClass:[NSNull class]]) {
                GTWSPARQLServer* httpServer = pair[0];
                //                    NSLog(@"stopping server %@", httpServer);
                [httpServer stop];
                jobs[job-1]     = [NSNull null];
                printf("OK\n");
            }
            continue;
        } else if ([sparql isEqualToString:@"exit"]) {
            goto REPL_EXIT;
        }
        
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
        } else if ([plan.type isEqual:kPlanSequence] && [plan.arguments count] == 0) {
            // Empty update sequence
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
                printf("OK\n");
            } else {
                printf("Not OK\n");
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
    printf("\n");
REPL_EXIT:
    return 0;
}
