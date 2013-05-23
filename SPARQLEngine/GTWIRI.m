#import "GTWIRI.h"

@implementation GTWIRI

- (GTWIRI*) initWithValue: (NSString*) value {
    return [self initWithIRI:value];
}

- (GTWIRI*) initWithIRI: (NSString*) iri {
    if (self = [self init]) {
        self.value  = iri;
    }
    return self;
}

- (GTWIRI*) initWithIRI: (NSString*) iri base: (GTWIRI*) base {
    if (self = [self init]) {
        NSURL* baseurl  = [[NSURL alloc] initWithString:[base value]];
        NSURL* url  = [[NSURL alloc] initWithString:iri relativeToURL:baseurl];
        self.value  = [url absoluteString];
        if (!self.value) {
            NSLog(@"failed to create IRI: <%@> with base %@", iri, base);
            return nil;
        }
    }
    return self;
}

- (GTWTermType) termType {
    return GTWTermIRI;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<%@>", self.value];
}

- (BOOL) isEqual:(id)object {
    if ([object conformsToProtocol:@protocol(GTWTerm)]){
        id<GTWTerm> term    = object;
        if (self.termType == term.termType) {
            if ([self.value isEqual:term.value]) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSComparisonResult)compare:(id<GTWTerm>)term {
    if (!term)
        return NSOrderedDescending;
    if (self.termType != term.termType) {
        if (term.termType == GTWTermBlank)
            return NSOrderedDescending;
        return NSOrderedAscending;
    } else {
        return [self.value compare:term.value];
    }
}

- (NSUInteger)hash {
    return [self.value hash];
}

@end
