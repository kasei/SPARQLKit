//
//  GTWHTTPErrorResponse.h
//  SPARQLKit
//
//  Created by Gregory Williams on 1/12/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "HTTPDataResponse.h"

@interface GTWHTTPErrorResponse : HTTPDataResponse {
    NSInteger _status;
}

+ (GTWHTTPErrorResponse*) serverErrorResponseWithType:(NSString*)type title:(NSString*)title detail:(NSString*)detail;
+ (GTWHTTPErrorResponse*) requestErrorResponseWithType:(NSString*)type title:(NSString*)title detail:(NSString*)detail;
- (id)initWithDictionary:(NSDictionary*)dict errorCode:(int)httpErrorCode;

@end
