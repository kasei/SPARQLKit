#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import <Foundation/NSKeyValueCoding.h>

@interface GTWQuad : NSObject<GTWQuad>

@property id<GTWTerm> subject;
@property id<GTWTerm> predicate;
@property id<GTWTerm> object;
@property id<GTWTerm> graph;

- (GTWQuad*) initWithSubject: (id<GTWTerm>) subj predicate: (id<GTWTerm>) pred object: (id<GTWTerm>) obj graph: (id<GTWTerm>) graph;
+ (GTWQuad*) quadFromTriple: (id<GTWTriple>) t withGraph: (id<GTWTerm>) graph;

@end
