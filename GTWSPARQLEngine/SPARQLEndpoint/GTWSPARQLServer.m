//
//  GTWSPARQLServer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLServer.h"
#import "HTTPConnection.h"
#import "GTWSPARQLConfig.h"

@implementation GTWSPARQLServer

- (id)initWithModel:(id<GTWModel>)model dataset:(GTWDataset*)dataset base:(NSString*)base {
    if (self = [super init]) {
        self.dataset    = dataset;
        self.model      = model;
        self.base       = base;
    }
    return self;
}


- (HTTPConfig *)config
{
	return [[GTWSPARQLConfig alloc] initWithServer:self model:self.model dataset:self.dataset base:self.base documentRoot:documentRoot queue:connectionQueue];
}

@end
