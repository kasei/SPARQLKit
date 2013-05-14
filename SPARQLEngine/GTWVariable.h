#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"

@interface GTWVariable : NSObject<GTWTerm>

@property (retain, readwrite) NSString* value;

- (GTWVariable*) initWithValue: (NSString*) value;
- (GTWVariable*) initWithName: (NSString*) name;

@end
