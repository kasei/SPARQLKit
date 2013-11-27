#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import "SPKSPARQLLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

@interface SPKSPARQLParser : NSObject<SPKSPARQLParser>

@property SPKSPARQLLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property id<GTWIRI> baseIRI;
//@property NSUInteger bnodeID;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property NSError* error;
@property NSMutableArray* seenAggregates;
@property NSMutableArray* aggregateSets;

- (SPKSPARQLParser*) initWithLexer: (SPKSPARQLLexer*) lex base: (GTWIRI*) base;

- (SPKSPARQLToken*) nextNonCommentToken;
- (id<SPKTree>) parseSPARQLQueryFromLexer: (SPKSPARQLLexer*) lexer withBaseURI: (NSString*) base checkEOF: (BOOL) checkEOF error: (NSError**) error;
- (id<SPKTree>) parseSPARQLUpdateFromLexer: (SPKSPARQLLexer*) lexer withBaseURI: (NSString*) base checkEOF: (BOOL) checkEOF error: (NSError**) error;

@end
