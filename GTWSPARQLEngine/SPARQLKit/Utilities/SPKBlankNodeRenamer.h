//
//  SPKBlankNodeRenamer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/7/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

@interface SPKBlankNodeRenamer : NSObject

@property NSUInteger counter;
@property NSMutableDictionary* mapping;

- (id<GTWStatement,GTWRewriteable>) renameObject: (id<GTWStatement,GTWRewriteable>) object inContext: (id) context;

@end
