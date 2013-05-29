#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWLiteral : NSObject<GTWLiteral>

@property (retain, readwrite) NSString* value;
@property (retain, readwrite) NSString* language;
@property (retain, readwrite) NSString* datatype;

+ (GTWLiteral*) integerLiteralWithValue: (NSInteger) value;
- (GTWLiteral*) initWithValue: (NSString*) value;
- (GTWLiteral*) initWithString: (NSString*) string;
- (GTWLiteral*) initWithString: (NSString*) string language: (NSString*) language;
- (GTWLiteral*) initWithString: (NSString*) string datatype: (NSString*) datatype;

- (BOOL) booleanValue;

@end
