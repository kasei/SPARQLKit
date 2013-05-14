#import <Foundation/Foundation.h>

@interface GTWTree : NSObject

typedef NS_ENUM(NSInteger, GTWTreeType) {
	// plan tree nodes:
    PLAN_EMPTY,                 // Empty()
	PLAN_SCAN,					// Scan( index, quad, restrictions )
	PLAN_BKAJOIN,				// BKAJoin( P, Q )
	PLAN_HASHJOIN,				// HashJoin( P, Q, joinVars )
	PLAN_NLJOIN,				// NLJoin( P, Q )
	PLAN_NLLEFTJOIN,			// NLLeftJoin( P, Q )
	PLAN_PROJECT,				// Project( P, vars )
	PLAN_FILTER,				// Filter( expr, P )
	PLAN_UNION,					// Union( P, Q )
	PLAN_EXTEND,				// Extend( P, var, expr )
	PLAN_MINUS,					// Minus( P, Q )
	PLAN_ORDER,					// Order( P, cond )
	PLAN_DISTINCT,				// Distinct( P )
	PLAN_SLICE,					// Slice( P, start, length )
	PLAN_RESULTSET,				// ResultSet( length, results )
	PLAN_JOIN_IDENTITY,			// JoinIdentity()
	PLAN_FEDSTUB,				// FedStub( P )
	PLAN_DESCRIBE,
	// algebra tree nodes:
	ALGEBRA_BGP,				// BGP(t1, t2, ...)
	ALGEBRA_JOIN,				// Join( P, Q )
	ALGEBRA_LEFTJOIN,			// LeftJoin( P, Q, expr )
	ALGEBRA_FILTER,				// Filter( expr, P )
	ALGEBRA_UNION,				// Union( P, Q )
	ALGEBRA_GRAPH,				// Graph( IRI|var, P )
	ALGEBRA_EXTEND,				// Extend( P, var, expr )
	ALGEBRA_MINUS,				// Minus( P, Q )
	ALGEBRA_ZEROLENGTHPATH,		// ZeroLengthPath( term|var, path, term|var )
	ALGEBRA_ZEROORMOREPATH,		// ZeroOrMorePath( term|var, path, term|var )
	ALGEBRA_ONEORMOREPATH,		// OneOrMorePath( term|var, path, term|var )
	ALGEBRA_NEGATEDPROPERTYSET,	// NegatedPropertySet( term|var, IRIset, term|var )
	ALGEBRA_GROUP,				// Group( exprlist, P )
	ALGEBRA_AGGREGATION,		// Aggregation( args, aggregate, scalarvals, G )
	ALGEBRA_AGGREGATEJOIN,		// AggregateJoin( aggregates )
	ALGEBRA_TOLIST,				// ToList( P )
	ALGEBRA_ORDERBY,			// OrderBy( M, cond )
	ALGEBRA_PROJECT,			// Project( M, vars )
	ALGEBRA_DISTINCT,			// Distinct( M )
	ALGEBRA_REDUCED,			// Reduced( M )
	ALGEBRA_SLICE,				// Slice( M, start, length )
	ALGEBRA_TOMULTISET,			// ToMultiSet( M )
	ALGEBRA_DESCRIBE,			//
	// these are the algebra types that "leave" the algebra/plan value space
	TREE_SET,					// GTWTree* arguments[size]
	TREE_LIST,					// GTWTree* arguments[size]
	TREE_DICTIONARY,			// GTWTree* arguments[size] of CSTRING nodes
	TREE_AGGREGATE,				// same as STRING
	TREE_TRIPLE,				// id<Triple> ptr
	TREE_QUAD,					// id<Quad> ptr
	TREE_EXPRESSION,			// expr* ptr
	TREE_NODE,					// id<GTWTerm> ptr
	TREE_PATH,					// @@ ?
	TREE_ORDER_CONDITION,		// @@ ?
	TREE_SOLUTION_SEQUENCE,		// solutionset* ptr
	TREE_STRING,				// char* ptr
	TREE_RESULT
};

@property GTWTreeType type;
@property NSArray* arguments;
@property void* ptr;
@property NSUInteger location;
@property void* annotation;

- (GTWTree*) initWithType: (GTWTreeType) type pointer: (void*) ptr arguments: (NSArray*) args;
- (NSString*) treeTypeName;

@end
