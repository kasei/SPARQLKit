#import "GTWVariable.h"

@implementation GTWVariable

- (GTWVariable*) initWithValue: (NSString*) value {
    return [self initWithName:value];
}

- (GTWVariable*) initWithName: (NSString*) name {
    if (self = [self init]) {
        self.value  = name;
    }
    return self;
}

- (GTWTermType) termType {
    return GTWTermVariable;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"?%@", self.value];
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

@end
