//
//  GTWConneg.h
//  GTWConneg
//
//  Created by Gregory Williams on 1/13/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+GTWUtilities.h"

extern NSString* __strong const kSPKConnegQuality;
extern NSString* __strong const kSPKConnegType;
extern NSString* __strong const kSPKConnegEncoding;
extern NSString* __strong const kSPKConnegCharacterSet;
extern NSString* __strong const kSPKConnegLanguage;
extern NSString* __strong const kSPKConnegSize;

NSDictionary* GTWMakeVariant(double qv, NSString* contentType, id encoding, NSString* characterSet, NSString* langauge, NSInteger size);

@interface GTWConneg : NSObject

- (NSArray*) negotiateWithRequest:(NSURLRequest*)req withVariants:(NSDictionary*)variants;

@end
