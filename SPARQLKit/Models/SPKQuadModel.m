#import "SPKQuadModel.h"
#import <GTWSWBase/GTWVariable.h>

@implementation SPKQuadModel

- (SPKQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store {
    if (self = [self init]) {
        self.store  = store;
    }
    return self;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
//    NSLog(@"SPKQuadModel enumerateQuadsMatching...");
    return [self.store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:block error:error];
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
        ok = [self.store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
    //        NSLog(@"creating bindings for quad: %@", q);
            NSMutableDictionary* r = [NSMutableDictionary dictionary];
            BOOL ok = YES;
            for (NSString* pos in vars) {
                NSString* name   = vars[pos];
    //            NSLog(@"mapping variable %@", name);
                id<GTWTerm> value        = [(NSObject*)q valueForKey: pos];
                if (!(r[name]) || ([r[name] isEqual: value])) {
                    r[name] = value;
                } else {
                    ok  = NO;
                    break;
                }
            }
            if (ok) {
                block(r);
            }
        } error: error];
    }
    return ok;
}

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    return [self.store enumerateGraphsUsingBlock:block error:error];
}

#pragma mark - Mutable Model Methods

- (BOOL) addQuad: (id<GTWQuad>) q error:(NSError **)error {
    if ([_store conformsToProtocol:@protocol(GTWMutableQuadStore)]) {
        return [(id<GTWMutableQuadStore>)_store addQuad:q error:error];
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Quad store backing model is not mutable: %@", _store];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.quadmodel" code:2 userInfo:@{@"description": desc}];
        }
        return NO;
    }
}

- (BOOL) removeQuad: (id<GTWQuad>) q error:(NSError **)error {
    if ([_store conformsToProtocol:@protocol(GTWMutableQuadStore)]) {
        return [(id<GTWMutableQuadStore>)_store removeQuad:q error:error];
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Quad store backing model is not mutable: %@", _store];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.quadmodel" code:2 userInfo:@{@"description": desc}];
        }
        return NO;
    }
}

- (BOOL) createGraph: (id<GTWIRI>) graph error:(NSError **)error {
    @autoreleasepool {
        NSMutableSet* graphs    = [NSMutableSet set];
        [_store enumerateGraphsUsingBlock:^(id<GTWTerm> g) {
            [graphs addObject:g];
        } error:error];
        if ([graphs containsObject:graph]) {
            if (error) {
                NSString* desc  = [NSString stringWithFormat:@"Quad store backing model already contains graph: %@", graph];
                *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.quadmodel" code:5 userInfo:@{@"description": desc}];
            }
            return NO;
        }
    }
    // This is a no-op because quad stores don't distinguish between empty and non-existent graphs
    return YES;
}

- (BOOL) dropGraph: (id<GTWIRI>) graph error:(NSError **)error {
    if ([_store conformsToProtocol:@protocol(GTWMutableQuadStore)]) {
        @autoreleasepool {
            NSMutableArray* quads = [NSMutableArray array];
            [_store enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:graph usingBlock:^(id<GTWQuad> q) {
                [quads addObject:q];
            } error:error];
            for (id<GTWQuad> q in quads) {
                [(id<GTWMutableQuadStore>)_store removeQuad:q error:error];
            }
        }
        return YES;
    } else {
        if (error) {
            NSString* desc  = [NSString stringWithFormat:@"Quad store backing model is not mutable: %@", _store];
            *error          = [NSError errorWithDomain:@"us.kasei.sparql.model.quadmodel" code:2 userInfo:@{@"description": desc}];
        }
        return NO;
    }
}

- (BOOL) clearGraph: (id<GTWIRI>) graph error:(NSError **)error {
    // Clearing a graph is the same as dropping a graph because quad stores don't distinguish between empty and non-existent graphs
    return [self dropGraph:graph error:error];
}

@end
