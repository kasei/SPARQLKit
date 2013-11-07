#import "GTWMemoryQuadStore.h"
#import "GTWTurtleParser.h"
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWVariable.h>

@implementation GTWMemoryQuadStore

+ (unsigned)interfaceVersion {
    return 0;
}

+ (NSString*) usage {
    return @"{ \"sources\": [ { \"file\": <path/file>, \"syntax\": \"turtle\" } ] }";
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWQuadStore), @protocol(GTWMutableQuadStore), nil];
}

- (void) _addQuad: (id<GTWQuad>) q toIndex: (NSMutableDictionary*) idx withPositions: (NSArray*) positions {
    // caller is responsible for using @synchronized(idx)
    NSObject<GTWQuad>* qq  = (NSObject<GTWQuad>*) q;
    //    NSLog(@"indexing quad: %@\n", q);
    NSMutableArray* keyarray    = [NSMutableArray array];
    for (NSString* p in positions) {
        NSObject<GTWTerm>* t   = [qq valueForKey: p];
        [keyarray addObject:t];
    }
    
    NSString* indexKey  = [keyarray componentsJoinedByString:@" "];
    //        NSLog(@"indexing quad: %@ => %@\n", indexKey, q);
    
    NSMutableSet* set;
    set = idx[indexKey];
    if (!set) {
        set = [NSMutableSet set];
        idx[indexKey] = set;
    }
    [set addObject:q];
}

- (void) _removeQuad: (id<GTWQuad>) q fromIndex: (NSMutableDictionary*) idx withPositions: (NSArray*) positions {
    // caller is responsible for using @synchronized(idx)
    NSObject<GTWQuad>* qq  = (NSObject<GTWQuad>*) q;
    //    NSLog(@"indexing quad: %@\n", q);
    NSMutableArray* keyarray    = [NSMutableArray array];
    for (NSString* p in positions) {
        NSObject<GTWTerm>* t   = [qq valueForKey: p];
        [keyarray addObject:t];
    }
    
    NSString* indexKey  = [keyarray componentsJoinedByString:@" "];
    //        NSLog(@"indexing quad: %@ => %@\n", indexKey, q);
    
    NSMutableSet* set;
    set = idx[indexKey];
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

- (instancetype) initWithDictionary: (NSDictionary*) dictionary {
    if (self = [self init]) {
        NSString* base      = dictionary[@"base_uri"];
        if (!base)
            base    = @"http://base.example.org/";
        GTWIRI* baseuri     = [[GTWIRI alloc] initWithValue:base];
        NSArray* sources    = dictionary[@"sources"];
        if (sources) {
            for (NSDictionary* source in sources) {
                NSString* file      = source[@"file"];
                NSString* syntax    = source[@"syntax"];
                NSString* graphName = source[@"graph"];
                if (file && syntax) {
                    if ([syntax isEqual: @"turtle"]) {
                        GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:(graphName ? graphName : base)];
                        NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:file];
                        GTWTurtleLexer* l   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
                        GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
                        if (p) {
                            //    NSLog(@"parser: %p\n", p);
                            [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
                                GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
                                [self addQuad:q error:nil];
                            } error:nil];
                            //        NSLog(@"-- ");
                        } else {
                            NSLog(@"Could not construct parser");
                        }
                    } else {
                        NSLog(@"Don't know how to parse file of type %@", syntax);
                        return nil;
                    }
                }
            }
        }
    }
    return self;
}

- (BOOL) addIndexType: (NSString*) type value: (NSArray*) positions synchronous: (BOOL) sync error: (NSError**) error {
    if ([type isEqualToString:@"term"]) {
        for (NSString* p in positions) {
            if (!([p isEqualToString:@"subject"] || [p isEqualToString:@"predicate"] || [p isEqualToString:@"object"] || [p isEqualToString:@"graph"])) {
                NSString* desc  = [NSString stringWithFormat:@"Cannot add index for unknown term position '%@'", p];
//                NSLog(@"%@", desc);
                if (error) {
                    *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.memory" code:1 userInfo:@{@"description": desc}];
                }
//                [self.logger logData:@"" forKey:@""];
                return NO;
            }
        }
        NSString* name  = [positions componentsJoinedByString:@", "];
//        NSLog(@"Adding index on term positions: <%@>\n", name);
        
        __block BOOL ok = YES;
        __block NSMutableDictionary* idx;
        __block NSError* _error;
        dispatch_barrier_sync(self.queue, ^{
    //        NSLog(@"async dispatch setting up index");
            // add index to store
            idx    = (self.indexes)[name];
            if (!idx) {
                idx    = [NSMutableDictionary dictionary];
                (self.indexKeys)[name] = positions;
                (self.indexes)[name] = idx;
            } else {
                NSString* desc  = [NSString stringWithFormat:@"Index on terms <%@> already exists", name];
                _error  = [NSError errorWithDomain:@"us.kasei.sparql.store.memory" code:1 userInfo:@{@"description": desc}];
//                NSLog(@"%@", desc);
                ok  = NO;
                return;
            }
            
            // index existing quads
            if (!sync) {
                NSEnumerator* e = [self.quads objectEnumerator];
                dispatch_async(self.queue, ^{
                    @synchronized(idx) {
                        for (NSObject<GTWQuad>* q in e) {
                            [self _addQuad:q toIndex:idx withPositions:positions];
                        }
                    }
                });
            }
        });
        if (!ok) {
            if (error) {
                *error  = _error;
            }
            return NO;
        }
        
        if (sync) {
            @synchronized(idx) {
                for (NSObject<GTWQuad>* q in self.quads) {
                    [self _addQuad:q toIndex:idx withPositions:positions];
                }
            }
        }
    } else {
        NSString* desc  = [NSString stringWithFormat:@"Attempt to add unknown index type %@", type];
        if (error) {
            *error  = [NSError errorWithDomain:@"us.kasei.sparql.store.memory" code:1 userInfo:@{@"description": desc}];
        }
        return NO;
    }
    return YES;
}

- (NSArray*) getGraphsWithOutError:(NSError **)error {
    NSMutableArray* graphs  = [NSMutableArray array];
    NSMutableSet* seen  = [NSMutableSet set];
    for (id<GTWQuad> q in self.quads) {
        if (![seen containsObject:q.graph]) {
            [graphs addObject:q.graph];
            [seen addObject:q.graph];
        }
    }
    return graphs;
}

- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
    NSMutableSet* seen  = [NSMutableSet set];
    [self.quads enumerateObjectsUsingBlock:^(id<GTWQuad> q, BOOL* stop){
        if (![seen containsObject:q.graph]) {
            block(q.graph);
            [seen addObject:q.graph];
        }
    }];
    return YES;
}

- (NSArray*) getQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error {
    NSMutableArray* quads    = [NSMutableArray array];
    [self enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q){
        [quads addObject:q];
    } error:error];
    return quads;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
    [self.quads enumerateObjectsUsingBlock:^(id<GTWQuad> q, BOOL* stop){
//        NSLog(@"checking quad: %@", q);
        if (s && ![s isKindOfClass:[GTWVariable class]]) {
            if (![s isEqual:q.subject]) {
//                NSLog(@"subject doesn't match %@", s);
                return;
            }
        }
        if (p && ![p isKindOfClass:[GTWVariable class]]) {
            if (![p isEqual:q.predicate]) {
//                NSLog(@"predicate doesn't match %@", p);
                return;
            }
        }
        if (o && ![o isKindOfClass:[GTWVariable class]]) {
            if (![o isEqual:q.object]) {
//                NSLog(@"object doesn't match %@", o);
                return;
            }
        }
        if (g && ![g isKindOfClass:[GTWVariable class]]) {
            if (![g isEqual:q.graph]) {
//                NSLog(@"graph doesn't match %@", g);
                return;
            }
        }
//        NSLog(@"enumerating matching quad: %@", q);
        block(q);
    }];
    return YES;
}

- (NSEnumerator*) quadEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error {
    NSArray* quads  = [self getQuadsMatchingSubject:s predicate:p object:o graph:g error:error];
    return [quads objectEnumerator];
}

- (BOOL) addQuad: (id<GTWQuad>) q error:(NSError **)error {
//    NSLog(@"+ %8lu %@", [self.quads count], q);
    [self.quads addObject:q];
    dispatch_barrier_async(self.queue, ^{
        for (NSString* name in self.indexes) {
            NSMutableDictionary* idx    = (self.indexes)[name];
            dispatch_async(self.queue, ^{
                NSArray* positions  = (self.indexKeys)[name];
                @synchronized(idx) {
                    [self _addQuad:q toIndex:idx withPositions:positions];
                }
            });
        }
    });
    
    return YES;
}

- (BOOL) removeQuad: (id<GTWQuad>) q error:(NSError **)error {
    [self.quads removeObject:q];
    dispatch_barrier_async(self.queue, ^{
        for (NSString* name in self.indexes) {
            NSMutableDictionary* idx    = (self.indexes)[name];
            dispatch_async(self.queue, ^{
                NSArray* positions  = (self.indexKeys)[name];
                @synchronized(idx) {
                    [self _removeQuad:q fromIndex:idx withPositions:positions];
                }
            });
        }
    });
    
    return YES;
}

- (void) dealloc {
    dispatch_queue_t queue  = self.queue;
    self.queue  = NULL;
    dispatch_suspend(queue);
    dispatch_resume(queue);
}

- (NSString*) description {
    NSMutableString* d  = [NSMutableString string];
    [d appendFormat:@"Quadstore with %lu statements\n", [self.quads count]];
    [d appendFormat:@"%lu Indexes:\n", [self.indexes count]];
    for (id i in self.indexes) {
        NSSet* set  = (self.indexes)[i];
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
        NSArray* keys           = (self.indexKeys)[name];
        NSUInteger keyCount     = [keys count];
        NSUInteger matching     = 0;
        NSUInteger histSize     = [(self.indexes)[name] count];
        NSMutableDictionary* dict   = [NSMutableDictionary dictionary];
        
        if (s) dict[@"subject"] = s;
        if (p) dict[@"predicate"] = p;
        if (o) dict[@"object"] = o;
        if (g) dict[@"graph"] = g;
        for (id k in keys) {
            id<GTWTerm> term    = dict[k];
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
