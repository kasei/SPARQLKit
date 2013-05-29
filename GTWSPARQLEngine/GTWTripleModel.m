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

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
    if (g) {
        id<GTWTripleStore> store   = [self.graphs objectForKey:g.value];
        if (store) {
            BOOL ok = [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t){
                id<GTWQuad> q      = [GTWQuad quadFromTriple:t withGraph:g];
                block(q);
            } error:error];
            if (!ok) {
                return NO;
            }
        }
        return YES;
    } else {
        for (NSString* graphName in [self.graphs allKeys]) {
            GTWIRI* graph   = [[GTWIRI alloc] initWithIRI:graphName];
            id<GTWTripleStore> store    = [self.graphs objectForKey:graphName];
            BOOL ok = [store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t){
                id<GTWQuad> q      = [GTWQuad quadFromTriple:t withGraph:graph];
                block(q);
            } error:error];
            if (!ok) {
                return NO;
            }
        }
        return YES;
    }
}

- (BOOL) enumerateBindingsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(NSDictionary* q)) block error:(NSError **)error {
    //    NSLog(@"%@ %@ %@ %@", s, p, o, g);
    NSMutableDictionary* vars  = [NSMutableDictionary dictionary];
    if ([s conformsToProtocol:@protocol(GTWVariable)]) {
        [vars setObject:s.value forKey:@"subject"];
        s   = nil;
    }
    if ([p conformsToProtocol:@protocol(GTWVariable)]) {
        [vars setObject:p.value forKey:@"predicate"];
        p   = nil;
    }
    if ([o conformsToProtocol:@protocol(GTWVariable)]) {
        [vars setObject:o.value forKey:@"object"];
        o   = nil;
    }
    if ([g conformsToProtocol:@protocol(GTWVariable)]) {
        [vars setObject:g.value forKey:@"graph"];
        g   = nil;
    }
    
    return [self enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
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
