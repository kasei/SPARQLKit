//
//  GTWSPARQLTestHarnessURLProtocol.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/30/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLTestHarnessURLProtocol.h"
#import "GTWSPARQLParser.h"
#import "GTWQueryPlanner.h"
#import "GTWSimpleQueryEngine.h"
#import "GTWTree.h"
#import "GTWSPARQLResultsXMLSerializer.h"

static NSMutableDictionary *_mockedRequests;
static dispatch_once_t mockToken;

@implementation GTWSPARQLTestHarnessURLProtocol

+ (void) load {
    dispatch_once(&mockToken, ^{
        _mockedRequests = [NSMutableDictionary dictionary];
    });
}

+ (void) clearMockedEndpoints {
    [_mockedRequests removeAllObjects];
}

+ (void) mockEndpoint: (NSURL*) endpoint withModel: (id<GTWModel>) model defaultGraph: (id<GTWIRI>) defaultGraph {
    [_mockedRequests setObject:@[model, defaultGraph] forKey:endpoint];
    NSLog(@"=============================\n%@\n=============================\n", _mockedRequests);
}

+ (void) mockBadEndpoint: (NSURL*) endpoint {
    [_mockedRequests setObject:@[] forKey:endpoint];
}

+ (BOOL) canInitWithRequest:(NSURLRequest *)request {
    NSURL* url  = [request URL];
    NSURL* ep   = [[NSURL alloc] initWithScheme:[url scheme] host:[url host] path:[url path]];
    
    NSArray* data       = [_mockedRequests objectForKey:ep];
//    NSLog(@"mocked response data: %@", data);
    if (data) {
        return YES;
    } else {
        NSLog(@"not mocking request for %@", ep);
        return NO;
    }
}

+ (NSURLRequest *) canonicalRequestForRequest: (NSURLRequest *)request {
    return request;
}

- (void) startLoading {
    id<NSURLProtocolClient> client = [self client];
    NSURLRequest *request = [self request];
    NSURL* url  = [request URL];
//    NSLog(@"MOCKING %@", url);
    NSURL* ep   = [[NSURL alloc] initWithScheme:[url scheme] host:[url host] path:[url path]];
    
    NSArray* mockData       = [_mockedRequests objectForKey:ep];
    if (!mockData) {
        NSError* error  = [NSError errorWithDomain:@"us.kasei.sparql.mock-urlprotocol" code:-1 userInfo:@{@"description": [NSString stringWithFormat:@"No mock data present for endpoint %@", ep]}];
        [client URLProtocol:self didFailWithError:error];
    }
    
    if ([mockData count]) {
        id<GTWModel> model      = mockData[0];
        id<GTWIRI> defaultGraph = mockData[1];
        
        NSString* string = [url query];
        NSScanner* scanner = [NSScanner scannerWithString:string];
        [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"&?"]];
        NSString* tempString;
        NSMutableDictionary *vars = [NSMutableDictionary dictionary];
        while ([scanner scanUpToString:@"&" intoString:&tempString]) {
            NSArray* pair   = [tempString componentsSeparatedByString:@"="];
            CFStringRef unescaped = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                                          (CFStringRef)pair[1],
                                                                                          CFSTR(""),
                                                                                          kCFStringEncodingUTF8);
            NSString* value = [NSString stringWithString:(__bridge NSString*) unescaped];
            CFRelease(unescaped);
            [vars setObject:value forKey:pair[0]];
        }
        
        NSString* sparql = vars[@"query"];
        id<GTWSPARQLParser> parser  = [[GTWSPARQLParser alloc] init];
        id<GTWTree> algebra    = [parser parseSPARQL:sparql withBaseURI:defaultGraph.value];
        GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
        GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defaultGraph]];
        GTWTree<GTWTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model optimize: YES];
        [plan computeProjectVariables];
        id<GTWQueryEngine> engine   = [[GTWSimpleQueryEngine alloc] init];
        
        if (NO) {
            NSLog(@"MOCKED model ------------------->\n");
            [model enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q) {
                NSLog(@"-> %@", q);
            } error:nil];
            NSLog(@"<------------------- MOCKED model\n");
            NSLog(@"%@", plan);
    //        NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
    //        for (NSDictionary* r in e) {
    //            NSLog(@"----> %@", r);
    //        }
        }

//        NSLog(@"executing query...");
        NSEnumerator* e     = [engine evaluateQueryPlan:plan withModel:model];
//        NSLog(@"got resutls");
        id<GTWSPARQLResultsSerializer> s    = [[GTWSPARQLResultsXMLSerializer alloc] init];
        NSSet* variables    = [plan annotationForKey:kProjectVariables];
        NSData* data        = [s dataFromResults:e withVariables:variables];
//        NSLog(@"serialized %lu bytes in SRX format", [data length]);
        
        NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:200 HTTPVersion:@"1.1" headerFields:@{ @"Content-Type": @"application/sparql-results+xml" }];
//        NSLog(@"notifying client of RESPONSE");
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
//        NSLog(@"sending client data");
        [client URLProtocol:self didLoadData:data];
//        NSLog(@"notifying client of load finish");
        [client URLProtocolDidFinishLoading:self];
//        NSLog(@"done MOCKING");
    } else {
        NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[request URL] statusCode:404 HTTPVersion:@"1.1" headerFields:@{ @"Content-Type": @"text/plain" }];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
        NSData* data            = [@"Not found" dataUsingEncoding:NSUTF8StringEncoding];
        [client URLProtocol:self didLoadData:data];
        [client URLProtocolDidFinishLoading:self];
    }
}

- (void) stopLoading {
}

@end
