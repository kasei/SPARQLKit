#import <Foundation/Foundation.h>

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

@protocol GTWBlank <GTWTerm>
@end

@protocol GTWIRI <GTWTerm>
@end

@protocol GTWLiteral <GTWTerm>
- (NSString*) datatype;
- (NSString*) language;
- (BOOL) booleanValue;
@end

@protocol GTWVariable <GTWTerm>
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

@protocol GTWCostValue
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

@protocol GTWMutableTripleStore
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

@protocol GTWMutableQuadStore
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
- (NSComparisonResult)compare:(id<GTWCostValue>)ca with:(id<GTWCostValue>)cb;
@end

#pragma mark -

@protocol GTWTree
typedef id(^GTWTreeAccessorBlock)(id<GTWTree> node, NSUInteger level, BOOL* stop);

typedef NS_ENUM(NSInteger, GTWTreeTraversalOrder) {
    GTWTreePrefixOrder  = -1,
    GTWTreeInfixOrder   = 0,
    GTWTreePostfixOrder = 1
};

- (NSString*) treeTypeName;
- (id) applyBlock: (GTWTreeAccessorBlock)block inOrder: (GTWTreeTraversalOrder) order;
- (id) applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix;
- (id) annotationForKey: (NSString*) key;
- (void) computeScopeVariables;
@end

#pragma mark -

@protocol GTWQueryPlan
@end
@protocol GTWQueryAlgebra
@end

#pragma mark -

@protocol GTWCostModel
@property Class costValueClass;
@property Class costEvaluatorClass;
@property id<GTWCostEvaluator> costEvaluator;
- (id<GTWCostValue>) costForPlan: (id<GTWQueryPlan>) plan;
@end

#pragma mark -

@protocol GTWQueryDataset
- (NSArray*) defaultGraphs;
- (NSArray*) availableGraphsFromModel: (id<GTWModel>) model;
@end

@protocol GTWQueryPlanner
@property id<GTWLogger> logger;
- (id<GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWQueryDataset>) dataset optimize: (BOOL) opt;
//- (id<GTWQueryPlan>) queryPlanForAlgebra: (id<GTWQueryAlgebra>) algebra withDefaultDataSource: (id<GTWDataSource>) source usingCostModel: (id<GTWCostModel>) cm error:(NSError **)error;
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
- (id<GTWTree>) parserSPARQL: (NSString*) queryString withBaseURI: (NSString*) base;
@end

#pragma mark -

@protocol GTWRDFParser
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
@end

