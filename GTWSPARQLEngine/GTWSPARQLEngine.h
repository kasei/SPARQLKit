#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

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

@protocol GTWTree<NSObject>
typedef id(^GTWTreeAccessorBlock)(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL* stop);
typedef NSString* GTWTreeType;

typedef NS_ENUM(NSInteger, GTWTreeTraversalOrder) {
    GTWTreePrefixOrder  = -1,
    GTWTreeInfixOrder   = 0,
    GTWTreePostfixOrder = 1
};

@property BOOL leaf;
@property GTWTreeType type;
@property NSArray* arguments;
@property id value;
@property void* ptr;
@property NSMutableDictionary* annotations;

- (NSString*) treeTypeName;
- (id) applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix;
- (id) annotationForKey: (NSString*) key;
- (void) computeScopeVariables;
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
@property (readwrite) NSString* baseURI;
- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error;
@end


#pragma mark -

@protocol GTWQueryEngine
- (NSEnumerator*) evaluateQueryPlan: (id<GTWQueryPlan>) plan withModel: (id<GTWModel>) model;
@end

#pragma mark -

@protocol GTWSPARQLResultsSerializer
- (NSData*) serializeResults: (NSEnumerator*) results withVariables: (NSSet*) variables;
@end

