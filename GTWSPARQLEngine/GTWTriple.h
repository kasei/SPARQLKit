#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWTriple : NSObject<GTWTriple>

@property id<GTWTerm> subject;
@property id<GTWTerm> predicate;
@property id<GTWTerm> object;

- (GTWTriple*) initWithSubject: (id<GTWTerm>) subj predicate: (id<GTWTerm>) pred object: (id<GTWTerm>) obj;
+ (GTWTriple*) tripleFromQuad: (id<GTWQuad>) q;

@end
