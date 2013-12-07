//
//  SPKSPARQLResultsTSVSerializer.h
//  SPARQLKit
//
//  Created by Gregory Williams on 12/6/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface SPKSPARQLResultsTSVSerializer : NSObject<GTWSerializer, GTWSPARQLResultsSerializer>

@property id<GTWSerializerDelegate> delegate;

@end
