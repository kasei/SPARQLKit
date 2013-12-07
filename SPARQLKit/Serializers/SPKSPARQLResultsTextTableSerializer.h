//
//  SPKSPARQLResultsTextTableSerializer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import <GTWSWBase/GTWSWBase.h>

@interface SPKSPARQLResultsTextTableSerializer : NSObject<GTWSerializer, GTWSPARQLResultsSerializer>

@property (retain,readwrite) id<GTWSerializerDelegate> delegate;

@end
