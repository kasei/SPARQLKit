//
//  GTWSPARQLTestHarnessURLProtocol.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/30/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWSPARQLTestHarnessURLProtocol : NSURLProtocol

+ (void) mockEndpoint: (NSURL*) endpoint withModel: (id<GTWModel>) model defaultGraph: (id<GTWIRI>) defaultGraph;
+ (void) mockBadEndpoint: (NSURL*) endpoint;
+ (void) clearMockedEndpoints;

@end
