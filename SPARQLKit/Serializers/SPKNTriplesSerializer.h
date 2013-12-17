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
@property BOOL escapeUnicode;

+ (NSString*) nTriplesEncodingOfString: (NSString*) value;
+ (NSString*) nTriplesEncodingOfString: (NSString*) value escapingUnicode:(BOOL)escape;
+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term;
+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term escapingUnicode:(BOOL)escape;

@end
