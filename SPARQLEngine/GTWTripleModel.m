#import "GTWTripleModel.h"
#import "GTWTriple.h"
#import "GTWQuad.h"
#import "GTWVariable.h"

@implementation GTWTripleModel

- (GTWTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph {
    if (self = [self init]) {
//        self.store  = store;
//        self.graph  = graph;
        self.graphs = [NSMutableDictionary dictionary];
        [self.graphs setObject:store forKey:graph.value];
    }
    return self;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<Quad> q)) block error:(NSError **)error {
    if (g) {
        id<GTWTripleStore> store   = [self.graphs objectForKey:g.value];
        if (store) {
            [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<Triple> t){
                GTWQuad* q      = [GTWQuad quadFromTriple:t withGraph:g];
                block(q);
            } error:error];
        }
        return YES;
    } else {
        for (NSString* graphName in [self.graphs allKeys]) {
            GTWIRI* graph   = [[GTWIRI alloc] initWithIRI:graphName];
            id<GTWTripleStore> store    = [self.graphs objectForKey:graphName];
            [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<Triple> t){
                GTWQuad* q      = [GTWQuad quadFromTriple:t withGraph:graph];
                block(q);
            } error:error];
        }
        return YES;
    }
}

- (BOOL) enumerateBindingsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(NSDictionary* q)) block error:(NSError **)error {
    //    NSLog(@"%@ %@ %@ %@", s, p, o, g);
    NSMutableDictionary* vars  = [NSMutableDictionary dictionary];
    if ([s isKindOfClass:[GTWVariable class]]) {
        [vars setObject:s.value forKey:@"subject"];
        s   = nil;
    }
    if ([p isKindOfClass:[GTWVariable class]]) {
        [vars setObject:p.value forKey:@"predicate"];
        p   = nil;
    }
    if ([o isKindOfClass:[GTWVariable class]]) {
        [vars setObject:o.value forKey:@"object"];
        o   = nil;
    }
    if ([g isKindOfClass:[GTWVariable class]]) {
        [vars setObject:g.value forKey:@"graph"];
        g   = nil;
    }
    
    return [self enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<Quad> q) {
        //        NSLog(@"creating bindings for quad: %@", q);
        NSMutableDictionary* r = [NSMutableDictionary dictionary];
        BOOL ok = YES;
        for (NSString* pos in vars) {
            NSString* name   = [vars objectForKey:pos];
            //            NSLog(@"mapping variable %@", name);
            id<GTWTerm> value        = [(NSObject*)q valueForKey: pos];
            if ([r objectForKey:name]) {
                ok  = NO;
                break;
            } else {
                [r setObject:value forKey:name];
            }
        }
        if (ok)
            block(r);
    } error: error];
}

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    for (NSString* graph in [self.graphs allKeys]) {
        GTWIRI* iri = [[GTWIRI alloc] initWithIRI:graph];
        block(iri);
    }
    return YES;
}

@end
