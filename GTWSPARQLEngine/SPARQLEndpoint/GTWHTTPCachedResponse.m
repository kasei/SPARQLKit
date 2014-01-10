//
//  GTWHTTPCachedResponse.m
//  SPARQLKit
//
//  Created by Gregory Williams on 1/9/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "GTWHTTPCachedResponse.h"

@implementation GTWHTTPCachedResponse

- (GTWHTTPCachedResponse*) init {
	if((self = [super initWithData:[NSData data]])) {
	}
	return self;
}

- (NSInteger)status {
    return 304;
}

@end
