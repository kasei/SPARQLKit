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
GTWTreeType __strong const kPlanGroup                   = @"PlanGroup";
GTWTreeType __strong const kPlanZeroOrMorePath          = @"PlanZeroOrMorePath";
GTWTreeType __strong const kPlanOneOrMorePath           = @"PlanOneOrMorePath";
GTWTreeType __strong const kPlanZeroOrOnePath           = @"PlanZeroOrOnePath";
GTWTreeType __strong const kPlanNPSPath                 = @"PlanNPS";
GTWTreeType __strong const kPlanConstruct               = @"PlanConstruct";

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
//GTWTreeType __strong const kAlgebraZeroLengthPath		= @"AlgebraZeroLengthPath";
//GTWTreeType __strong const kAlgebraZeroOrMorePath		= @"AlgebraZeroOrMorePath";
//GTWTreeType __strong const kAlgebraOneOrMorePath		= @"AlgebraOneOrMorePath";
//GTWTreeType __strong const kAlgebraNegatedPropertySet	= @"AlgebraNegatedPropertySet";
GTWTreeType __strong const kAlgebraGroup				= @"AlgebraGroup";
//GTWTreeType __strong const kAlgebraAggregation			= @"AlgebraAggregation";
//GTWTreeType __strong const kAlgebraAggregateJoin		= @"AlgebraAggregateJoin";
GTWTreeType __strong const kAlgebraToList				= @"AlgebraToList";
GTWTreeType __strong const kAlgebraOrderBy				= @"AlgebraOrderBy";
GTWTreeType __strong const kAlgebraProject				= @"AlgebraProject";
GTWTreeType __strong const kAlgebraDistinct				= @"AlgebraDistinct";
GTWTreeType __strong const kAlgebraReduced				= @"AlgebraReduced";
GTWTreeType __strong const kAlgebraSlice				= @"AlgebraSlice";
GTWTreeType __strong const kAlgebraToMultiset			= @"AlgebraToMultiset";
GTWTreeType __strong const kAlgebraDescribe				= @"AlgebraDescribe";
GTWTreeType __strong const kAlgebraConstruct            = @"AlgebraConstruct";
GTWTreeType __strong const kAlgebraDataset              = @"AlgebraDataset";

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

@implementation GTWTree

- (GTWTree*) init {
    if (self = [super init]) {
        self.annotations = [NSMutableDictionary dictionary];
        self.leaf        = NO;
    }
    return self;
}

- (GTWTree*) initLeafWithType: (GTWTreeType) type treeValue: (id<GTWTree>) treeValue {
    return [self initLeafWithType:type value:nil treeValue:treeValue pointer:NULL];
}

- (GTWTree*) initLeafWithType: (GTWTreeType) type value: (id) value pointer: (void*) ptr {
    return [self initLeafWithType:type value:value treeValue:nil pointer:NULL];
}

- (GTWTree*) initLeafWithType: (GTWTreeType) type value: (id) value treeValue: (id<GTWTree>) treeValue pointer: (void*) ptr {
    if (self = [self init]) {
        self.leaf   = YES;
        self.type   = type;
        self.ptr	= ptr;
        self.value  = value;
        self.treeValue  = treeValue;
        if (!type) {
            NSLog(@"no type specified for GTWTree leaf");
        }
    }
    return self;
}

- (GTWTree*) initWithType: (GTWTreeType) type value: (id) value treeValue: (id<GTWTree>) treeValue arguments: (NSArray*) args {
    if (self = [self init]) {
        int i;
        self.leaf   = NO;
        self.type   = type;
        self.ptr	= NULL;
        self.value  = value;
        self.treeValue  = treeValue;
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
    
    if (self.type == kTreeNode && !(self.value || self.treeValue)) {
        NSLog(@"TreeNode without node!");
        return nil;
    }
    
    return self;
}


- (GTWTree*) initWithType: (GTWTreeType) type value: (id) value arguments: (NSArray*) args {
    return [self initWithType:type value:value treeValue:nil arguments:args];
}

- (GTWTree*) initWithType: (GTWTreeType) type treeValue: (id<GTWTree>) treeValue arguments: (NSArray*) args {
    return [self initWithType:type value:nil treeValue:treeValue arguments:args];
}

- (GTWTree*) initWithType: (GTWTreeType) type arguments: (NSArray*) args {
    return [self initWithType:type value:nil treeValue: nil arguments:args];
}

- (id) copyReplacingValues: (NSDictionary*) map {
    id<GTWTree> replace = [map objectForKey:self];
    if (replace) {
        id r    = replace;
        return [r copy];
    } else {
        GTWTree* copy       = [[[self class] alloc] init];
        copy.leaf           = self.leaf;
        copy.type           = self.type;
        NSMutableArray* args    = [NSMutableArray array];
        for (id<GTWTree> a in self.arguments) {
            id<GTWTree> c   = [a copyReplacingValues: map];
            [args addObject:c];
        }
        copy.arguments      = args;
        if ([self.value conformsToProtocol:@protocol(GTWRewriteable)]) {
            id<GTWRewriteable> value    = self.value;
            copy.value          = [value copyReplacingValues: map];
        } else {
            copy.value          = [self.value copy];
        }
        id tv               = self.treeValue;
        copy.treeValue      = [tv copyReplacingValues: map];
        copy.ptr            = self.ptr;
        copy.location       = self.location;
        copy.annotations    = [NSMutableDictionary dictionaryWithDictionary:self.annotations];
        return copy;
    }
}

- (id)copyWithZone:(NSZone *)zone {
    return [self copy];
}

- (GTWTree*) copy {
    GTWTree* copy       = [GTWTree alloc];
    copy.leaf           = self.leaf;
    copy.type           = self.type;
    copy.arguments      = [self.arguments copy];
    copy.value          = [self.value copy];
    id tv               = self.treeValue;
    copy.treeValue      = [tv copy];
    copy.ptr            = self.ptr;
    copy.location       = self.location;
    copy.annotations    = [NSMutableDictionary dictionaryWithDictionary:self.annotations];
    return copy;
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
            NSMutableDictionary* a  = [node annotations];
            a[kUsedVariables] = [set copy];
        }
        return nil;
    }];
}

- (void) computeProjectVariables {
    [self computeScopeVariables];
    [self applyPrefixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
        if (node.type == kPlanProject) {
            GTWTree* list   = node.treeValue;
            NSMutableArray* vars    = [NSMutableArray array];
            for (id<GTWTree> v in list.arguments) {
                if (v.type == kTreeNode && [v.value isKindOfClass:[GTWVariable class]]) {
                    [vars addObject:v.value];
                } else if (v.type == kAlgebraExtend) {
                    id<GTWTree> list    = v.treeValue;
                    id<GTWTree> node    = list.arguments[1];
                    id<GTWTerm> v       = node.value;
                    if ([v isKindOfClass:[GTWVariable class]]) {
                        [vars addObject:v];
                    }
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
            id<GTWTree> list   = node.treeValue;
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

- (NSSet*) inScopeVariables {
    if (self.type == kTreeNode) {
        return [NSSet setWithObject:self.value];
    } else if (self.type == kTreeTriple || self.type == kTreeQuad) {
        NSMutableSet* set   = [NSMutableSet set];
        NSArray* nodes  = [self.value allValues];
        for (id<GTWTerm> n in nodes) {
            if ([n isKindOfClass:[GTWVariable class]]) {
                [set addObject:n];
            }
        }
        return set;
    } else if (self.type == kAlgebraProject) {
//        NSLog(@"computing in-scope variables for projection: %@", self);
        id<GTWTree> project = self.treeValue;
        NSMutableSet* set   = [NSMutableSet set];
        for (id<GTWTree> t in project.arguments) {
            if (t.type == kTreeNode) {
                [set addObject:t.value];
            } else if (t.type == kAlgebraExtend) {
                id<GTWTree> list    = t.treeValue;
                id<GTWTree> node    = list.arguments[1];
                [set addObject:node.value];
                for (id<GTWTree> pattern in t.arguments) {
                    NSSet* patvars      = [pattern inScopeVariables];
                    [set addObjectsFromArray:[patvars allObjects]];
                }
            }
        }
//        NSLog(@"---> %@", set);
        return set;
    } else if (self.type == kAlgebraExtend) {
        id<GTWTree> list    = self.treeValue;
        NSMutableSet* set   = [NSMutableSet setWithSet:[self.arguments[0] inScopeVariables]];
        id<GTWTree> node    = list.arguments[1];
        id<GTWTerm> term    = node.value;
        [set addObject: term];
        return set;
    } else {
        NSMutableSet* set   = [NSMutableSet set];
        for (id<GTWTree> n in self.arguments) {
            [set addObjectsFromArray:[[n inScopeVariables] allObjects]];
        }
        return set;
    }
}

- (NSSet*) nonAggregatedVariables {
    if (self.type == kTreeNode) {
        id<GTWTerm> t   = self.value;
        if ([t isKindOfClass:[GTWVariable class]]) {
            return [NSSet setWithObject:self.value];
        } else {
            return [NSSet set];
        }
    } else if (self.type == kAlgebraExtend) {
        id<GTWTree> list    = self.treeValue;
        NSMutableSet* set   = [NSMutableSet setWithSet:[list.arguments[0] nonAggregatedVariables]];
        for (id<GTWTree> pattern in self.arguments) {
            NSSet* patvars      = [pattern nonAggregatedVariables];
            [set addObjectsFromArray:[patvars allObjects]];
        }
        return set;
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
        if (node.treeValue) {
            [s appendFormat:@"%@", node.treeValue];
        } else if (node.value) {
            [s appendFormat:@"%@", node.value];
        }
        if (node.ptr) {
            [s appendFormat:@"<%p>", node.ptr];
        }
        [s appendString:@")"];
    } else {
        [s appendFormat: @"%@", [node treeTypeName]];
        if (node.treeValue) {
            [s appendFormat:@"[%@]", node.treeValue];
        } else if (node.value) {
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
            if (node.treeValue) {
                [s appendFormat:@" %@", node.treeValue];
            } else if (node.value) {
                [s appendFormat:@" %@", node.value];
            }
            if (node.ptr) {
                [s appendFormat:@"<%p>", node.ptr];
            }
            [s appendFormat:@"\n"];
        } else {
            [s appendFormat: @"%@%@", indent, [node treeTypeName]];
            if (node.treeValue) {
                [s appendFormat:@" %@", [node.treeValue conciseDescription]];
            } else if (node.value) {
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

- (BOOL)isEqual:(id)anObject {
    return [[self description] isEqual: [anObject description]];
}

- (NSComparisonResult)compare:(id<GTWTree>)tree {
    return [[self description] compare:[tree description]];
}

- (NSUInteger)hash {
    NSUInteger h    = [[self description] hash];
    return h;
}

@end

@implementation GTWQueryPlan
@end
