//
//  SPKMutableURLRequest.m
//  SPARQLKit
//
//  Created by Gregory Williams on 12/3/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKMutableURLRequest.h"
#import "SPARQLKit.h"

static NSString* OSVersionNumber ( void ) {
    static NSString* productVersion    = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSDictionary *version = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
        productVersion = version[@"ProductVersion"];
    });
    return productVersion;
}

@implementation SPKMutableURLRequest

+ (NSString*) userAgentTokens {
    NSString* user_agent	= [NSString stringWithFormat:@"%@/%@ Darwin/%@", SPARQLKIT_NAME, SPARQLKIT_VERSION, OSVersionNumber()];
    return user_agent;
}

+ (NSMutableURLRequest*) requestWithURL: (NSURL*) url {
    SPKMutableURLRequest* req   = [super requestWithURL:url];
	[req setCachePolicy:NSURLRequestReturnCacheDataElseLoad];
    //	[req setTimeoutInterval:5.0];
    
    NSString* user_agent    = [self userAgentTokens];
	[req setValue:user_agent forHTTPHeaderField:@"User-Agent"];
    return req;
}

- (void) addUserAgentTokenName: (NSString*) name version: (NSString*) version {
	NSString* userAgent	= [self valueForHTTPHeaderField:@"User-Agent"];
    NSString* newAgent  = [NSString stringWithFormat:@"%@/%@ %@", name, version, userAgent];
	[self setValue:newAgent forHTTPHeaderField:@"User-Agent"];
}

@end
