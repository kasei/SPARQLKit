//
//  SPKNQuadsSerializer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/31/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import "SPKNTriplesSerializer.h"

@interface SPKNQuadsSerializer : NSObject<GTWSerializer, GTWQuadsSerializer>

@property id<GTWSerializerDelegate> delegate;

@end
