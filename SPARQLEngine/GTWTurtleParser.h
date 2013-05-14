#import <Foundation/Foundation.h>
#import "GTWTurtleLexer.h"
#import "GTWTriple.h"
#import "GTWBlank.h"
#import "GTWIRI.h"

typedef GTWBlank*(^IDGenerator)(NSString* name);

@interface GTWTurtleParser : NSObject<GTWRDFParser>

@property GTWTurtleLexer* lexer;
@property NSMutableArray* stack;
@property NSMutableDictionary* namespaces;
@property GTWIRI* base;
//@property NSUInteger bnodeID;
@property (nonatomic, copy) IDGenerator bnodeIDGenerator;
@property NSError* error;

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<Triple> t)) block error:(NSError **)error;
- (GTWTurtleParser*) initWithLexer: (GTWTurtleLexer*) lex base: (GTWIRI*) base;
- (GTWTriple*) nextObject;

- (id<GTWTerm>) currentSubject;
- (id<GTWTerm>) currentPredicate;
- (BOOL) haveSubjectPredicatePair;
- (BOOL) haveSubject;
- (void) pushNewSubject: (id<GTWTerm>) subj;
- (void) popSubject;
- (void) pushNewPredicate: (id<GTWTerm>) pred;
- (void) popPredicate;

@end
