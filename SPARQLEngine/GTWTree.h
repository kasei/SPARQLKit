#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"

extern NSString * __strong const kUsedVariables;
extern NSString * __strong const kProjectVariables;

@interface GTWTree : NSObject<GTWTree>

typedef NSString* GTWTreeType;

// ---------------------------------------------------------

// plan tree nodes:
extern GTWTreeType __strong const kPlanEmpty;                 // Empty()
extern GTWTreeType __strong const kPlanScan;					// Scan( index, quad, restrictions )
extern GTWTreeType __strong const kPlanBKAjoin;				// BKAJoin( P, Q )
extern GTWTreeType __strong const kPlanHashJoin;				// HashJoin( P, Q, joinVars )
extern GTWTreeType __strong const kPlanNLjoin;				// NLJoin( P, Q )
extern GTWTreeType __strong const kPlanNLLeftJoin;			// NLLeftJoin( P, Q )
extern GTWTreeType __strong const kPlanProject;				// Project( P, vars )
extern GTWTreeType __strong const kPlanFilter;				// Filter( expr, P )
extern GTWTreeType __strong const kPlanUnion;					// Union( P, Q )
extern GTWTreeType __strong const kPlanExtend;				// Extend( P, var, expr )
extern GTWTreeType __strong const kPlanMinus;					// Minus( P, Q )
extern GTWTreeType __strong const kPlanOrder;					// Order( P, cond )
extern GTWTreeType __strong const kPlanDistinct;				// Distinct( P )
extern GTWTreeType __strong const kPlanSlice;					// Slice( P, start, length )
extern GTWTreeType __strong const kPlanResultSet;				// ResultSet( length, results )
extern GTWTreeType __strong const kPlanJoinIdentity;			// JoinIdentity()
extern GTWTreeType __strong const kPlanFedStub;				// FedStub( P )
extern GTWTreeType __strong const kPlanDescribe;
// algebra tree nodes:
extern GTWTreeType __strong const kAlgebraBGP;				// BGP(t1, t2, ...)
extern GTWTreeType __strong const kAlgebraJoin;				// Join( P, Q )
extern GTWTreeType __strong const kAlgebraLeftJoin;			// LeftJoin( P, Q, expr )
extern GTWTreeType __strong const kAlgebraFilter;				// Filter( expr, P )
extern GTWTreeType __strong const kAlgebraUnion;				// Union( P, Q )
extern GTWTreeType __strong const kAlgebraGraph;				// Graph( IRI|var, P )
extern GTWTreeType __strong const kAlgebraExtend;				// Extend( P, var, expr )
extern GTWTreeType __strong const kAlgebraMinus;				// Minus( P, Q )
extern GTWTreeType __strong const kAlgebraZeroLengthPath;		// ZeroLengthPath( term|var, path, term|var )
extern GTWTreeType __strong const kAlgebraZeroOrMorePath;		// ZeroOrMorePath( term|var, path, term|var )
extern GTWTreeType __strong const kAlgebraOneOrMorePath;		// OneOrMorePath( term|var, path, term|var )
extern GTWTreeType __strong const kAlgebraNegatedPropertySet;	// NegatedPropertySet( term|var, IRIset, term|var )
extern GTWTreeType __strong const kAlgebraGroup;				// Group( exprlist, P )
extern GTWTreeType __strong const kAlgebraAggregation;		// Aggregation( args, aggregate, scalarvals, G )
extern GTWTreeType __strong const kAlgebraAggregateJoin;		// AggregateJoin( aggregates )
extern GTWTreeType __strong const kAlgebraToList;				// ToList( P )
extern GTWTreeType __strong const kAlgebraOrderBy;			// OrderBy( M, cond )
extern GTWTreeType __strong const kAlgebraProject;			// Project( M, vars )
extern GTWTreeType __strong const kAlgebraDistinct;			// Distinct( M )
extern GTWTreeType __strong const kAlgebraReduced;			// Reduced( M )
extern GTWTreeType __strong const kAlgebraSlice;				// Slice( M, start, length )
extern GTWTreeType __strong const kAlgebraToMultiset;			// ToMultiSet( M )
extern GTWTreeType __strong const kAlgebraDescribe;			//
// these are the algebra types that "leave" the algebra/plan value space
extern GTWTreeType __strong const kTreeSet;					// GTWTree* arguments[size]
extern GTWTreeType __strong const kTreeList;					// GTWTree* arguments[size]
extern GTWTreeType __strong const kTreeDictionary;			// GTWTree* arguments[size] of CSTRING nodes
extern GTWTreeType __strong const kTreeAggregate;				// same as STRING
extern GTWTreeType __strong const kTreeTriple;				// id<Triple> ptr
extern GTWTreeType __strong const kTreeQuad;					// id<Quad> ptr
extern GTWTreeType __strong const kTreeExpression;			// expr* ptr
extern GTWTreeType __strong const kTreeNode;					// id<GTWTerm> ptr
extern GTWTreeType __strong const kTreePath;					// @@ ?
extern GTWTreeType __strong const kTreeOrderCondition;		// @@ ?
extern GTWTreeType __strong const kTreeSolutionSequence;		// solutionset* ptr
extern GTWTreeType __strong const kTreeString;				// char* ptr
// Expression types
extern GTWTreeType __strong const kExprAnd;
extern GTWTreeType __strong const kExprOr;
extern GTWTreeType __strong const kExprEq;
extern GTWTreeType __strong const kExprNeq;
extern GTWTreeType __strong const kExprLt;
extern GTWTreeType __strong const kExprGt;
extern GTWTreeType __strong const kExprLe;
extern GTWTreeType __strong const kExprGe;
extern GTWTreeType __strong const kExprUMinus;
extern GTWTreeType __strong const kExprPlus;
extern GTWTreeType __strong const kExprMinus;
extern GTWTreeType __strong const kExprBang;
extern GTWTreeType __strong const kExprLiteral;
extern GTWTreeType __strong const kExprFunction;
extern GTWTreeType __strong const kExprBound;
extern GTWTreeType __strong const kExprStr;
extern GTWTreeType __strong const kExprLang;
extern GTWTreeType __strong const kExprDatatype;
extern GTWTreeType __strong const kExprIsURI;
extern GTWTreeType __strong const kExprIsBlank;
extern GTWTreeType __strong const kExprIsLiteral;
extern GTWTreeType __strong const kExprCast;
//    EXPR_ORDER_COND_ASC,
//    EXPR_ORDER_COND_DESC,
extern GTWTreeType __strong const kExprLangMatches;
extern GTWTreeType __strong const kExprRegex;
//    EXPR_GROUP_COND_ASC,
//    EXPR_GROUP_COND_DESC,
extern GTWTreeType __strong const kExprCount;
//    EXPR_VARSTAR,
extern GTWTreeType __strong const kExprSameTerm;
extern GTWTreeType __strong const kExprSum;
extern GTWTreeType __strong const kExprAvg;
extern GTWTreeType __strong const kExprMin;
extern GTWTreeType __strong const kExprMax;
extern GTWTreeType __strong const kExprCoalesce;
extern GTWTreeType __strong const kExprIf;
extern GTWTreeType __strong const kExprURI;
extern GTWTreeType __strong const kExprIRI;
extern GTWTreeType __strong const kExprStrLang;
extern GTWTreeType __strong const kExprStrDT;
extern GTWTreeType __strong const kExprBNode;
extern GTWTreeType __strong const kExprGroupConcat;
extern GTWTreeType __strong const kExprSample;
extern GTWTreeType __strong const kExprIn;
extern GTWTreeType __strong const kExprNotIn;
extern GTWTreeType __strong const kExprIsNumeric;
extern GTWTreeType __strong const kExprYear;
extern GTWTreeType __strong const kExprMonth;
extern GTWTreeType __strong const kExprDay;
extern GTWTreeType __strong const kExprHours;
extern GTWTreeType __strong const kExprMinutes;
extern GTWTreeType __strong const kExprSeconds;
extern GTWTreeType __strong const kExprTimeZone;
extern GTWTreeType __strong const kExprCurrentDatetime;
extern GTWTreeType __strong const kExprNow;
extern GTWTreeType __strong const kExprFromUnixTime;
extern GTWTreeType __strong const kExprToUnixTime;
extern GTWTreeType __strong const kExprConcat;
extern GTWTreeType __strong const kExprStrLen;
extern GTWTreeType __strong const kExprSubStr;
extern GTWTreeType __strong const kExprUCase;
extern GTWTreeType __strong const kExprLCase;
extern GTWTreeType __strong const kExprStrStarts;
extern GTWTreeType __strong const kExprStrEnds;
extern GTWTreeType __strong const kExprContains;
extern GTWTreeType __strong const kExprEncodeForURI;
extern GTWTreeType __strong const kExprTZ;
extern GTWTreeType __strong const kExprRand;
extern GTWTreeType __strong const kExprAbs;
extern GTWTreeType __strong const kExprRound;
extern GTWTreeType __strong const kExprCeil;
extern GTWTreeType __strong const kExprFloor;
extern GTWTreeType __strong const kExprMD5;
extern GTWTreeType __strong const kExprSHA1;
extern GTWTreeType __strong const kExprSHA224;
extern GTWTreeType __strong const kExprSHA256;
extern GTWTreeType __strong const kExprSHA384;
extern GTWTreeType __strong const kExprSHA512;
extern GTWTreeType __strong const kExprStrBefore;
extern GTWTreeType __strong const kExprStrAfter;
extern GTWTreeType __strong const kExprReplace;
extern GTWTreeType __strong const kExprUUID;
extern GTWTreeType __strong const kExprStrUUID;
    //
extern GTWTreeType __strong const kTreeResult;

// ---------------------------------------------------------

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

@interface GTWQueryPlan : GTWTree<GTWQueryPlan>
@end
