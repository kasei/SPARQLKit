//
//  SPKQuery.h
//  SPARQLKit
//
//  Created by Gregory Williams on 12/6/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPKOperation.h"

@interface SPKQuery : SPKOperation

- (SPKQuery*) initWithQueryString: (NSString*) queryString baseURI: (NSString*) base;
- (id<SPKTree>) parseWithError: (NSError*__autoreleasing*) error;

@end
