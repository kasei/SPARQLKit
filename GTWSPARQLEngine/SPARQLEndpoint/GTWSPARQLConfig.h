//
//  GTWSPARQLConfig.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "HTTPConnection.h"
#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWDataset.h>

@interface GTWSPARQLConfig : HTTPConfig

@property id<GTWModel> model;
@property GTWDataset* dataset;
@property NSString* base;
@property BOOL verbose;

- (id)initWithServer:(HTTPServer *)server model:(id<GTWModel>)model dataset:(GTWDataset*)dataset base:(NSString*) base documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;

@end
