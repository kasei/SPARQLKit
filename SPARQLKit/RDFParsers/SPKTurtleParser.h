#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import "SPKSPARQLLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

typedef NS_ENUM(NSInteger, SPKTurtleParserErrorCode) {
    SPKTurtleParserError,
	SPKTurtleUnexpectedTokenError,
    SPKTurtleUndeclaredPrefixError,
    SPKTurtleBadTokenError,
};


/**
 @description The SPKTurtleParser class provides a @c GTWRDFParser that parses Turtle data
              into a set of @c GTWTriple objects.
 */
@interface SPKTurtleParser : NSObject<GTWRDFParser>

@property SPKSPARQLLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property id<GTWIRI> baseIRI;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property (copy) void(^tripleBlock)(id<GTWTriple>);
@property BOOL verbose;

/**
 @param lex
 A @c SPKSPARQLLexer configured with the Turtle content to be parsed.
 @param base
 A @c GTWIRI specifying the base URI to be used during parsing.
 */
- (SPKTurtleParser*) initWithLexer: (SPKSPARQLLexer*) lex base: (GTWIRI*) base;
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;

@end
