//
//  SPKOperation.m
//  SPARQLKit
//
//  Created by Gregory Williams on 3/1/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "SPKOperation.h"
#import "SPKSPARQLParser.h"
#import "SPKSimpleQueryEngine.h"
#import "SPKQueryPlanner.h"

@implementation SPKOperation

- (SPKOperation*) initWithString: (NSString*) opString baseURI: (NSString*) base {
    if (self = [self init]) {
        self.opString       = [opString copy];
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
    id<SPKTree> algebra;
    
    algebra = [self.parser parseSPARQLOperation:self.opString withBaseURI:self.opBase settingPrefixes:self.prefixes error:&e];
    
    if (e) {
        NSLog(@"parser error: %@", e);
        if (error)
            *error  = e;
        return nil;
    }
    if (self.verbose) {
        NSLog(@"query:\n%@", algebra);
    }
    
    self.algebra    = algebra;
    return algebra;
}

- (id<GTWQueryPlan>) planWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error {
    if (![self parseWithError:error])
        return nil;
    
    id<SPKTree> algebra     = self.algebra;
    SPKTree<SPKTree,GTWQueryPlan>* plan   = [self.planner queryPlanForAlgebra:algebra usingDataset:self.dataset withModel: model optimize:YES options:nil];
    if (self.verbose) {
        NSLog(@"plan:\n%@", plan);
    }
    
    if (!plan)
        return nil;
    
    self.plan   = plan;
    return plan;
}

- (NSEnumerator*) executeWithModel:(id<GTWModel>) model error: (NSError*__autoreleasing*) error {
    if (![self planWithModel:model error:error])
        return nil;
    
    SPKTree<SPKTree,GTWQueryPlan>* plan   = (SPKTree<SPKTree,GTWQueryPlan>*) self.plan;
    self.variables      = [plan inScopeVariables];
    self.resultClass    = [plan planResultClass];
    
    if (self.verbose) {
        NSLog(@"executing query...");
    }
    
    NSEnumerator* results   = [self.engine evaluateQueryPlan:plan withModel:model];
    return results;
}


@end
