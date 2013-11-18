//
//  GTWNTriplesSerializer.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 10/12/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWNTriplesSerializer : NSObject<GTWSerializer, GTWTriplesSerializer>

+ (NSString*) nTriplesEncodingOfString: (NSString*) value;
+ (NSString*) nTriplesEncodingOfTerm: (id<GTWTerm>) term;

@end
