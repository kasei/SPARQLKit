#import <Foundation/Foundation.h>

extern NSString * __strong const kUsedVariables;

@interface GTWTree : NSObject

typedef id(^GTWTreeAccessorBlock)(GTWTree* node, NSUInteger level, BOOL* stop);

typedef NS_ENUM(NSInteger, GTWTreeTraversalOrder) {
    GTWTreePrefixOrder  = -1,
    GTWTreeInfixOrder   = 0,
    GTWTreePostfixOrder = 1
};

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
    // Expression types
    EXPR_AND,
    EXPR_OR,
    EXPR_EQ,
    EXPR_NEQ,
    EXPR_LT,
    EXPR_GT,
    EXPR_LE,
    EXPR_GE,
    EXPR_UMINUS,
    EXPR_PLUS,
    EXPR_MINUS,
    EXPR_BANG,
    EXPR_LITERAL,
    EXPR_FUNCTION,
    EXPR_BOUND,
    EXPR_STR,
    EXPR_LANG,
    EXPR_DATATYPE,
    EXPR_ISURI,
    EXPR_ISBLANK,
    EXPR_ISLITERAL,
    EXPR_CAST,
//    EXPR_ORDER_COND_ASC,
//    EXPR_ORDER_COND_DESC,
    EXPR_LANGMATCHES,
    EXPR_REGEX,
//    EXPR_GROUP_COND_ASC,
//    EXPR_GROUP_COND_DESC,
    EXPR_COUNT,
//    EXPR_VARSTAR,
    EXPR_SAMETERM,
    EXPR_SUM,
    EXPR_AVG,
    EXPR_MIN,
    EXPR_MAX,
    EXPR_COALESCE,
    EXPR_IF,
    EXPR_URI,
    EXPR_IRI,
    EXPR_STRLANG,
    EXPR_STRDT,
    EXPR_BNODE,
    EXPR_GROUP_CONCAT,
    EXPR_SAMPLE,
    EXPR_IN,
    EXPR_NOT_IN,
    EXPR_ISNUMERIC,
    EXPR_YEAR,
    EXPR_MONTH,
    EXPR_DAY,
    EXPR_HOURS,
    EXPR_MINUTES,
    EXPR_SECONDS,
    EXPR_TIMEZONE,
    EXPR_CURRENT_DATETIME,
    EXPR_NOW,
    EXPR_FROM_UNIXTIME,
    EXPR_TO_UNIXTIME,
    EXPR_CONCAT,
    EXPR_STRLEN,
    EXPR_SUBSTR,
    EXPR_UCASE,
    EXPR_LCASE,
    EXPR_STRSTARTS,
    EXPR_STRENDS,
    EXPR_CONTAINS,
    EXPR_ENCODE_FOR_URI,
    EXPR_TZ,
    EXPR_RAND,
    EXPR_ABS,
    EXPR_ROUND,
    EXPR_CEIL,
    EXPR_FLOOR,
    EXPR_MD5,
    EXPR_SHA1,
    EXPR_SHA224,
    EXPR_SHA256,
    EXPR_SHA384,
    EXPR_SHA512,
    EXPR_STRBEFORE,
    EXPR_STRAFTER,
    EXPR_REPLACE,
    EXPR_UUID,
    EXPR_STRUUID,

    //
	TREE_RESULT
};

@property BOOL leaf;
@property GTWTreeType type;
@property NSArray* arguments;

// if node.value or node.ptr is set, the node is considered a leaf node, and node.arguments are ignored. node.value and node.ptr may be used to store any relevant semantic value(s) for the node
@property id value;
@property void* ptr;
@property NSUInteger location;
@property NSMutableDictionary* annotations;

- (GTWTree*) initLeafWithType: (GTWTreeType) type value: (id) value pointer: (void*) ptr;
- (GTWTree*) initWithType: (GTWTreeType) type arguments: (NSArray*) args;
- (GTWTree*) initWithType: (GTWTreeType) type value: (id) value arguments: (NSArray*) args;
//- (GTWTree*) initWithType: (GTWTreeType) type value: (id) value pointer: (void*) ptr arguments: (NSArray*) args;
- (NSString*) treeTypeName;
- (id) applyBlock: (GTWTreeAccessorBlock)block inOrder: (GTWTreeTraversalOrder) order;
- (id) applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix;
- (id) annotationForKey: (NSString*) key;
- (void) computeScopeVariables;

@end
