#import "GTWTripleModel.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>

@implementation GTWTripleModel

- (GTWTripleModel*) initWithTripleStore: (id<GTWTripleStore>) store usingGraphName: (GTWIRI*) graph {
    if (self = [self init]) {
//        self.store  = store;
//        self.graph  = graph;
        self.graphs = [NSMutableDictionary dictionary];
        (self.graphs)[graph.value] = store;
    }
    return self;
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

@end
