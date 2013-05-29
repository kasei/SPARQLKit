#import <Foundation/Foundation.h>
#import "GTWSPARQLProtocol.h"

#define BLACKWATCH_FEDERATOR_NAME "GTWSPARQLEngine"
#define BLACKWATCH_FEDERATOR_VERSION "0.0.1"

static NSString* OSVersionNumber ( void ) {
    NSDictionary *version = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    NSString *productVersion = [version objectForKey:@"ProductVersion"];
    return productVersion;
}

@implementation GTWSPARQLProtocolStore

- (GTWSPARQLProtocolStore*) initWithEndpoint: (NSString*) endpoint {
    if (self = [self init]) {
        self.endpoint   = endpoint;
    }
    return self;
}

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSMutableArray* triples = [NSMutableArray array];
    [self enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t) {
        [triples addObject:t];
    } error:error];
    return triples;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    NSString* sparql    = [NSString stringWithFormat:@"SELECT * WHERE { %@ %@ %@ }", s, p, o];
	NSString* query		= [[[sparql stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"&" withString:@"%26"] stringByReplacingOccurrencesOfString:@";" withString:@"%3B"];
	NSURL* url	= [NSURL URLWithString:[NSString stringWithFormat:@"%@?query=%@", self.endpoint, query]];
	NSMutableURLRequest* req	= [NSMutableURLRequest requestWithURL:url];
	[req setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
	[req setTimeoutInterval:450.0];
    
	NSString* user_agent	= [NSString stringWithFormat:@"%s/%s Darwin/%@", BLACKWATCH_FEDERATOR_NAME, BLACKWATCH_FEDERATOR_VERSION, OSVersionNumber()];
	[req setValue:user_agent forHTTPHeaderField:@"User-Agent"];
	[req setValue:@"application/sparql-results+xml" forHTTPHeaderField:@"Accept"];
    
	NSData* data	= nil;
	NSHTTPURLResponse* resp	= nil;
	NSError* _error			= nil;
    //	NSLog(@"request: %@", req);
	data	= [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&_error];
    //	NSLog(@"got response with %lu bytes: %@", [data length], [resp allHeaderFields]);
    //	NSLog(@"got response with %lu bytes", [data length]);
	if (data) {
		NSInteger code	= [resp statusCode];
        if (code >= 300) {
//            NSLog(@"error: (%03ld) %@\n", code, [NSHTTPURLResponse localizedStringForStatusCode:code]);
            NSDictionary* headers	= [resp allHeaderFields];
            NSString* type		= [headers objectForKey:@"Content-Type"];
            if (error) {
                if ([type hasPrefix:@"text/"]) {
                    *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"body": [NSString stringWithCString:[data bytes] encoding:NSUTF8StringEncoding]}];
                } else {
                    *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"data": data}];
                }
            }
            return NO;
        } else {
            // TODO: parse the srx data
            NSLog(@"*** should parse SRX data of length %lu here\n", [data length]);
            return YES;
        }
	} else {
//		NSInteger code	= [resp statusCode];
//		NSLog(@"error: (%03ld) %@\n", code, [NSHTTPURLResponse localizedStringForStatusCode:code]);
//        NSLog(@"... %@", _error);
        if (error) {
            NSLog(@"SPARQL Protocol HTTP error: %@", _error);
            *error  = _error;
        }
        return NO;
	}
}

@end
