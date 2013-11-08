#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWSPARQLLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

@interface GTWTurtleParser : NSObject<GTWRDFParser>

@property GTWSPARQLLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property GTWIRI* baseIRI;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property (copy) void(^tripleBlock)(id<GTWTriple>);
@property BOOL verbose;

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
- (GTWTurtleParser*) initWithLexer: (GTWSPARQLLexer*) lex base: (GTWIRI*) base;

@end
