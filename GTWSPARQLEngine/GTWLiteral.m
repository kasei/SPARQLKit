#import "GTWLiteral.h"

@implementation GTWLiteral

+ (GTWLiteral*) integerLiteralWithValue: (NSInteger) value {
    return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%ld", value] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
}

- (GTWLiteral*) initWithValue: (NSString*) value {
    return [self initWithString:value];
}

- (GTWLiteral*) initWithString: (NSString*) string {
    if (self = [self init]) {
        self.value  = string;
    }
    return self;
}

- (GTWLiteral*) initWithString: (NSString*) string language: (NSString*) language {
    if (self = [self init]) {
        self.value      = string;
        self.language   = [language lowercaseString];
        self.datatype   = @"http://www.w3.org/1999/02/22-rdf-syntax-ns#langString";
    }
    return self;
}

- (GTWLiteral*) initWithString: (NSString*) string datatype: (NSString*) datatype {
    if (self = [self init]) {
        self.value      = string;
        self.datatype   = datatype;
    }
    return self;
}

- (GTWTermType) termType {
    return GTWTermLiteral;
}

- (NSString*) description {
    NSString* serialized    = [[[[self.value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    if (self.language) {
        return [NSString stringWithFormat:@"\"%@\"@%@", serialized, self.language];
    } else if (self.datatype) {
        return [NSString stringWithFormat:@"\"%@\"^^<%@>", serialized, self.datatype];
    } else {
        return [NSString stringWithFormat:@"\"%@\"", serialized];
    }
}

- (BOOL) isEqual:(id)object {
    if ([object conformsToProtocol:@protocol(GTWTerm)]){
        id<GTWTerm> term    = object;
        if (self.termType == term.termType) {
            if ([self.value isEqual:term.value]) {
                if ([self.language isEqual:term.language]) {
                    return YES;
                } else if (self.language || term.language) {
                    return NO;
                }
                if ([self.datatype isEqual:term.datatype]) {
                    return YES;
                } else if (self.datatype || term.datatype) {
                    return NO;
                }
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
        if (term.termType == GTWTermBlank || term.termType == GTWTermIRI)
            return NSOrderedDescending;
        return NSOrderedAscending;
    } else {
        NSComparisonResult cmp;
        if (!self.datatype && !term.datatype) {
            return [self.value compare:term.value];
        } else if (self.datatype && term.datatype) {
            cmp = [self.datatype compare:term.datatype];
            if (cmp != NSOrderedSame)
                return cmp;
            return [self.value compare:term.value];
        } else {
            if (!self.datatype) {
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }
    }
    return NSOrderedSame;
}

- (NSUInteger)hash {
    return [[self.value description] hash];
}

- (BOOL) booleanValue {
    if (!self.datatype)
        return NO;
    if (![self.datatype isEqualToString:@"http://www.w3.org/2001/XMLSchema#boolean"])
        return NO;
    return [self.value isEqualToString:@"true"];
}

@end
