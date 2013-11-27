#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

extern NSString * __strong const kUsedVariables;
extern NSString * __strong const kProjectVariables;

@interface SPKTree : NSObject<SPKTree, GTWRewriteable, NSCopying>

// ---------------------------------------------------------

// plan tree nodes:

extern SPKTreeType __strong const kPlanAsk;                 // Ask()
extern SPKTreeType __strong const kPlanEmpty;                 // Empty()
extern SPKTreeType __strong const kPlanScan;					// Scan( index, quad, restrictions )
extern SPKTreeType __strong const kPlanBKAjoin;				// BKAJoin( P, Q )
extern SPKTreeType __strong const kPlanHashJoin;				// HashJoin( P, Q, joinVars )
extern SPKTreeType __strong const kPlanNLjoin;				// NLJoin( P, Q )
extern SPKTreeType __strong const kPlanNLLeftJoin;			// NLLeftJoin( P, Q )
extern SPKTreeType __strong const kPlanProject;				// Project( P, vars )
extern SPKTreeType __strong const kPlanFilter;				// Filter( expr, P )
extern SPKTreeType __strong const kPlanUnion;					// Union( P, Q )
extern SPKTreeType __strong const kPlanExtend;				// Extend( P, var, expr )
extern SPKTreeType __strong const kPlanMinus;					// Minus( P, Q )
extern SPKTreeType __strong const kPlanOrder;					// Order( P, cond )
extern SPKTreeType __strong const kPlanDistinct;				// Distinct( P )
extern SPKTreeType __strong const kPlanGraph;               // Graph( G, P )
extern SPKTreeType __strong const kPlanService;               // Service( G, P )
extern SPKTreeType __strong const kPlanSlice;					// Slice( P, start, length )
extern SPKTreeType __strong const kPlanJoinIdentity;			// JoinIdentity()
extern SPKTreeType __strong const kPlanFedStub;				// FedStub( P )
extern SPKTreeType __strong const kPlanDescribe;
extern SPKTreeType __strong const kPlanGroup;
extern SPKTreeType __strong const kPlanZeroOrMorePath;
extern SPKTreeType __strong const kPlanOneOrMorePath;
extern SPKTreeType __strong const kPlanZeroOrOnePath;
extern SPKTreeType __strong const kPlanNPSPath;
extern SPKTreeType __strong const kPlanConstruct;
extern SPKTreeType __strong const kPlanLoad;
extern SPKTreeType __strong const kPlanModify;
extern SPKTreeType __strong const kPlanInsertData;
extern SPKTreeType __strong const kPlanDeleteData;
extern SPKTreeType __strong const kPlanCopy;                // TODO: remove this when the planner can produce the equivalent plan to an INSERT/WHERE
extern SPKTreeType __strong const kPlanDrop;
extern SPKTreeType __strong const kPlanDropAll;
extern SPKTreeType __strong const kPlanSequence;
//********** WHEN a new plan type is added, make sure that [SPKTree planResultClass] is still accurate
extern SPKTreeType __strong const kPlanCustom;

// algebra tree nodes:
extern SPKTreeType __strong const kAlgebraAsk;
extern SPKTreeType __strong const kAlgebraBGP;				// BGP(t1, t2, ...)
extern SPKTreeType __strong const kAlgebraJoin;				// Join( P, Q )
extern SPKTreeType __strong const kAlgebraLeftJoin;			// LeftJoin( P, Q, expr )
extern SPKTreeType __strong const kAlgebraFilter;				// Filter( expr, P )
extern SPKTreeType __strong const kAlgebraUnion;				// Union( P, Q )
extern SPKTreeType __strong const kAlgebraGraph;				// Graph( IRI|var, P )
extern SPKTreeType __strong const kAlgebraService;				// Service( IRI|var, P )
extern SPKTreeType __strong const kAlgebraExtend;				// Extend( P, var, expr )
extern SPKTreeType __strong const kAlgebraMinus;				// Minus( P, Q )
extern SPKTreeType __strong const kAlgebraGroup;				// Group( exprlist, P )
extern SPKTreeType __strong const kAlgebraToList;				// ToList( P )
extern SPKTreeType __strong const kAlgebraOrderBy;			// OrderBy( M, cond )
extern SPKTreeType __strong const kAlgebraProject;			// Project( M, vars )
extern SPKTreeType __strong const kAlgebraDistinct;			// Distinct( M )
extern SPKTreeType __strong const kAlgebraReduced;			// Reduced( M )
extern SPKTreeType __strong const kAlgebraSlice;				// Slice( M, start, length )
extern SPKTreeType __strong const kAlgebraToMultiset;			// ToMultiSet( M )
extern SPKTreeType __strong const kAlgebraDescribe;			//
extern SPKTreeType __strong const kAlgebraConstruct;
extern SPKTreeType __strong const kAlgebraDataset;
extern SPKTreeType __strong const kAlgebraInsertData;
extern SPKTreeType __strong const kAlgebraDeleteData;
extern SPKTreeType __strong const kAlgebraLoad;
extern SPKTreeType __strong const kAlgebraClear;
extern SPKTreeType __strong const kAlgebraDrop;
extern SPKTreeType __strong const kAlgebraCreate;
extern SPKTreeType __strong const kAlgebraAdd;
extern SPKTreeType __strong const kAlgebraCopy;
extern SPKTreeType __strong const kAlgebraModify;
extern SPKTreeType __strong const kAlgebraSequence;

// these are the algebra types that "leave" the algebra/plan value space
extern SPKTreeType __strong const kTreeSet;					// SPKTree* arguments[size]
extern SPKTreeType __strong const kTreeList;					// SPKTree* arguments[size]
extern SPKTreeType __strong const kTreeDictionary;			// SPKTree* arguments[size] of CSTRING nodes
extern SPKTreeType __strong const kTreeAggregate;				// same as STRING
extern SPKTreeType __strong const kTreeTriple;				// id<GTWTriple> ptr
extern SPKTreeType __strong const kTreeQuad;					// id<GTWQuad> ptr
extern SPKTreeType __strong const kTreeExpression;			// expr* ptr
extern SPKTreeType __strong const kTreeNode;					// id<GTWTerm> ptr
extern SPKTreeType __strong const kTreePath;					// @@ ?
extern SPKTreeType __strong const kTreeOrderCondition;		// @@ ?
extern SPKTreeType __strong const kTreeSolutionSequence;		// solutionset* ptr
extern SPKTreeType __strong const kTreeString;				// NSString*
// Property Path types
extern SPKTreeType __strong const kPathIRI;
extern SPKTreeType __strong const kPathInverse;
extern SPKTreeType __strong const kPathNegate;
extern SPKTreeType __strong const kPathSequence;
extern SPKTreeType __strong const kPathOr;
extern SPKTreeType __strong const kPathZeroOrMore;
extern SPKTreeType __strong const kPathOneOrMore;
extern SPKTreeType __strong const kPathZeroOrOne;
// Expression types
extern SPKTreeType __strong const kExprAnd;
extern SPKTreeType __strong const kExprOr;
extern SPKTreeType __strong const kExprEq;
extern SPKTreeType __strong const kExprNeq;
extern SPKTreeType __strong const kExprLt;
extern SPKTreeType __strong const kExprGt;
extern SPKTreeType __strong const kExprLe;
extern SPKTreeType __strong const kExprGe;
extern SPKTreeType __strong const kExprUMinus;
extern SPKTreeType __strong const kExprPlus;
extern SPKTreeType __strong const kExprMinus;
extern SPKTreeType __strong const kExprMul;
extern SPKTreeType __strong const kExprDiv;
extern SPKTreeType __strong const kExprBang;
extern SPKTreeType __strong const kExprLiteral;
extern SPKTreeType __strong const kExprFunction;
extern SPKTreeType __strong const kExprBound;
extern SPKTreeType __strong const kExprStr;
extern SPKTreeType __strong const kExprLang;
extern SPKTreeType __strong const kExprDatatype;
extern SPKTreeType __strong const kExprIsURI;
extern SPKTreeType __strong const kExprIsBlank;
extern SPKTreeType __strong const kExprIsLiteral;
extern SPKTreeType __strong const kExprCast;
extern SPKTreeType __strong const kExprLangMatches;
extern SPKTreeType __strong const kExprRegex;
extern SPKTreeType __strong const kExprCount;
extern SPKTreeType __strong const kExprSameTerm;
extern SPKTreeType __strong const kExprSum;
extern SPKTreeType __strong const kExprAvg;
extern SPKTreeType __strong const kExprMin;
extern SPKTreeType __strong const kExprMax;
extern SPKTreeType __strong const kExprCoalesce;
extern SPKTreeType __strong const kExprIf;
extern SPKTreeType __strong const kExprURI;
extern SPKTreeType __strong const kExprIRI;
extern SPKTreeType __strong const kExprStrLang;
extern SPKTreeType __strong const kExprStrDT;
extern SPKTreeType __strong const kExprBNode;
extern SPKTreeType __strong const kExprGroupConcat;
extern SPKTreeType __strong const kExprSample;
extern SPKTreeType __strong const kExprIn;
extern SPKTreeType __strong const kExprNotIn;
extern SPKTreeType __strong const kExprIsNumeric;
extern SPKTreeType __strong const kExprYear;
extern SPKTreeType __strong const kExprMonth;
extern SPKTreeType __strong const kExprDay;
extern SPKTreeType __strong const kExprHours;
extern SPKTreeType __strong const kExprMinutes;
extern SPKTreeType __strong const kExprSeconds;
extern SPKTreeType __strong const kExprTimeZone;
extern SPKTreeType __strong const kExprCurrentDatetime;
extern SPKTreeType __strong const kExprNow;
extern SPKTreeType __strong const kExprFromUnixTime;
extern SPKTreeType __strong const kExprToUnixTime;
extern SPKTreeType __strong const kExprConcat;
extern SPKTreeType __strong const kExprStrLen;
extern SPKTreeType __strong const kExprSubStr;
extern SPKTreeType __strong const kExprUCase;
extern SPKTreeType __strong const kExprLCase;
extern SPKTreeType __strong const kExprStrStarts;
extern SPKTreeType __strong const kExprStrEnds;
extern SPKTreeType __strong const kExprContains;
extern SPKTreeType __strong const kExprEncodeForURI;
extern SPKTreeType __strong const kExprTZ;
extern SPKTreeType __strong const kExprRand;
extern SPKTreeType __strong const kExprAbs;
extern SPKTreeType __strong const kExprRound;
extern SPKTreeType __strong const kExprCeil;
extern SPKTreeType __strong const kExprFloor;
extern SPKTreeType __strong const kExprMD5;
extern SPKTreeType __strong const kExprSHA1;
extern SPKTreeType __strong const kExprSHA224;
extern SPKTreeType __strong const kExprSHA256;
extern SPKTreeType __strong const kExprSHA384;
extern SPKTreeType __strong const kExprSHA512;
extern SPKTreeType __strong const kExprStrBefore;
extern SPKTreeType __strong const kExprStrAfter;
extern SPKTreeType __strong const kExprReplace;
extern SPKTreeType __strong const kExprUUID;
extern SPKTreeType __strong const kExprStrUUID;
extern SPKTreeType __strong const kExprExists;
extern SPKTreeType __strong const kExprNotExists;

extern SPKTreeType __strong const kTreeResult;
extern SPKTreeType __strong const kTreeResultSet;				// ResultSet( length, results )

// ---------------------------------------------------------

@property BOOL leaf;
@property SPKTreeType type;
@property id<SPKTree> treeValue;
@property NSArray* arguments;

@property id value;
@property void* ptr;
@property NSMutableDictionary* annotations;

- (SPKTree*) initWithType: (SPKTreeType) type value: (id) value treeValue: (id<SPKTree>) treeValue arguments: (NSArray*) args;
- (SPKTree*) initLeafWithType: (SPKTreeType) type treeValue: (id<SPKTree>) treeValue;
- (SPKTree*) initLeafWithType: (SPKTreeType) type value: (id) value;
- (SPKTree*) initWithType: (SPKTreeType) type arguments: (NSArray*) args;
- (SPKTree*) initWithType: (SPKTreeType) type value: (id) value arguments: (NSArray*) args;
- (SPKTree*) initWithType: (SPKTreeType) type treeValue: (id<SPKTree>) treeValue arguments: (NSArray*) args;
- (NSString*) treeTypeName;
- (id) applyPrefixBlock: (SPKTreeAccessorBlock)prefix postfixBlock: (SPKTreeAccessorBlock) postfix;
- (Class) planResultClass;

+ (NSString*) sparqlForAlgebra: (id<SPKTree>) algebra;
- (NSString*) conciseDescription;
- (NSString*) longDescription;

@end

@interface SPKQueryPlan : SPKTree<GTWQueryPlan>
@end
