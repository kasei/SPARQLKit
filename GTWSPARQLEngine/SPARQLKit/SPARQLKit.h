#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWBlank.h>

#define SPARQLKIT_NAME  @"SPARQLKit"
#define SPARQLKIT_VERSION @"0.0.1"

@protocol GTWLogger
- (void) logData: (id) data forKey: (NSString*) key;
@end

#pragma mark -

@protocol GTWCostValue
//opaque
@end

#pragma mark -
#pragma mark Triple Store Protocols

@protocol GTWCostEvaluator
@property id<GTWLogger> logger;
- (NSComparisonResult)compare:(id<GTWCostValue>)ca with:(id<GTWCostValue>)cb;
@end

#pragma mark -

@protocol GTWTree<NSObject,GTWRewriteable>
typedef id(^GTWTreeAccessorBlock)(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL* stop);
typedef NSString* GTWTreeType;
@property BOOL leaf;
@property GTWTreeType type;
@property NSArray* arguments;
@property id<GTWTree> treeValue;
@property id value;
@property void* ptr;
@property NSMutableDictionary* annotations;

/**
 @param map
 A dictionary mapping 
 @param variables
 A set of variable names that should be used during serialization.
 @return The serialization of the enumerated SPARQL results.
 */
- (id) copyReplacingValues: (NSDictionary*) map;
- (NSString*) treeTypeName;
- (NSSet*) nonAggregatedVariables;
- (NSSet*) referencedBlanks;
- (NSSet*) inScopeVariables;
- (NSSet*) inScopeNodesOfClass: (NSSet*) types;
- (NSString*) conciseDescription;
- (NSString*) longDescription;
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

@protocol GTWQueryPlanner
@property id<GTWLogger> logger;
- (id<GTWTree,GTWQueryPlan>) queryPlanForAlgebra: (id<GTWTree>) algebra usingDataset: (id<GTWDataset>) dataset withModel: (id<GTWModel>) model options: (NSDictionary*) options;
@optional
- (id<GTWTree,GTWQueryPlan>) joinPlanForPlans: (id<GTWTree>) lhs and: (id<GTWTree>) rhs;
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

@protocol SPKSPARQLParser
- (id<GTWTree>) parseSPARQL: (NSString*) queryString withBaseURI: (NSString*) base error: (NSError**) error;
@end

#pragma mark -

@protocol GTWRDFParser
@property (readwrite) id<GTWIRI> baseURI;
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
@end


#pragma mark -

@protocol GTWQueryEngine
- (NSEnumerator*) evaluateQueryPlan: (id<GTWQueryPlan>) plan withModel: (id<GTWModel>) model;
@end



typedef GTWBlank*(^IDGenerator)(NSString* name);

