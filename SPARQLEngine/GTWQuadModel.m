#import "GTWQuadModel.h"
#import "GTWVariable.h"

@implementation GTWQuadModel

- (GTWQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store {
    if (self = [self init]) {
        self.store  = store;
    }
    return self;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
//    NSLog(@"GTWQuadModel enumerateQuadsMatching...");
    return [self.store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:block error:error];
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
    
    return [self.store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
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
    return [self.store enumerateGraphsUsingBlock:block error:error];
}

@end
