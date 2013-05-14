#import "SPARQLEngine.h"

@interface GTWIRI : NSObject<GTWTerm>

@property (retain, readwrite) NSString* value;

- (GTWIRI*) initWithValue: (NSString*) value;
- (GTWIRI*) initWithIRI: (NSString*) iri;
- (GTWIRI*) initWithIRI: (NSString*) iri base: (GTWIRI*) base;

@end
