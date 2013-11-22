#import "SPKTripleModel.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import "SPKTree.h"

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

#pragma mark - Mutable Model Methods

- (BOOL) addQuad: (id<GTWQuad>) q error:(NSError **)error {
    id<GTWTerm> graph    = q.graph;
    id<GTWTripleStore> store   = (self.graphs)[graph.value];
    if (store) {
        if ([store conformsToProtocol:@protocol(GTWMutableTripleStore)]) {
            id<GTWTriple> triple    = [GTWTriple tripleFromQuad:q];
            return [(id<GTWMutableTripleStore>)store addTriple:triple error:error];
        } else {
            if (error) {
                NSString* desc  = [NSString stringWithFormat:@"Triple store backing graph %@ is not mutable: %@", graph, store];
                *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:2 userInfo:@{@"description": desc}];
            }
            return NO;
        }
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Graph does not exist for adding quad: %@", graph];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:1 userInfo:@{@"description": desc}];
        }
        return NO;
    }
    
}

- (BOOL) removeQuad: (id<GTWQuad>) q error:(NSError **)error {
    id<GTWTerm> graph    = q.graph;
    id<GTWTripleStore> store   = (self.graphs)[graph.value];
    if (store) {
        if ([store conformsToProtocol:@protocol(GTWMutableTripleStore)]) {
            id<GTWTriple> triple    = [GTWTriple tripleFromQuad:q];
            return [(id<GTWMutableTripleStore>)store removeTriple:triple error:error];
        } else {
            if (error) {
                NSString* desc  = [NSString stringWithFormat:@"Triple store backing graph %@ is not mutable: %@", graph, store];
                *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:2 userInfo:@{@"description": desc}];
            }
            return NO;
        }
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Graph does not exist for removing quad: %@", graph];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:1 userInfo:@{@"description": desc}];
        }
        return NO;
    }
}

- (BOOL) createGraph: (id<GTWIRI>) graph error:(NSError **)error {
    if (error) {
        NSString* desc  = [NSString stringWithFormat:@"SPKTripleModel cannot create empty graphs."];
        *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:3 userInfo:@{@"description": desc}];
    }
    return NO;
}

- (BOOL) dropGraph: (id<GTWIRI>) graph error:(NSError **)error {
    id<GTWTripleStore> store   = (self.graphs)[graph.value];
    if (!store) {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Graph to drop does not exist: %@.", graph];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:4 userInfo:@{@"description": desc}];
        }
        return NO;
    }
    [self.graphs removeObjectForKey:graph.value];
    return YES;
}

- (BOOL) clearGraph: (id<GTWIRI>) graph error:(NSError **)error {
    id<GTWTripleStore> store   = (self.graphs)[graph.value];
    if (store) {
        if ([store conformsToProtocol:@protocol(GTWMutableTripleStore)]) {
            @autoreleasepool {
                NSMutableArray* triples = [NSMutableArray array];
                [store enumerateTriplesMatchingSubject:nil predicate:nil object:nil usingBlock:^(id<GTWTriple> t) {
                    [triples addObject:t];
                } error:error];
                for (id<GTWTriple> t in triples) {
                    [(id<GTWMutableTripleStore>)store removeTriple:t error:error];
                }
            }
            return YES;
        } else {
            if (error) {
                NSString* desc  = [NSString stringWithFormat:@"Triple store backing graph %@ is not mutable: %@", graph, store];
                *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:2 userInfo:@{@"description": desc}];
            }
            return NO;
        }
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Graph does not exist for clearing: %@", graph];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.triplemodel" code:1 userInfo:@{@"description": desc}];
        }
        return NO;
    }
}

#pragma mark - Query Planning

- (id<SPKTree,GTWQueryPlan>) queryPlanForAlgebra: (id<SPKTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model options: (NSDictionary*) options {
//    NSLog(@"SPKTripleModel planning algebra: %@", algebra);
    NSArray* graphs = [self.graphs allKeys];
    NSMutableArray* plans   = [NSMutableArray array];
    NSUInteger customPlans  = 0;
    for (NSString* graph in graphs) {
        GTWIRI* defaultGraph        = [[GTWIRI alloc] initWithValue:graph];
        GTWDataset* subDataset      = [GTWDataset datasetFromDataset:dataset withDefaultGraphs:@[defaultGraph]];
        id<GTWTripleStore> store    = self.graphs[graph];
//        NSLog(@"-> planning with store %@", store);
        if ([store conformsToProtocol:@protocol(SPKQueryPlanner)]) {
            id<SPKTree,GTWQueryPlan> plan   = [(id<SPKQueryPlanner>)store queryPlanForAlgebra: algebra usingDataset: subDataset withModel: model options:options];
            if (plan) {
                customPlans++;
                [plans addObject:plan];
                continue;
            }
        } else {
//            NSLog(@"-> %@ is not a query planning store", store);
        }
        
        // The triple store couldn't plan this pattern, so plan it using the master query planner, restricted to just this graph name
        id<SPKQueryPlanner> planner = options[@"queryPlanner"];
        NSMutableDictionary* replanningOptions  = [NSMutableDictionary dictionaryWithDictionary:options];
        replanningOptions[@"disableCustomPlanning"] = @YES;
        id<SPKTree,GTWQueryPlan> plan   = [planner queryPlanForAlgebra: algebra usingDataset: subDataset withModel: model options:replanningOptions];
        if (!plan)
            return nil;
        [plans addObject:plan];
        continue;
    }
    
    if (customPlans == 0)
        return nil;
    
    if ([plans count]) {
        if ([plans count] == 1) {
            return plans[0];
        } else {
            return [[SPKQueryPlan alloc] initWithType:kPlanUnion arguments:plans];
        }
    }
    return nil;
}

@end
