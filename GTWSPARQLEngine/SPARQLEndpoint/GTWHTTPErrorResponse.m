//
//  GTWHTTPErrorResponse.m
//  SPARQLKit
//
//  Created by Gregory Williams on 1/12/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "GTWHTTPErrorResponse.h"

@implementation GTWHTTPErrorResponse

+ (GTWHTTPErrorResponse*) serverErrorResponseWithType:(NSString*)type title:(NSString*)title detail:(NSString*)detail {
    return [[GTWHTTPErrorResponse alloc] initWithDictionary:@{@"type": type, @"title":title, @"detail":detail} errorCode:500];
}

+ (GTWHTTPErrorResponse*) requestErrorResponseWithType:(NSString*)type title:(NSString*)title detail:(NSString*)detail {
    return [[GTWHTTPErrorResponse alloc] initWithDictionary:@{@"type": type, @"title":title, @"detail":detail} errorCode:400];
}

- (id)initWithDictionary:(NSDictionary*)dict errorCode:(int)httpErrorCode {
    if (!([dict objectForKey:@"type"] && [dict objectForKey:@"title"])) {
        NSLog(@"GTWHTTPErrorResponse dictionary requires both 'type' and 'title' fields: %@", dict);
        return nil;
    }
    
    NSError* error;
    NSData* dataParam   = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (!dataParam) {
        NSLog(@"%@", error);
        return nil;
    }
    if (self = [super initWithData:dataParam]) {
        _status = httpErrorCode;
    }
    return self;
}

- (NSInteger) status {
    return _status;
}

- (NSDictionary *)httpHeaders {
    return @{
             @"Content-Type": @"application/problem+json",
             };
}

@end
