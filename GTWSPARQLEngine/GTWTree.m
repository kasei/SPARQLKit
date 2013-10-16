#import "GTWTree.h"
#import "GTWSPARQLEngine.h"
#import <GTWSWBase/GTWVariable.h>

NSString* __strong const kUsedVariables     = @"us.kasei.sparql.variables.used";
NSString* __strong const kProjectVariables  = @"us.kasei.sparql.variables.project";

// Plans
GTWTreeType __strong const kPlanAsk                     = @"PlanAsk";
GTWTreeType __strong const kPlanEmpty					= @"PlanEmpty";
GTWTreeType __strong const kPlanScan					= @"PlanScan";
GTWTreeType __strong const kPlanBKAjoin					= @"PlanBKAjoin";
GTWTreeType __strong const kPlanHashJoin				= @"PlanHashJoin";
GTWTreeType __strong const kPlanNLjoin					= @"PlanNLjoin";
GTWTreeType __strong const kPlanNLLeftJoin				= @"PlanNLLeftJoin";
GTWTreeType __strong const kPlanProject					= @"PlanProject";
GTWTreeType __strong const kPlanFilter					= @"PlanFilter";
GTWTreeType __strong const kPlanUnion					= @"PlanUnion";
GTWTreeType __strong const kPlanExtend					= @"PlanExtend";
GTWTreeType __strong const kPlanMinus					= @"PlanMinus";
GTWTreeType __strong const kPlanOrder					= @"PlanOrder";
GTWTreeType __strong const kPlanDistinct				= @"PlanDistinct";
GTWTreeType __strong const kPlanGraph                   = @"PlanGraph";
GTWTreeType __strong const kPlanSlice					= @"PlanSlice";
GTWTreeType __strong const kPlanJoinIdentity			= @"PlanJoinIdentity";
GTWTreeType __strong const kPlanFedStub					= @"PlanFedStub";
GTWTreeType __strong const kPlanDescribe				= @"PlanDescribe";

// Algebras
GTWTreeType __strong const kAlgebraAsk                  = @"AlgebraAsk";
GTWTreeType __strong const kAlgebraBGP					= @"AlgebraBGP";
GTWTreeType __strong const kAlgebraJoin					= @"AlgebraJoin";
GTWTreeType __strong const kAlgebraLeftJoin				= @"AlgebraLeftJoin";
GTWTreeType __strong const kAlgebraFilter				= @"AlgebraFilter";
GTWTreeType __strong const kAlgebraUnion				= @"AlgebraUnion";
GTWTreeType __strong const kAlgebraGraph				= @"AlgebraGraph";
GTWTreeType __strong const kAlgebraExtend				= @"AlgebraExtend";
GTWTreeType __strong const kAlgebraMinus				= @"AlgebraMinus";
GTWTreeType __strong const kAlgebraZeroLengthPath		= @"AlgebraZeroLengthPath";
GTWTreeType __strong const kAlgebraZeroOrMorePath		= @"AlgebraZeroOrMorePath";
GTWTreeType __strong const kAlgebraOneOrMorePath		= @"AlgebraOneOrMorePath";
GTWTreeType __strong const kAlgebraNegatedPropertySet	= @"AlgebraNegatedPropertySet";
GTWTreeType __strong const kAlgebraGroup				= @"AlgebraGroup";
GTWTreeType __strong const kAlgebraAggregation			= @"AlgebraAggregation";
GTWTreeType __strong const kAlgebraAggregateJoin		= @"AlgebraAggregateJoin";
GTWTreeType __strong const kAlgebraToList				= @"AlgebraToList";
GTWTreeType __strong const kAlgebraOrderBy				= @"AlgebraOrderBy";
GTWTreeType __strong const kAlgebraProject				= @"AlgebraProject";
GTWTreeType __strong const kAlgebraDistinct				= @"AlgebraDistinct";
GTWTreeType __strong const kAlgebraReduced				= @"AlgebraReduced";
GTWTreeType __strong const kAlgebraSlice				= @"AlgebraSlice";
GTWTreeType __strong const kAlgebraToMultiset			= @"AlgebraToMultiset";
GTWTreeType __strong const kAlgebraDescribe				= @"AlgebraDescribe";
GTWTreeType __strong const kAlgebraConstruct            = @"AlgebraConstruct";

// Leaving the tree value space
GTWTreeType __strong const kTreeSet						= @"TreeSet";
GTWTreeType __strong const kTreeList					= @"TreeList";
GTWTreeType __strong const kTreeDictionary				= @"TreeDictionary";
GTWTreeType __strong const kTreeAggregate				= @"TreeAggregate";
GTWTreeType __strong const kTreeTriple					= @"TreeTriple";
GTWTreeType __strong const kTreeQuad					= @"TreeQuad";
GTWTreeType __strong const kTreeExpression				= @"TreeExpression";
GTWTreeType __strong const kTreeNode					= @"TreeNode";
GTWTreeType __strong const kTreePath					= @"TreePath";
GTWTreeType __strong const kTreeOrderCondition			= @"TreeOrderCondition";
GTWTreeType __strong const kTreeSolutionSequence		= @"TreeSolutionSequence";
GTWTreeType __strong const kTreeString					= @"TreeString";

// Property Path types
GTWTreeType __strong const kPathIRI                     = @"link";
GTWTreeType __strong const kPathInverse                 = @"inv";
GTWTreeType __strong const kPathNegate                  = @"!";
GTWTreeType __strong const kPathSequence                = @"seq";
GTWTreeType __strong const kPathOr                      = @"alt";
GTWTreeType __strong const kPathZeroOrMore              = @"*";
GTWTreeType __strong const kPathOneOrMore               = @"+";
GTWTreeType __strong const kPathZeroOrOne               = @"?";

// Expressions
GTWTreeType __strong const kExprAnd						= @"ExprAnd";
GTWTreeType __strong const kExprOr						= @"ExprOr";
GTWTreeType __strong const kExprEq						= @"ExprEq";
GTWTreeType __strong const kExprNeq						= @"ExprNeq";
GTWTreeType __strong const kExprLt						= @"ExprLt";
GTWTreeType __strong const kExprGt						= @"ExprGt";
GTWTreeType __strong const kExprLe						= @"ExprLe";
GTWTreeType __strong const kExprGe						= @"ExprGe";
GTWTreeType __strong const kExprUMinus					= @"ExprUMinus";
GTWTreeType __strong const kExprPlus					= @"ExprPlus";
GTWTreeType __strong const kExprMinus					= @"ExprMinus";
GTWTreeType __strong const kExprMul                     = @"ExprMul";
GTWTreeType __strong const kExprDiv                     = @"ExprDiv";
GTWTreeType __strong const kExprBang					= @"ExprBang";
GTWTreeType __strong const kExprLiteral					= @"ExprLiteral";
GTWTreeType __strong const kExprFunction				= @"ExprFunction";
GTWTreeType __strong const kExprBound					= @"ExprBound";
GTWTreeType __strong const kExprStr						= @"ExprStr";
GTWTreeType __strong const kExprLang					= @"ExprLang";
GTWTreeType __strong const kExprDatatype				= @"ExprDatatype";
GTWTreeType __strong const kExprIsURI					= @"ExprIsURI";
GTWTreeType __strong const kExprIsBlank					= @"ExprIsBlank";
GTWTreeType __strong const kExprIsLiteral				= @"ExprIsLiteral";
GTWTreeType __strong const kExprCast					= @"ExprCast";
GTWTreeType __strong const kExprLangMatches				= @"ExprLangMatches";
GTWTreeType __strong const kExprRegex					= @"ExprRegex";
GTWTreeType __strong const kExprCount					= @"ExprCount";
GTWTreeType __strong const kExprSameTerm				= @"ExprSameTerm";
GTWTreeType __strong const kExprSum						= @"ExprSum";
GTWTreeType __strong const kExprAvg						= @"ExprAvg";
GTWTreeType __strong const kExprMin						= @"ExprMin";
GTWTreeType __strong const kExprMax						= @"ExprMax";
GTWTreeType __strong const kExprCoalesce				= @"ExprCoalesce";
GTWTreeType __strong const kExprIf						= @"ExprIf";
GTWTreeType __strong const kExprURI						= @"ExprURI";
GTWTreeType __strong const kExprIRI						= @"ExprIRI";
GTWTreeType __strong const kExprStrLang					= @"ExprStrLang";
GTWTreeType __strong const kExprStrDT					= @"ExprStrDT";
GTWTreeType __strong const kExprBNode					= @"ExprBNode";
GTWTreeType __strong const kExprGroupConcat				= @"ExprGroupConcat";
GTWTreeType __strong const kExprSample					= @"ExprSample";
GTWTreeType __strong const kExprIn						= @"ExprIn";
GTWTreeType __strong const kExprNotIn					= @"ExprNotIn";
GTWTreeType __strong const kExprIsNumeric				= @"ExprIsNumeric";
GTWTreeType __strong const kExprYear					= @"ExprYear";
GTWTreeType __strong const kExprMonth					= @"ExprMonth";
GTWTreeType __strong const kExprDay						= @"ExprDay";
GTWTreeType __strong const kExprHours					= @"ExprHours";
GTWTreeType __strong const kExprMinutes					= @"ExprMinutes";
GTWTreeType __strong const kExprSeconds					= @"ExprSeconds";
GTWTreeType __strong const kExprTimeZone				= @"ExprTimeZone";
GTWTreeType __strong const kExprCurrentDatetime			= @"ExprCurrentDatetime";
GTWTreeType __strong const kExprNow						= @"ExprNow";
GTWTreeType __strong const kExprFromUnixTime			= @"ExprFromUnixTime";
GTWTreeType __strong const kExprToUnixTime				= @"ExprToUnixTime";
GTWTreeType __strong const kExprConcat					= @"ExprConcat";
GTWTreeType __strong const kExprStrLen					= @"ExprStrLen";
GTWTreeType __strong const kExprSubStr					= @"ExprSubStr";
GTWTreeType __strong const kExprUCase					= @"ExprUCase";
GTWTreeType __strong const kExprLCase					= @"ExprLCase";
GTWTreeType __strong const kExprStrStarts				= @"ExprStrStarts";
GTWTreeType __strong const kExprStrEnds					= @"ExprStrEnds";
GTWTreeType __strong const kExprContains				= @"ExprContains";
GTWTreeType __strong const kExprEncodeForURI			= @"ExprEncodeForURI";
GTWTreeType __strong const kExprTZ						= @"ExprTZ";
GTWTreeType __strong const kExprRand					= @"ExprRand";
GTWTreeType __strong const kExprAbs						= @"ExprAbs";
GTWTreeType __strong const kExprRound					= @"ExprRound";
GTWTreeType __strong const kExprCeil					= @"ExprCeil";
GTWTreeType __strong const kExprFloor					= @"ExprFloor";
GTWTreeType __strong const kExprMD5						= @"ExprMD5";
GTWTreeType __strong const kExprSHA1					= @"ExprSHA1";
GTWTreeType __strong const kExprSHA224					= @"ExprSHA224";
GTWTreeType __strong const kExprSHA256					= @"ExprSHA256";
GTWTreeType __strong const kExprSHA384					= @"ExprSHA384";
GTWTreeType __strong const kExprSHA512					= @"ExprSHA512";
GTWTreeType __strong const kExprStrBefore				= @"ExprStrBefore";
GTWTreeType __strong const kExprStrAfter				= @"ExprStrAfter";
GTWTreeType __strong const kExprReplace					= @"ExprReplace";
GTWTreeType __strong const kExprUUID					= @"ExprUUID";
GTWTreeType __strong const kExprStrUUID					= @"ExprStrUUID";
GTWTreeType __strong const kExprExists                  = @"ExprExists";
GTWTreeType __strong const kExprNotExists               = @"ExprNotExists";

GTWTreeType __strong const kTreeResult					= @"TreeResult";
GTWTreeType __strong const kTreeResultSet				= @"ResultSet";

//static const char* gtw_tree_type_name ( GTWTreeType t ) {
//	switch (t) {
//        case PLAN_EMPTY:
//            return "Empty";
//		case PLAN_JOIN_IDENTITY:
//			return "JoinIdentity";
//		case PLAN_SCAN:
//			return "Scan";
//		case PLAN_BKAJOIN:
//			return "BKAJoin";
//		case PLAN_FEDSTUB:
//			return "FedStub";
//		case PLAN_NLJOIN:
//			return "NLJoin";
//		case PLAN_HASHJOIN:
//			return "HashJoin";
//		case PLAN_NLLEFTJOIN:
//			return "NLLeftJoin";
//		case PLAN_PROJECT:
//			return "Project";
//		case PLAN_FILTER:
//			return "Filter";
//		case PLAN_UNION:
//			return "Union";
//		case PLAN_EXTEND:
//			return "Extend";
//		case PLAN_MINUS:
//			return "Minus";
//		case PLAN_ORDER:
//			return "Order";
//		case PLAN_DISTINCT:
//			return "Distinct";
//		case PLAN_SLICE:
//			return "Slice";
//		case PLAN_DESCRIBE:
//			return "Describe";
//		case ALGEBRA_BGP:
//			return "BGP";
//		case ALGEBRA_JOIN:
//			return "Join";
//		case ALGEBRA_LEFTJOIN:
//			return "LeftJoin";
//		case ALGEBRA_FILTER:
//			return "Filter";
//		case ALGEBRA_UNION:
//			return "Union";
//		case ALGEBRA_GRAPH:
//			return "Graph";
//		case ALGEBRA_EXTEND:
//			return "Extend";
//		case ALGEBRA_MINUS:
//			return "Minus";
//		case ALGEBRA_ZEROLENGTHPATH:
//			return "ZeroLengthPath";
//		case ALGEBRA_ZEROORMOREPATH:
//			return "ZeroOrMorePath";
//		case ALGEBRA_ONEORMOREPATH:
//			return "OneOrMorePath";
//		case ALGEBRA_NEGATEDPROPERTYSET:
//			return "NegatedPropertySet";
//		case ALGEBRA_GROUP:
//			return "Group";
//		case ALGEBRA_AGGREGATION:
//			return "Aggregation";
//		case ALGEBRA_AGGREGATEJOIN:
//			return "AggregateJoin";
//		case ALGEBRA_TOLIST:
//			return "ToList";
//		case ALGEBRA_ORDERBY:
//			return "OrderBy";
//		case ALGEBRA_PROJECT:
//			return "Project";
//		case ALGEBRA_DISTINCT:
//			return "Distinct";
//		case ALGEBRA_REDUCED:
//			return "Reduced";
//		case ALGEBRA_SLICE:
//			return "Slice";
//		case ALGEBRA_TOMULTISET:
//			return "ToMultiset";
//		case ALGEBRA_DESCRIBE:
//			return "Describe";
//		case TREE_SET:
//			return "set";
//		case TREE_LIST:
//			return "list";
//		case TREE_DICTIONARY:
//			return "dictionary";
//		case TREE_AGGREGATE:
//			return "aggregate";
//		case TREE_TRIPLE:
//			return "triple";
//		case TREE_QUAD:
//			return "quad";
//		case TREE_EXPRESSION:
//			return "expr";
//		case TREE_NODE:
//			return "node";
//		case TREE_PATH:
//			return "path";
//		case TREE_ORDER_CONDITION:
//			return "ordercondition";
//		case TREE_SOLUTION_SEQUENCE:
//			return "solutionsequence";
//		case TREE_STRING:
//			return "string";
//		case EXPR_AND:
//			return "EXPR_AND";
//		case EXPR_OR:
//			return "EXPR_OR";
//		case EXPR_EQ:
//			return "EXPR_EQ";
//		case EXPR_NEQ:
//			return "EXPR_NEQ";
//		case EXPR_LT:
//			return "EXPR_LT";
//		case EXPR_GT:
//			return "EXPR_GT";
//		case EXPR_LE:
//			return "EXPR_LE";
//		case EXPR_GE:
//			return "EXPR_GE";
//		case EXPR_UMINUS:
//			return "EXPR_UMINUS";
//		case EXPR_PLUS:
//			return "EXPR_PLUS";
//		case EXPR_MINUS:
//			return "EXPR_MINUS";
//		case EXPR_BANG:
//            return "EXPR_BANG";
//		case EXPR_LITERAL:
//            return "EXPR_LITERAL";
//		case EXPR_FUNCTION:
//            return "EXPR_FUNCTION";
//		case EXPR_BOUND:
//            return "EXPR_BOUND";
//		case EXPR_STR:
//            return "EXPR_STR";
//		case EXPR_LANG:
//            return "EXPR_LANG";
//		case EXPR_DATATYPE:
//            return "EXPR_DATATYPE";
//		case EXPR_ISURI:
//            return "EXPR_ISURI";
//		case EXPR_ISBLANK:
//            return "EXPR_ISBLANK";
//		case EXPR_ISLITERAL:
//            return "EXPR_ISLITERAL";
//		case EXPR_CAST:
//            return "EXPR_CAST";
//		case EXPR_LANGMATCHES:
//            return "EXPR_LANGMATCHES";
//		case EXPR_REGEX:
//            return "EXPR_REGEX";
//		case EXPR_COUNT:
//            return "EXPR_COUNT";
//		case EXPR_SAMETERM:
//            return "EXPR_SAMETERM";
//		case EXPR_SUM:
//            return "EXPR_SUM";
//		case EXPR_AVG:
//            return "EXPR_AVG";
//		case EXPR_MIN:
//            return "EXPR_MIN";
//		case EXPR_MAX:
//            return "EXPR_MAX";
//		case EXPR_COALESCE:
//            return "EXPR_COALESCE";
//		case EXPR_IF:
//            return "EXPR_IF";
//		case EXPR_URI:
//            return "EXPR_URI";
//		case EXPR_IRI:
//            return "EXPR_IRI";
//		case EXPR_STRLANG:
//            return "EXPR_STRLANG";
//		case EXPR_STRDT:
//            return "EXPR_STRDT";
//		case EXPR_BNODE:
//            return "EXPR_BNODE";
//		case EXPR_GROUP_CONCAT:
//            return "EXPR_GROUP_CONCAT";
//		case EXPR_SAMPLE:
//            return "EXPR_SAMPLE";
//		case EXPR_IN:
//            return "EXPR_IN";
//		case EXPR_NOT_IN:
//            return "EXPR_NOT_IN";
//		case EXPR_ISNUMERIC:
//            return "EXPR_ISNUMERIC";
//		case EXPR_YEAR:
//            return "EXPR_YEAR";
//		case EXPR_MONTH:
//            return "EXPR_MONTH";
//		case EXPR_DAY:
//            return "EXPR_DAY";
//		case EXPR_HOURS:
//            return "EXPR_HOURS";
//		case EXPR_MINUTES:
//            return "EXPR_MINUTES";
//		case EXPR_SECONDS:
//            return "EXPR_SECONDS";
//		case EXPR_TIMEZONE:
//            return "EXPR_TIMEZONE";
//		case EXPR_CURRENT_DATETIME:
//            return "EXPR_CURRENT_DATETIME";
//		case EXPR_NOW:
//            return "EXPR_NOW";
//		case EXPR_FROM_UNIXTIME:
//            return "EXPR_FROM_UNIXTIME";
//		case EXPR_TO_UNIXTIME:
//            return "EXPR_TO_UNIXTIME";
//		case EXPR_CONCAT:
//            return "EXPR_CONCAT";
//		case EXPR_STRLEN:
//            return "EXPR_STRLEN";
//		case EXPR_SUBSTR:
//            return "EXPR_SUBSTR";
//		case EXPR_UCASE:
//            return "EXPR_UCASE";
//		case EXPR_LCASE:
//            return "EXPR_LCASE";
//		case EXPR_STRSTARTS:
//            return "EXPR_STRSTARTS";
//		case EXPR_STRENDS:
//            return "EXPR_STRENDS";
//		case EXPR_CONTAINS:
//            return "EXPR_CONTAINS";
//		case EXPR_ENCODE_FOR_URI:
//            return "EXPR_ENCODE_FOR_URI";
//		case EXPR_TZ:
//            return "EXPR_TZ";
//		case EXPR_RAND:
//            return "EXPR_RAND";
//		case EXPR_ABS:
//            return "EXPR_ABS";
//		case EXPR_ROUND:
//            return "EXPR_ROUND";
//		case EXPR_CEIL:
//            return "EXPR_CEIL";
//		case EXPR_FLOOR:
//            return "EXPR_FLOOR";
//		case EXPR_MD5:
//            return "EXPR_MD5";
//		case EXPR_SHA1:
//            return "EXPR_SHA1";
//		case EXPR_SHA224:
//            return "EXPR_SHA224";
//		case EXPR_SHA256:
//            return "EXPR_SHA256";
//		case EXPR_SHA384:
//            return "EXPR_SHA384";
//		case EXPR_SHA512:
//            return "EXPR_SHA512";
//		case EXPR_STRBEFORE:
//            return "EXPR_STRBEFORE";
//		case EXPR_STRAFTER:
//            return "EXPR_STRAFTER";
//		case EXPR_REPLACE:
//            return "EXPR_REPLACE";
//		case EXPR_UUID:
//            return "EXPR_UUID";
//		case EXPR_STRUUID:
//            return "EXPR_STRUUID";
//		default:
//			return "(unknown)";
//	}
//}

@implementation GTWTree

- (GTWTree*) init {
    if (self = [super init]) {
        self.annotations = [NSMutableDictionary dictionary];
        self.leaf        = NO;
    }
    return self;
}

- (GTWTree*) initLeafWithType: (GTWTreeType) type value: (id) value pointer: (void*) ptr {
    if (self = [self init]) {
        self.leaf   = YES;
        self.type   = type;
        self.ptr	= ptr;
        self.value  = value;
        if (!type) {
            NSLog(@"no type specified for GTWTree leaf");
        }
    }
    return self;
}

- (GTWTree*) initWithType: (GTWTreeType) type value: (id) value arguments: (NSArray*) args {
    if (self = [self initWithType:type arguments:args]) {
        self.value  = value;
    }
    return self;
}

- (GTWTree*) initWithType: (GTWTreeType) type arguments: (NSArray*) args {
    if (self = [self init]) {
        int i;
        self.leaf   = NO;
        self.type   = type;
        self.ptr	= NULL;
        self.value  = nil;
        NSUInteger size     = [args count];
        NSMutableArray* arguments  = [NSMutableArray arrayWithCapacity:size];
        self.arguments  = args;
        int location_set	= 0;
        NSUInteger location	= 0;
        //	fprintf(stderr, "constructing %s with locations:\n", gtw_tree_type_name(type));
        NSUInteger locsize	= size;
        
        if (type == kPlanHashJoin) {
            // PLAN_HASHJOIN's 3rd child is the list of join vars, not a subplan, so it shouldn't participate in invocation counting
            locsize--;
        }
        
        for (i = 0; i < size; i++) {
            GTWTree* n  = args[i];
            if (n == nil) {
                NSLog(@"NULL node argument passed to gtw_new_tree");
                return nil;
            }
            
//            if (type == TREE_NODE || type == TREE_TRIPLE || type == TREE_QUAD || type == TREE_EXPRESSION) {
//                
//            } else {
                if (![n isKindOfClass:[GTWTree class]]) {
                    NSLog(@"argument object isn't a tree object: %@", n);
                    ;
                }
            
//            NSLog(@"argument object: %@", n);
                if (i < locsize) {
                    //			fprintf(stderr, "- %"PRIu32"\n", n->location);
                    if (location_set) {
                        if (location != n.location) {
                            location	= 0;
                        }
                    } else {
                        location_set	= 1;
                        location		= n.location;
                    }
                }
//            }
            [arguments addObject:n];
        }
        self.arguments  = arguments;
        /*
         if (location > 0) {
         fprintf(stderr, "setting location to %"PRIu32"\n", location);
         }
         */
        
        // 	if (type == PLAN_UNION) {
        // 		if (size == 1) {
        // 			fprintf(stderr, "*** UNION with 1 branch\n");
        // 			gtw_error_trap();
        // 		}
        // 	}
        if (type == kPlanHashJoin && size >= 3) {
            GTWTree* n	= args[2];
            NSUInteger count	= [n.arguments count];
            if (count == 0) {
                NSLog(@"hashjoin without join variables\n");
            }
        }
        self.location	= location;
    }
    return self;
}

- (NSString*) treeTypeName {
    return self.type;
//    return [NSString stringWithCString:gtw_tree_type_name(self.type) encoding:NSUTF8StringEncoding];
}

- (id) _applyBlock: (id(^)(id<GTWTree> node, NSUInteger level, BOOL* stop))block inOrder: (GTWTreeTraversalOrder) order level: (NSUInteger) level {
    BOOL stop   = NO;
    id value    = nil;
    if (order == GTWTreePrefixOrder) {
        value    = block(self, level, &stop);
        if (stop)
            return value;
    }
    
    if (order == GTWTreeInfixOrder) {
        if ([self.arguments count] == 2) {
            [self.arguments[0] _applyBlock:block inOrder:order level:level+1];
            value   = [self _applyBlock:block inOrder:order level:level];
            [self.arguments[1] _applyBlock:block inOrder:order level:level+1];
        } else {
            NSLog(@"Cannot use infix tree traversal on tree node with children count of %ld", [self.arguments count]);
            return nil;
        }
    } else {
        for (GTWTree* child in self.arguments) {
            [child _applyBlock:block inOrder:order level:level+1];
        }
    }
    
    if (order == GTWTreePostfixOrder) {
        value    = block(self, level, &stop);
    }
    
    return value;
}

- (id) _applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix withParent: (id<GTWTree>) parent level: (NSUInteger) level {
    BOOL stop   = NO;
    id value    = nil;
    if (prefix) {
        value    = prefix(self, parent, level, &stop);
        if (stop)
            return value;
    }
    
    for (GTWTree* child in self.arguments) {
        [child _applyPrefixBlock:prefix postfixBlock:postfix withParent: self level:level+1];
    }
    
    if (postfix) {
        value    = postfix(self, parent, level, &stop);
    }
    
    return value;
}

- (id) applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix {
    return [self _applyPrefixBlock:prefix postfixBlock:postfix withParent: nil level:0];
}

- (id) annotationForKey: (NSString*) key {
    return (self.annotations)[key];
}

- (void) computeScopeVariables {
    [self applyPrefixBlock:nil postfixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
        if (node.leaf) {
            if (node.type == kTreeNode) {
                id<GTWTerm> term    = node.value;
                // TODO: This should be using a protocol to check if the term is a variable
                if ([term conformsToProtocol:@protocol(GTWVariable)]) {
                    NSSet* set          = [NSSet setWithObject:term];
                    //                NSLog(@"variables: %@ for plan: %@", set, node);
                    (node.annotations)[kUsedVariables] = set;
                }
            } else if (node.type == kTreeQuad) {
                id<GTWQuad> q  = node.value;
                NSArray* array  = @[q.subject, q.predicate, q.object, q.graph];
                NSMutableSet* set   = [NSMutableSet set];
                for (id<GTWTerm> term in array) {
                    if ([term conformsToProtocol:@protocol(GTWVariable)]) {
                        [set addObject:term];
                    }
                    (node.annotations)[kUsedVariables] = set;
                }
            } else if (node.type == kTreeTriple) {
                id<GTWTriple> q  = node.value;
                NSArray* array  = @[q.subject, q.predicate, q.object];
                NSMutableSet* set   = [NSMutableSet set];
                for (id<GTWTerm> term in array) {
                    if ([term conformsToProtocol:@protocol(GTWVariable)]) {
                        [set addObject:term];
                    }
                    (node.annotations)[kUsedVariables] = set;
                }
            }
        } else {
            NSMutableSet* set   = [NSMutableSet set];
            if (node.value && [node.value conformsToProtocol:@protocol(GTWTerm)]) {
                id<GTWTerm> term    = node.value;
                // TODO: This should be using a protocol to check if the term is a variable
                if ([term conformsToProtocol:@protocol(GTWVariable)]) {
                    [set unionSet: [NSSet setWithObject:term]];
                }
            }
            
            NSUInteger count    = [node.arguments count];
            if (count) {
                GTWTree* firstchild  = node.arguments[0];
                [set unionSet:(firstchild.annotations)[kUsedVariables]];
                NSUInteger i;
                for (i = 1; i < count; i++) {
                    GTWTree* nextchild  = node.arguments[i];
                    NSSet* newset  = (nextchild.annotations)[kUsedVariables];
                    if (newset) {
                        [set unionSet:newset];
                    }
                }
                if (node.value && [node.value isKindOfClass:[GTWTree class]]) {
                    GTWTree* tree   = node.value;
                    [tree computeScopeVariables];
                    NSSet* newset  = (tree.annotations)[kUsedVariables];
                    if (newset) {
                        [set unionSet:newset];
                    }
                }
                
            }
            (node.annotations)[kUsedVariables] = set;
        }
        return nil;
    }];
}

- (void) computeProjectVariables {
    [self computeScopeVariables];
    [self applyPrefixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
        if (node.type == kPlanProject) {
            GTWTree* list   = node.value;
            NSMutableArray* vars    = [NSMutableArray array];
            for (id<GTWTree> v in list.arguments) {
                if (v.type == kTreeNode && [v.value conformsToProtocol:@protocol(GTWVariable)]) {
                    [vars addObject:v.value];
                }
            }
            NSSet* set      = [NSMutableSet setWithArray:vars];
            (node.annotations)[kProjectVariables] = set;
        } else if (node.type == kPlanNLjoin) {
            NSSet* lhs  = [node.arguments[0] annotationForKey:kUsedVariables];
            NSMutableSet* joinVars   = [NSMutableSet setWithSet:[node.arguments[1] annotationForKey:kUsedVariables]];
            [joinVars intersectSet:lhs];
            NSMutableArray* vars    = [NSMutableArray array];
            for (id<GTWVariable> v in joinVars) {
                [vars addObject:v];
            }
            NSMutableSet* set   = [NSMutableSet setWithArray:vars];
            NSSet* parentVars   = [parent annotationForKey:kProjectVariables];
            if (parentVars) {
                [set unionSet:parentVars];
            }
            (node.annotations)[kProjectVariables] = set;
//            NSLog(@"pattern: %@\njoin variables: %@\nproject variables: %@", node, joinVars, set);
        } else if (node.type == kPlanOrder) {
            GTWTree* list   = node.value;
            NSMutableArray* vars    = [NSMutableArray array];
            for (id<GTWTree> v in list.arguments) {
                if (v.type == kTreeNode && [v.value conformsToProtocol:@protocol(GTWVariable)]) {
                    [vars addObject:v.value];
                }
            }
            NSMutableSet* set   = [NSMutableSet setWithArray:vars];
            NSSet* parentVars   = [parent annotationForKey:kProjectVariables];
            if (parentVars) {
                [set unionSet:parentVars];
            }
            (node.annotations)[kProjectVariables] = set;
        } else {
            NSMutableSet* set  = [NSMutableSet setWithSet: [parent annotationForKey:kProjectVariables]];
            if (!set) {
                set     = [NSMutableSet setWithSet: [node annotationForKey:kUsedVariables]];
            }
            
            NSSet* usedvars = [node annotationForKey:kUsedVariables];
            [set intersectSet:usedvars];
            (node.annotations)[kProjectVariables] = set;
        }
        
        
//        NSSet* set  = [node.annotations objectForKey:kProjectVariables];
//        NSLog(@"pushing down project list: %@ on %@", set, [node conciseDescription]);
        return nil;
    } postfixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
        if (node.type == kPlanSlice) {
            id<GTWTree> child   = node.arguments[0];
            id proj             = child.annotations[kProjectVariables];
            (node.annotations)[kProjectVariables]   = proj;
        }
        return nil;
    }];
}

- (NSSet*) nonAggregatedVariables {
    if (self.type == kTreeNode) {
        return [NSSet setWithObject:self.value];
    } else if (self.type == kAlgebraExtend) {
        return [self.arguments[0] nonAggregatedVariables];
    } else if (self.type == kExprCount || self.type == kExprSum || self.type == kExprMin || self.type == kExprMax || self.type == kExprAvg || self.type == kExprSample || self.type == kExprGroupConcat) {
        return [NSSet set];
    } else {
        NSMutableSet* set   = [NSMutableSet set];
        for (id<GTWTree> n in self.arguments) {
            [set addObjectsFromArray:[[n nonAggregatedVariables] allObjects]];
        }
        return set;
    }
}

- (NSString*) conciseDescription {
    NSMutableString* s = [NSMutableString string];
    GTWTree* node = self;
    if (node.leaf) {
        [s appendFormat: @"%@(", [node treeTypeName]];
        if (node.value) {
            [s appendFormat:@"%@", node.value];
        }
        if (node.ptr) {
            [s appendFormat:@"<%p>", node.ptr];
        }
        [s appendString:@")"];
    } else {
        [s appendFormat: @"%@", [node treeTypeName]];
        if (node.value) {
            [s appendFormat:@"[%@]", node.value];
        }
        int i;
        NSUInteger count    = [node.arguments count];
        if (count > 0) {
            [s appendString:@"("];
            [s appendFormat:@"%@", [node.arguments[0] conciseDescription]];
            for (i = 1; i < count; i++) {
                [s appendFormat:@", %@", [node.arguments[i] conciseDescription]];
            }
            [s appendString:@")"];
        }
    }
    return s;
}

- (NSString*) longDescription {
    NSMutableString* s = [NSMutableString string];
    [self applyPrefixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
        NSMutableString* indent = [NSMutableString string];
        for (NSUInteger i = 0; i < level; i++) {
            [indent appendFormat:@"  "];
        }
        //        [s appendFormat: @"%@%s\n", indent, gtw_tree_type_name(node.type)];
        if (node.leaf) {
            [s appendFormat: @"%@%@", indent, [node treeTypeName]];
            if (node.value) {
                [s appendFormat:@" %@", node.value];
            }
            if (node.ptr) {
                [s appendFormat:@"<%p>", node.ptr];
            }
            [s appendFormat:@"\n"];
        } else {
            [s appendFormat: @"%@%@", indent, [node treeTypeName]];
            if (node.value) {
                if ([node.value isKindOfClass:[GTWTree class]]) {
                    [s appendFormat:@" %@", [node.value conciseDescription]];
                } else {
                    [s appendFormat:@" %@", node.value];
                }
            }
            if (node.ptr) {
                [s appendFormat:@"<%p>", node.ptr];
            }
            [s appendFormat:@"\n"];
        }
        return nil;
    } postfixBlock:nil];
    return s;
}

- (NSString*) description {
    if (self.type == kTreeNode || self.type == kTreeQuad || self.type == kTreeList) {
        return [self conciseDescription];
    } else {
        return [self longDescription];
    }
}

@end

@implementation GTWQueryPlan
@end
