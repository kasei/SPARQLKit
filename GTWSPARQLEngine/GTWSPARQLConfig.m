//
//  GTWSPARQLConfig.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLConfig.h"

@implementation GTWSPARQLConfig

- (id)initWithServer:(HTTPServer *)_server model:(id<GTWModel>)model dataset:(GTWDataset*)dataset base:(NSString*)base documentRoot:(NSString *)_documentRoot queue:(dispatch_queue_t)q {
    if (self = [super initWithServer:_server documentRoot:_documentRoot queue:q]) {
        self.dataset    = dataset;
        self.model      = model;
        self.base       = base;
    }
    return self;
}
@end
