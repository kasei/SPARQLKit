//
//  SPKPrefixNameSerializerDelegate.h
//  SPARQLKit
//
//  Created by Gregory Williams on 12/7/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface SPKPrefixNameSerializerDelegate : NSObject<GTWSerializerDelegate>

@property (retain) NSDictionary* prefixes;

- (SPKPrefixNameSerializerDelegate*) initWithNamespaceDictionary: (NSDictionary*) namespaces;
- (NSString*) stringFromObject: (id) object;

@end
