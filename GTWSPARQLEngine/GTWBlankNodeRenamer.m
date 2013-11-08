//
//  GTWBlankNodeRenamer.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/7/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWBlankNodeRenamer.h"

@implementation GTWBlankNodeRenamer

- (GTWBlankNodeRenamer*) init {
    if (self = [super init]) {
        self.mapping    = [NSMutableDictionary dictionary];
        self.counter    = 0;
    }
    return self;
}

- (id<GTWStatement,GTWRewriteable>) renameObject: (id<GTWStatement,GTWRewriteable>) object inContext: (NSString*) context {
    NSArray* terms  = [object allValues];
    for (id<GTWTerm> t in terms) {
        if ([t isKindOfClass:[GTWBlank class]]) {
            id<GTWTerm> mapped  = [self.mapping objectForKey:t];
            if (!mapped) {
                mapped   = [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"b-%@-%lu", context, self.counter++]];
                [self.mapping setObject:mapped forKey:t];
            }
        }
    }
    id<GTWStatement,GTWRewriteable> new     = [object copyReplacingValues:self.mapping];
    return new;
}

@end
