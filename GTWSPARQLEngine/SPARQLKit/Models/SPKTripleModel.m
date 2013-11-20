#import "SPKTripleModel.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>

@implementation SPKTripleModel

- (SPKTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph {
    if (self = [self init]) {
        [self addStore:store usingGraphName:graph];
    }
    return self;
}

- (SPKTripleModel*) init {
    if (self = [super init]) {
        self.graphs = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void) addStore:(id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph {
    _graphs[graph.value] = store;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
    if (g) {
        id<GTWTripleStore> store   = (self.graphs)[g.value];
        @autoreleasepool {
            if (store) {
                BOOL ok = [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t){
                    id<GTWQuad> q      = [GTWQuad quadFromTriple:t withGraph:g];
                    block(q);
                } error:error];
                if (!ok) {
                    return NO;
                }
            }
        }
        return YES;
    } else {
        @autoreleasepool {
            for (NSString* graphName in [self.graphs allKeys]) {
                GTWIRI* graph   = [[GTWIRI alloc] initWithValue:graphName];
                id<GTWTripleStore> store    = (self.graphs)[graphName];
                BOOL ok = [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t){
                    id<GTWQuad> q      = [GTWQuad quadFromTriple:t withGraph:graph];
                    block(q);
                } error:error];
                if (!ok) {
                    return NO;
                }
            }
        }
        return YES;
    }
}

- (BOOL) enumerateBindingsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(NSDictionary* q)) block error:(NSError **)error {
    //    NSLog(@"%@ %@ %@ %@", s, p, o, g);
    NSMutableDictionary* vars  = [NSMutableDictionary dictionary];
    if ([s conformsToProtocol:@protocol(GTWVariable)]) {
        vars[@"subject"] = s.value;
        s   = nil;
    }
    if ([p conformsToProtocol:@protocol(GTWVariable)]) {
        vars[@"predicate"] = p.value;
        p   = nil;
    }
    if ([o conformsToProtocol:@protocol(GTWVariable)]) {
        vars[@"object"] = o.value;
        o   = nil;
    }
    if ([g conformsToProtocol:@protocol(GTWVariable)]) {
        vars[@"graph"] = g.value;
        g   = nil;
    }
    
    BOOL ok;
    @autoreleasepool {
        ok  = [self enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
            //        NSLog(@"creating bindings for quad: %@", q);
            NSMutableDictionary* r = [NSMutableDictionary dictionary];
            BOOL ok = YES;
            for (NSString* pos in vars) {
                NSString* name   = vars[pos];
                //            NSLog(@"mapping variable %@", name);
                id<GTWTerm> value        = [(NSObject*)q valueForKey: pos];
                if (r[name]) {
                    ok  = NO;
                    break;
                } else {
                    r[name] = value;
                }
            }
            if (ok)
                block(r);
        } error: error];
    }
    return ok;
}

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    @autoreleasepool {
        for (NSString* graph in [self.graphs allKeys]) {
            GTWIRI* iri = [[GTWIRI alloc] initWithValue:graph];
            block(iri);
        }
    }
    return YES;
}

- (id<SPKTree,GTWQueryPlan>) queryPlanForAlgebra: (id<SPKTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model options: (NSDictionary*) options {
    NSArray* graphs = [self.graphs allKeys];
    NSString* graph = [graphs firstObject];
    if (graph) {
        id<GTWTripleStore> store    = self.graphs[graph];
        if (store) {
            if ([store conformsToProtocol:@protocol(SPKQueryPlanner)]) {
                NSMutableDictionary* dict    = [NSMutableDictionary dictionary];
                if (options) {
                    [dict addEntriesFromDictionary:options];
                }
                dict[@"tripleStoreIdentifier"]   = graph;
                id<SPKTree,GTWQueryPlan> plan   = [(id<SPKQueryPlanner>)store queryPlanForAlgebra: algebra usingDataset: dataset withModel: model options:dict];
                if (plan) {
                    return plan;
                }
            }
        }
    }
    return nil;
}

@end
