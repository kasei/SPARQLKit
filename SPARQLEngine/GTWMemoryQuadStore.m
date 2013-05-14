#import "GTWMemoryQuadStore.h"

@implementation GTWMemoryQuadStore

- (void) _addQuad: (id<Quad>) q toIndex: (NSMutableDictionary*) idx withPositions: (NSArray*) positions {
    // caller is responsible for using @synchronized(idx)
    NSObject<Quad>* qq  = (NSObject<Quad>*) q;
    //    NSLog(@"indexing quad: %@\n", q);
    NSMutableArray* keyarray    = [NSMutableArray array];
    for (NSString* p in positions) {
        NSObject<GTWTerm>* t   = [qq valueForKey: p];
        [keyarray addObject:t];
    }
    
    NSString* indexKey  = [keyarray componentsJoinedByString:@" "];
    //        NSLog(@"indexing quad: %@ => %@\n", indexKey, q);
    
    NSMutableSet* set;
    set = [idx objectForKey:indexKey];
    if (!set) {
        set = [NSMutableSet set];
        [idx setObject:set forKey:indexKey];
    }
    [set addObject:q];
}

- (void) _removeQuad: (id<Quad>) q fromIndex: (NSMutableDictionary*) idx withPositions: (NSArray*) positions {
    // caller is responsible for using @synchronized(idx)
    NSObject<Quad>* qq  = (NSObject<Quad>*) q;
    //    NSLog(@"indexing quad: %@\n", q);
    NSMutableArray* keyarray    = [NSMutableArray array];
    for (NSString* p in positions) {
        NSObject<GTWTerm>* t   = [qq valueForKey: p];
        [keyarray addObject:t];
    }
    
    NSString* indexKey  = [keyarray componentsJoinedByString:@" "];
    //        NSLog(@"indexing quad: %@ => %@\n", indexKey, q);
    
    NSMutableSet* set;
    set = [idx objectForKey:indexKey];
    if (set) {
        [set removeObject:q];
    }
}

- (GTWMemoryQuadStore*) init {
    if (self = [super init]) {
        self.quads      = [[NSMutableSet alloc] init];
        self.queue      = dispatch_queue_create("us.kasei.sparql.quadstore", DISPATCH_QUEUE_CONCURRENT);
        self.indexes    = [NSMutableDictionary dictionary];
        self.indexKeys  = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL) addIndexType: (NSString*) type value: (NSArray*) positions synchronous: (BOOL) sync error: (NSError**) error {
    if ([type isEqualToString:@"term"]) {
        for (NSString* p in positions) {
            if (!([p isEqualToString:@"subject"] || [p isEqualToString:@"predicate"] || [p isEqualToString:@"object"] || [p isEqualToString:@"graph"])) {
                NSLog(@"Cannot add index for unknown term position '%@'", p);
                // TODO: set error
                [self.logger logData:@"" forKey:@""];
                return NO;
            }
        }
        NSString* name  = [positions componentsJoinedByString:@", "];
        NSLog(@"Adding index on term positions: <%@>\n", name);
        
        
        __block BOOL ok = YES;
        __block NSMutableDictionary* idx;
        dispatch_barrier_sync(self.queue, ^{
    //        NSLog(@"async dispatch setting up index");
            // add index to store
            idx    = [self.indexes objectForKey:name];
            if (!idx) {
                idx    = [NSMutableDictionary dictionary];
                [self.indexKeys setObject:positions forKey:name];
                [self.indexes setObject:idx forKey:name];
            } else {
                NSLog(@"Index on terms <%@> already exists", name);
                ok  = NO;
                return;
            }
            
            // index existing quads
            if (!sync) {
                NSEnumerator* e = [self.quads objectEnumerator];
                dispatch_async(self.queue, ^{
                    @synchronized(idx) {
                        for (NSObject<Quad>* q in e) {
                            [self _addQuad:q toIndex:idx withPositions:positions];
                        }
                    }
                });
            }
        });
        if (!ok) {
            return NO;
        }
        
        if (sync) {
            @synchronized(idx) {
                for (NSObject<Quad>* q in self.quads) {
                    [self _addQuad:q toIndex:idx withPositions:positions];
                }
            }
        }
    } else {
        // TODO: set error
        return NO;
    }
    return YES;
}

- (NSArray*) getGraphsWithOutError:(NSError **)error {
    NSMutableArray* graphs  = [NSMutableArray array];
    NSMutableSet* seen  = [NSMutableSet set];
    for (id<Quad> q in self.quads) {
        if (![seen containsObject:q.graph]) {
            [graphs addObject:q.graph];
            [seen addObject:q.graph];
        }
    }
    return graphs;
}

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    NSMutableSet* seen  = [NSMutableSet set];
    [self.quads enumerateObjectsUsingBlock:^(id<Quad> q, BOOL* stop){
        if (![seen containsObject:q.graph]) {
            block(q.graph);
            [seen addObject:q.graph];
        }
    }];
    return YES;
}

- (NSArray*) getQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error {
    NSMutableArray* quads    = [NSMutableArray array];
    [self enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<Quad> q){
        [quads addObject:q];
    } error:error];
    return quads;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<Quad> q)) block error:(NSError **)error {
    [self.quads enumerateObjectsUsingBlock:^(id<Quad> q, BOOL* stop){
        if (s) {
            if (![s isEqual:q.subject])
                return;
        }
        if (p) {
            if (![p isEqual:q.predicate])
                return;
        }
        if (o) {
            if (![o isEqual:q.object])
                return;
        }
        if (g) {
            if (![g isEqual:q.graph])
                return;
        }
//        NSLog(@"enumerating matching quad: %@", q);
        block(q);
    }];
    return YES;
}

- (BOOL) addQuad: (id<Quad>) q error:(NSError **)error {
//    NSLog(@"+ %8lu %@", [self.quads count], q);
    [self.quads addObject:q];
    dispatch_barrier_async(self.queue, ^{
        for (NSString* name in self.indexes) {
            NSMutableDictionary* idx    = [self.indexes objectForKey:name];
            dispatch_async(self.queue, ^{
                NSArray* positions  = [self.indexKeys objectForKey:name];
                @synchronized(idx) {
                    [self _addQuad:q toIndex:idx withPositions:positions];
                }
            });
        }
    });
    
    return YES;
}

- (BOOL) removeQuad: (id<Quad>) q error:(NSError **)error {
    [self.quads removeObject:q];
    dispatch_barrier_async(self.queue, ^{
        for (NSString* name in self.indexes) {
            NSMutableDictionary* idx    = [self.indexes objectForKey:name];
            dispatch_async(self.queue, ^{
                NSArray* positions  = [self.indexKeys objectForKey:name];
                @synchronized(idx) {
                    [self _removeQuad:q fromIndex:idx withPositions:positions];
                }
            });
        }
    });
    
    return YES;
}

- (void) dealloc {
    dispatch_suspend(self.queue);
}

- (NSString*) description {
    NSMutableString* d  = [NSMutableString string];
    [d appendFormat:@"Quadstore with %lu statements\n", [self.quads count]];
    [d appendFormat:@"%lu Indexes:\n", [self.indexes count]];
    for (id i in self.indexes) {
        NSSet* set  = [self.indexes objectForKey:i];
        [d appendFormat:@"    - %@ (%lu items)\n", i, [set count]];
    }
    return d;
}

- (NSString*) bestIndexForMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g {
    NSUInteger bestKeyCount = -1;
    NSUInteger bestMatching = 0;
    NSUInteger bestHistSize = 0;
    NSString* bestName      = nil;
    
    for (id name in self.indexes) {
        NSArray* keys           = [self.indexKeys objectForKey:name];
        NSUInteger keyCount     = [keys count];
        NSUInteger matching     = 0;
        NSUInteger histSize     = [[self.indexes objectForKey:name] count];
        NSMutableDictionary* dict   = [NSMutableDictionary dictionary];
        
        if (s) [dict setObject:s forKey:@"subject"];
        if (p) [dict setObject:p forKey:@"predicate"];
        if (o) [dict setObject:o forKey:@"object"];
        if (g) [dict setObject:g forKey:@"graph"];
        for (id k in keys) {
            id<GTWTerm> term    = [dict objectForKey:k];
            if (term) {
                matching++;
            } else {
                break;
            }
        }
//        NSLog(@"---->     index %@: %lu/%lu/%lu\n", name, matching, keyCount, histSize);
        float bestRatio = (float) bestMatching / (float) bestKeyCount;
        float newRatio  = (float) matching / (float) keyCount;
        if (bestName) {
            if ((newRatio > 0.0) && ((newRatio > bestRatio) || (newRatio == bestRatio && histSize > bestHistSize))) {
                bestName        = name;
                bestKeyCount    = keyCount;
                bestMatching    = matching;
                bestHistSize    = histSize;
            }
        } else if (newRatio > 0.0) {
            bestName        = name;
            bestKeyCount    = keyCount;
            bestMatching    = matching;
            bestHistSize    = histSize;
        }
    }
//    NSLog(@"----> best index: %@ (%lu/%lu/%lu)\n", bestName, bestMatching, bestKeyCount, bestHistSize);
    return bestName;
}

@end
