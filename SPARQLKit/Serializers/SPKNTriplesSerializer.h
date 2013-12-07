//
//  SPKNTriplesSerializer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/12/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface SPKNTriplesSerializer : NSObject<GTWSerializer, GTWTriplesSerializer>

@property id<GTWSerializerDelegate> delegate;

+ (NSString*) nTriplesEncodingOfString: (NSString*) value;
+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term;

@end
