#import "GTWTriple.h"

@implementation GTWTriple

+ (GTWTriple*) tripleFromQuad: (id<GTWQuad>) q {
    return [[GTWTriple alloc] initWithSubject:q.subject predicate:q.predicate object:q.object];
}

- (GTWTriple*) initWithSubject: (id<GTWTerm>) subj predicate: (id<GTWTerm>) pred object: (id<GTWTerm>) obj {
    if (self = [self init]) {
        if (!subj || subj == (id<GTWTerm>)[NSNull null]) {
            NSLog(@"triple with nil subject");
            return nil;
        }
        self.subject    = subj;
        self.predicate  = pred;
        self.object     = obj;
    }
    return self;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"%@ %@ %@ .", self.subject, self.predicate, self.object];
}

- (BOOL) isEqual:(id)object {
    if ([object conformsToProtocol:@protocol(GTWTriple)]){
        id<GTWTriple> t = object;
        if (![self.subject isEqual:t.subject])
            return NO;
        if (![self.predicate isEqual:t.predicate])
            return NO;
        if (![self.object isEqual:t.object])
            return NO;
        return YES;
    }
    return NO;
}

- (NSUInteger)hash {
    return [[self description] hash];
}

@end
