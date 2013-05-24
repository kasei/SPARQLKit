#import <Foundation/Foundation.h>
#import "GTWTree.h"

@protocol GTWTerm <NSObject>
typedef NS_ENUM(NSInteger, GTWTermType) {
    GTWTermIRI,
    GTWTermBlank,
    GTWTermLiteral,
    GTWTermVariable,
};
- (id<GTWTerm>) initWithValue: (NSString*) value;
- (GTWTermType) termType;
- (NSString*) value;
- (NSComparisonResult)compare:(id<GTWTerm>)term;
@optional
- (NSString*) language;
- (NSString*) datatype;
@end

@protocol GTWTriple
@property id<GTWTerm> subject;
@property id<GTWTerm> predicate;
@property id<GTWTerm> object;
@end

@protocol GTWQuad <GTWTriple>
@property id<GTWTerm> subject;
@property id<GTWTerm> predicate;
@property id<GTWTerm> object;
@property id<GTWTerm> graph;
@end

#pragma mark -

@protocol GTWLogger
- (void) logData: (id) data forKey: (NSString*) key;
@end

#pragma mark -

@protocol CostValue
//opaque
@end

#pragma mark -

@protocol GTWDataSource
@property id<GTWLogger> logger;
@end

#pragma mark -
#pragma mark Triple Store Protocols

@protocol GTWTripleStore
@property id<GTWLogger> logger;
- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error;
- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
@optional
- (NSEnumerator*) tripleEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error;
- (NSString*) etagForTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error;
- (NSUInteger) countTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error;
@end

@protocol MutableTripleStore
- (BOOL) addTriple: (id<GTWTriple>) t error:(NSError **)error;
- (BOOL) removeTriple: (id<GTWTriple>) t error:(NSError **)error;
@end

#pragma mark -
#pragma mark Quad Store Protocols

@protocol GTWQuadStore
@property id<GTWLogger> logger;
- (NSArray*) getGraphsWithOutError:(NSError **)error;
- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error;
- (NSArray*) getQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error;
@optional
- (NSEnumerator*) quadEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
- (BOOL) addIndexType: (NSString*) type value: (NSArray*) positions synchronous: (BOOL) sync error: (NSError**) error;
- (NSString*) etagForQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
- (NSUInteger) countGraphsWithOutError:(NSError **)error;
- (NSUInteger) countQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
@end

@protocol MutableQuadStore
- (BOOL) addQuad: (id<GTWQuad>) q error:(NSError **)error;
- (BOOL) removeQuad: (id<GTWQuad>) q error:(NSError **)error;
@end


#pragma mark -

@protocol GTWModel
- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error;
- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error;
- (BOOL) enumerateBindingsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(NSDictionary* q)) block error:(NSError **)error;
@end


#pragma mark -

@protocol GTWCostEvaluator
@property id<GTWLogger> logger;
- (NSComparisonResult)compare:(id<CostValue>)ca with:(id<CostValue>)cb;
@end

#pragma mark -

@protocol QueryPlan
@end
@protocol QueryAlgebra
@end

#pragma mark -

@protocol GTWCostModel
@property Class costValueClass;
@property Class costEvaluatorClass;
@property id<GTWCostEvaluator> costEvaluator;
- (id<CostValue>) costForPlan: (id<QueryPlan>) plan;
@end

#pragma mark -

@protocol QueryPlanner
@property id<GTWLogger> logger;
- (id<QueryPlan>) queryPlanForAlgebra: (id<QueryAlgebra>) algebra withDefaultDataSource: (id<GTWDataSource>) source usingCostModel: (id<GTWCostModel>) cm error:(NSError **)error;
@end


#pragma mark -

@protocol GTWTransactionLog
@property id<GTWLogger> logger;
- (void) beginLogEntry;
- (void) endLogEntry;
- (void) abortLogEntry;
- (void) createGraph;
- (void) dropGraph;
- (void) addQuadWithSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
- (void) removeQuadWithSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error;
@end

#pragma mark -

@protocol GTWSPARQLParser
- (GTWTree*) parserSPARQL: (NSString*) queryString withBaseURI: (NSString*) base;
@end

#pragma mark -

@protocol GTWRDFParser
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
@end

