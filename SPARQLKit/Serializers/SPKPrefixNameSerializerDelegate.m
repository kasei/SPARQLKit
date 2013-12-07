//
//  SPKPrefixNameSerializerDelegate.m
//  SPARQLKit
//
//  Created by Gregory Williams on 12/7/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPKPrefixNameSerializerDelegate.h"
#import <GTWSWBase/GTWIRI.h>

@implementation SPKPrefixNameSerializerDelegate

- (SPKPrefixNameSerializerDelegate*) initWithNamespaceDictionary: (NSDictionary*) namespaces {
    if (self = [self init]) {
        NSMutableDictionary* iriToPrefix    = [NSMutableDictionary dictionary];
        for (NSString* ns in namespaces) {
            iriToPrefix[namespaces[ns]] = ns;
        }
        self.prefixes   = [iriToPrefix copy];
    }
    return self;
}

- (NSString*) stringFromObject: (id) object {
    if (!object)
        return nil;
    if ([object isKindOfClass:[GTWIRI class]]) {
        GTWIRI* i       = (GTWIRI*) object;
        NSString* iri   = i.value;
        for (NSString* prefix in self.prefixes) {
            if ([iri hasPrefix:prefix]) {
                NSString* local = [iri substringFromIndex:[prefix length]];
                return [NSString stringWithFormat:@"%@:%@", self.prefixes[prefix], local];
            }
        }
        return nil;
    }
    return nil;
}

@end
