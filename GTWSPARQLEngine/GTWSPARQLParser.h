#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWSPARQLLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

@interface GTWSPARQLParser : NSObject<GTWSPARQLParser>

@property GTWSPARQLLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property id<GTWIRI> baseIRI;
//@property NSUInteger bnodeID;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property NSError* error;
@property NSMutableArray* seenAggregates;
@property NSMutableArray* aggregateSets;

- (GTWSPARQLParser*) initWithLexer: (GTWSPARQLLexer*) lex base: (GTWIRI*) base;

@end
