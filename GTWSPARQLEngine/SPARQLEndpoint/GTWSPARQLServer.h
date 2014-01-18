//
//  GTWSPARQLServer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "HTTPServer.h"
#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWDataset.h>

@interface GTWSPARQLServer : HTTPServer

@property id<GTWModel> model;
@property GTWDataset* dataset;
@property NSString* base;
@property BOOL verbose;

- (id)initWithModel:(id<GTWModel>)model dataset:(GTWDataset*)dataset base:(NSString*)base verbose:(BOOL)verbose;

@end
