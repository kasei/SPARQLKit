//
//  GTWHTTPDataResponse.m
//  SPARQLKit
//
//  Created by Gregory Williams on 1/9/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "GTWHTTPDataResponse.h"

@implementation GTWHTTPDataResponse

- (NSString *)dateAsString:(NSDate *)date
{
	// From Apple's Documentation (Data Formatting Guide -> Date Formatters -> Cache Formatters for Efficiency):
	//
	// "Creating a date formatter is not a cheap operation. If you are likely to use a formatter frequently,
	// it is typically more efficient to cache a single instance than to create and dispose of multiple instances.
	// One approach is to use a static variable."
	//
	// This was discovered to be true in massive form via issue #46:
	//
	// "Was doing some performance benchmarking using instruments and httperf. Using this single optimization
	// I got a 26% speed improvement - from 1000req/sec to 3800req/sec. Not insignificant.
	// The culprit? Why, NSDateFormatter, of course!"
	//
	// Thus, we are using a static NSDateFormatter here.
	
	static NSDateFormatter *df;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		// Example: Sun, 06 Nov 1994 08:49:37 GMT
		
		df = [[NSDateFormatter alloc] init];
		[df setFormatterBehavior:NSDateFormatterBehavior10_4];
		[df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		[df setDateFormat:@"EEE, dd MMM y HH:mm:ss 'GMT'"];
		[df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
		
		// For some reason, using zzz in the format string produces GMT+00:00
	});
	
	return [df stringFromDate:date];
}

- (NSDictionary *)httpHeaders {
    NSMutableDictionary* headers    = [NSMutableDictionary dictionary];
    if (self.contentType) {
        headers[@"Content-Type"]    = self.contentType;
    }
    
//    NSLog(@"LAST MODIFIED %@", self.lastModified);
	if (self.lastModified) {
        [headers addEntriesFromDictionary: @{
                 @"Last-Modified": [self dateAsString:self.lastModified],
                 @"Expires": [self dateAsString:[NSDate date]],
                 @"Cache-Control": @"max-age=0"
        }];
    }
    return headers;
}

@end
