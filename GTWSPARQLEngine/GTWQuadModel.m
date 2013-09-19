#import "GTWQuadModel.h"
#import <GTWSWBase/GTWVariable.h>

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
    
    return [self.store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
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

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    return [self.store enumerateGraphsUsingBlock:block error:error];
}

@end
