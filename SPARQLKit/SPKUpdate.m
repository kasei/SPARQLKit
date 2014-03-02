//
//  SPKUpdate.m
//  SPARQLKit
//
//  Created by Gregory Williams on 2/28/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "SPKUpdate.h"
#import "SPKSPARQLParser.h"
#import "SPKSimpleQueryEngine.h"
#import "SPKQueryPlanner.h"

@implementation SPKUpdate

- (SPKUpdate*) initWithUpdateString: (NSString*) updateString baseURI: (NSString*) base {
    if (self = [self init]) {
        self.opString       = [updateString copy];
        self.opBase         = [base copy];
        self.parser         = [[SPKSPARQLParser alloc] init];
        self.engine         = [[SPKSimpleQueryEngine alloc] init];
        self.planner        = [[SPKQueryPlanner alloc] init];
        self.prefixes       = [NSMutableDictionary dictionary];
        GTWIRI* defGraph    = [[GTWIRI alloc] initWithValue: base];
        self.dataset        = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[defGraph]];
    }
    return self;
}

- (id<SPKTree>) parseWithError: (NSError*__autoreleasing*) error {
    NSError* e;
    id<SPKTree> algebra = [self.parser parseSPARQLUpdate:self.opString withBaseURI:self.opBase settingPrefixes:self.prefixes error:&e];
    
    if (e) {
        NSLog(@"parser error: %@", e);
        if (error)
            *error  = e;
        return nil;
    }
    if (self.verbose) {
        NSLog(@"update:\n%@", algebra);
    }
    
    self.algebra    = algebra;
    return algebra;
}

@end
