#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWSPARQLLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

/**
 @description The GTWTurtleParser class provides a @c GTWRDFParser that parses Turtle data
              into a set of @c GTWTriple objects.
 */
@interface GTWTurtleParser : NSObject<GTWRDFParser>

@property GTWSPARQLLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property id<GTWIRI> baseIRI;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property (copy) void(^tripleBlock)(id<GTWTriple>);
@property BOOL verbose;

/**
 @param lex
 A @c GTWSPARQLLexer configured with the Turtle content to be parsed.
 @param base
 A @c GTWIRI specifying the base URI to be used during parsing.
 */
- (GTWTurtleParser*) initWithLexer: (GTWSPARQLLexer*) lex base: (GTWIRI*) base;
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;

@end
