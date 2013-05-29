#import "GTWQuad.h"

@implementation GTWQuad

+ (GTWQuad*) quadFromTriple: (id<GTWTriple>) t withGraph: (id<GTWTerm>) graph {
    GTWQuad* q  = [[self alloc] initWithSubject:t.subject predicate:t.predicate object:t.object graph:graph];
    return q;
}

- (GTWQuad*) initWithSubject: (id<GTWTerm>) subj predicate: (id<GTWTerm>) pred object: (id<GTWTerm>) obj graph:(id<GTWTerm>)graph {
    if (self = [self init]) {
        self.subject    = subj;
        self.predicate  = pred;
        self.object     = obj;
        self.graph      = graph;
    }
    return self;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"%@ %@ %@ %@ .", self.subject, self.predicate, self.object, self.graph];
}

- (BOOL) isEqual:(id)object {
    if ([object conformsToProtocol:@protocol(GTWQuad)]){
        id<GTWQuad> t = object;
        if (![self.subject isEqual:t.subject])
            return NO;
        if (![self.predicate isEqual:t.predicate])
            return NO;
        if (![self.object isEqual:t.object])
            return NO;
        if (![self.graph isEqual:t.graph])
            return NO;
        return YES;
    }
    return NO;
}

- (NSUInteger)hash {
    return [[self description] hash];
}

@end
