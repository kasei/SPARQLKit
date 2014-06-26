//
//  SPKMutableURLRequest.h
//  SPARQLKit
//
//  Created by Gregory Williams on 12/3/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPKMutableURLRequest : NSMutableURLRequest

+ (NSString*) userAgentTokens;
- (void) addUserAgentTokenName: (NSString*) name version: (NSString*) version;

@end
