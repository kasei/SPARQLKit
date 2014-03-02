//
//  SPKUpdate.h
//  SPARQLKit
//
//  Created by Gregory Williams on 2/28/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPKOperation.h"

@interface SPKUpdate : SPKOperation

- (SPKUpdate*) initWithUpdateString: (NSString*) udpateString baseURI: (NSString*) base;
- (id<SPKTree>) parseWithError: (NSError*__autoreleasing*) error;

@end
