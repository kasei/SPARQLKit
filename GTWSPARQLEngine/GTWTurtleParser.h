#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import "GTWTurtleLexer.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWIRI.h>

typedef GTWBlank*(^IDGenerator)(NSString* name);

@interface GTWTurtleParser : NSObject<GTWRDFParser>

@property GTWTurtleLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property GTWIRI* base;
//@property NSUInteger bnodeID;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property NSError* error;

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
- (GTWTurtleParser*) initWithLexer: (GTWTurtleLexer*) lex base: (GTWIRI*) base;
- (id<GTWTriple>) nextObject;

- (id<GTWTerm>) currentSubject;
- (id<GTWTerm>) currentPredicate;
- (BOOL) haveSubjectPredicatePair;
- (BOOL) haveSubject;
- (void) pushNewSubject: (id<GTWTerm>) subj;
- (void) popSubject;
- (void) pushNewPredicate: (id<GTWTerm>) pred;
- (void) popPredicate;

@end
