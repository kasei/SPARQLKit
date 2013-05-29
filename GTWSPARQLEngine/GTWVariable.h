#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWVariable : NSObject<GTWVariable>

@property (retain, readwrite) NSString* value;

- (GTWVariable*) initWithValue: (NSString*) value;
- (GTWVariable*) initWithName: (NSString*) name;

@end
