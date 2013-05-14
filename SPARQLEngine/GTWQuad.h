#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#import <Foundation/NSKeyValueCoding.h>

@interface GTWQuad : NSObject<Quad>

@property id<GTWTerm> subject;
@property id<GTWTerm> predicate;
@property id<GTWTerm> object;
@property id<GTWTerm> graph;

- (GTWQuad*) initWithSubject: (id<GTWTerm>) subj predicate: (id<GTWTerm>) pred object: (id<GTWTerm>) obj graph: (id<GTWTerm>) graph;
+ (GTWQuad*) quadFromTriple: (id<Triple>) t withGraph: (id<GTWTerm>) graph;

@end
