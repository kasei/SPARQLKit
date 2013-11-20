#import "SPKTree.h"
#import "SPARQLKit.h"
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWTriple.h>
#import "NSObject+SPKTree.h"

NSString* __strong const kUsedVariables     = @"us.kasei.sparql.variables.used";
NSString* __strong const kProjectVariables  = @"us.kasei.sparql.variables.project";

// Plans
SPKTreeType __strong const kPlanAsk                     = @"PlanAsk";
SPKTreeType __strong const kPlanEmpty					= @"PlanEmpty";
SPKTreeType __strong const kPlanScan					= @"PlanScan";
SPKTreeType __strong const kPlanBKAjoin					= @"PlanBKAjoin";
SPKTreeType __strong const kPlanHashJoin				= @"PlanHashJoin";
SPKTreeType __strong const kPlanNLjoin					= @"PlanNLjoin";
SPKTreeType __strong const kPlanNLLeftJoin				= @"PlanNLLeftJoin";
SPKTreeType __strong const kPlanProject					= @"PlanProject";
SPKTreeType __strong const kPlanFilter					= @"PlanFilter";
SPKTreeType __strong const kPlanUnion					= @"PlanUnion";
SPKTreeType __strong const kPlanExtend					= @"PlanExtend";
SPKTreeType __strong const kPlanMinus					= @"PlanMinus";
SPKTreeType __strong const kPlanOrder					= @"PlanOrder";
SPKTreeType __strong const kPlanDistinct				= @"PlanDistinct";
SPKTreeType __strong const kPlanGraph                   = @"PlanGraph";
SPKTreeType __strong const kPlanService                 = @"PlanService";
SPKTreeType __strong const kPlanSlice					= @"PlanSlice";
SPKTreeType __strong const kPlanJoinIdentity			= @"PlanJoinIdentity";
SPKTreeType __strong const kPlanFedStub					= @"PlanFedStub";
SPKTreeType __strong const kPlanDescribe				= @"PlanDescribe";
SPKTreeType __strong const kPlanGroup                   = @"PlanGroup";
SPKTreeType __strong const kPlanZeroOrMorePath          = @"PlanZeroOrMorePath";
SPKTreeType __strong const kPlanOneOrMorePath           = @"PlanOneOrMorePath";
SPKTreeType __strong const kPlanZeroOrOnePath           = @"PlanZeroOrOnePath";
SPKTreeType __strong const kPlanNPSPath                 = @"PlanNPS";
SPKTreeType __strong const kPlanConstruct               = @"PlanConstruct";
SPKTreeType __strong const kPlanCustom                  = @"PlanCustom";

// Algebras
SPKTreeType __strong const kAlgebraAsk                  = @"AlgebraAsk";
SPKTreeType __strong const kAlgebraBGP					= @"AlgebraBGP";
SPKTreeType __strong const kAlgebraJoin					= @"AlgebraJoin";
SPKTreeType __strong const kAlgebraLeftJoin				= @"AlgebraLeftJoin";
SPKTreeType __strong const kAlgebraFilter				= @"AlgebraFilter";
SPKTreeType __strong const kAlgebraUnion				= @"AlgebraUnion";
SPKTreeType __strong const kAlgebraGraph				= @"AlgebraGraph";
SPKTreeType __strong const kAlgebraService				= @"AlgebraService";
SPKTreeType __strong const kAlgebraExtend				= @"AlgebraExtend";
SPKTreeType __strong const kAlgebraMinus				= @"AlgebraMinus";
SPKTreeType __strong const kAlgebraGroup				= @"AlgebraGroup";
SPKTreeType __strong const kAlgebraToList				= @"AlgebraToList";
SPKTreeType __strong const kAlgebraOrderBy				= @"AlgebraOrderBy";
SPKTreeType __strong const kAlgebraProject				= @"AlgebraProject";
SPKTreeType __strong const kAlgebraDistinct				= @"AlgebraDistinct";
SPKTreeType __strong const kAlgebraReduced				= @"AlgebraReduced";
SPKTreeType __strong const kAlgebraSlice				= @"AlgebraSlice";
SPKTreeType __strong const kAlgebraToMultiset			= @"AlgebraToMultiset";
SPKTreeType __strong const kAlgebraDescribe				= @"AlgebraDescribe";
SPKTreeType __strong const kAlgebraConstruct            = @"AlgebraConstruct";
SPKTreeType __strong const kAlgebraDataset              = @"AlgebraDataset";

// Leaving the tree value space
SPKTreeType __strong const kTreeSet						= @"TreeSet";
SPKTreeType __strong const kTreeList					= @"TreeList";
SPKTreeType __strong const kTreeDictionary				= @"TreeDictionary";
SPKTreeType __strong const kTreeAggregate				= @"TreeAggregate";
SPKTreeType __strong const kTreeTriple					= @"TreeTriple";
SPKTreeType __strong const kTreeQuad					= @"TreeQuad";
SPKTreeType __strong const kTreeExpression				= @"TreeExpression";
SPKTreeType __strong const kTreeNode					= @"TreeNode";
SPKTreeType __strong const kTreePath					= @"TreePath";
SPKTreeType __strong const kTreeOrderCondition			= @"TreeOrderCondition";
SPKTreeType __strong const kTreeSolutionSequence		= @"TreeSolutionSequence";
SPKTreeType __strong const kTreeString					= @"TreeString";

// Property Path types
SPKTreeType __strong const kPathIRI                     = @"link";
SPKTreeType __strong const kPathInverse                 = @"inv";
SPKTreeType __strong const kPathNegate                  = @"!";
SPKTreeType __strong const kPathSequence                = @"seq";
SPKTreeType __strong const kPathOr                      = @"alt";
SPKTreeType __strong const kPathZeroOrMore              = @"*";
SPKTreeType __strong const kPathOneOrMore               = @"+";
SPKTreeType __strong const kPathZeroOrOne               = @"?";

// Expressions
SPKTreeType __strong const kExprAnd						= @"ExprAnd";
SPKTreeType __strong const kExprOr						= @"ExprOr";
SPKTreeType __strong const kExprEq						= @"ExprEq";
SPKTreeType __strong const kExprNeq						= @"ExprNeq";
SPKTreeType __strong const kExprLt						= @"ExprLt";
SPKTreeType __strong const kExprGt						= @"ExprGt";
SPKTreeType __strong const kExprLe						= @"ExprLe";
SPKTreeType __strong const kExprGe						= @"ExprGe";
SPKTreeType __strong const kExprUMinus					= @"ExprUMinus";
SPKTreeType __strong const kExprPlus					= @"ExprPlus";
SPKTreeType __strong const kExprMinus					= @"ExprMinus";
SPKTreeType __strong const kExprMul                     = @"ExprMul";
SPKTreeType __strong const kExprDiv                     = @"ExprDiv";
SPKTreeType __strong const kExprBang					= @"ExprBang";
SPKTreeType __strong const kExprLiteral					= @"ExprLiteral";
SPKTreeType __strong const kExprFunction				= @"ExprFunction";
SPKTreeType __strong const kExprBound					= @"ExprBound";
SPKTreeType __strong const kExprStr						= @"ExprStr";
SPKTreeType __strong const kExprLang					= @"ExprLang";
SPKTreeType __strong const kExprDatatype				= @"ExprDatatype";
SPKTreeType __strong const kExprIsURI					= @"ExprIsURI";
SPKTreeType __strong const kExprIsBlank					= @"ExprIsBlank";
SPKTreeType __strong const kExprIsLiteral				= @"ExprIsLiteral";
SPKTreeType __strong const kExprCast					= @"ExprCast";
SPKTreeType __strong const kExprLangMatches				= @"ExprLangMatches";
SPKTreeType __strong const kExprRegex					= @"ExprRegex";
SPKTreeType __strong const kExprCount					= @"ExprCount";
SPKTreeType __strong const kExprSameTerm				= @"ExprSameTerm";
SPKTreeType __strong const kExprSum						= @"ExprSum";
SPKTreeType __strong const kExprAvg						= @"ExprAvg";
SPKTreeType __strong const kExprMin						= @"ExprMin";
SPKTreeType __strong const kExprMax						= @"ExprMax";
SPKTreeType __strong const kExprCoalesce				= @"ExprCoalesce";
SPKTreeType __strong const kExprIf						= @"ExprIf";
SPKTreeType __strong const kExprURI						= @"ExprURI";
SPKTreeType __strong const kExprIRI						= @"ExprIRI";
SPKTreeType __strong const kExprStrLang					= @"ExprStrLang";
SPKTreeType __strong const kExprStrDT					= @"ExprStrDT";
SPKTreeType __strong const kExprBNode					= @"ExprBNode";
SPKTreeType __strong const kExprGroupConcat				= @"ExprGroupConcat";
SPKTreeType __strong const kExprSample					= @"ExprSample";
SPKTreeType __strong const kExprIn						= @"ExprIn";
SPKTreeType __strong const kExprNotIn					= @"ExprNotIn";
SPKTreeType __strong const kExprIsNumeric				= @"ExprIsNumeric";
SPKTreeType __strong const kExprYear					= @"ExprYear";
SPKTreeType __strong const kExprMonth					= @"ExprMonth";
SPKTreeType __strong const kExprDay						= @"ExprDay";
SPKTreeType __strong const kExprHours					= @"ExprHours";
SPKTreeType __strong const kExprMinutes					= @"ExprMinutes";
SPKTreeType __strong const kExprSeconds					= @"ExprSeconds";
SPKTreeType __strong const kExprTimeZone				= @"ExprTimeZone";
SPKTreeType __strong const kExprCurrentDatetime			= @"ExprCurrentDatetime";
SPKTreeType __strong const kExprNow						= @"ExprNow";
SPKTreeType __strong const kExprFromUnixTime			= @"ExprFromUnixTime";
SPKTreeType __strong const kExprToUnixTime				= @"ExprToUnixTime";
SPKTreeType __strong const kExprConcat					= @"ExprConcat";
SPKTreeType __strong const kExprStrLen					= @"ExprStrLen";
SPKTreeType __strong const kExprSubStr					= @"ExprSubStr";
SPKTreeType __strong const kExprUCase					= @"ExprUCase";
SPKTreeType __strong const kExprLCase					= @"ExprLCase";
SPKTreeType __strong const kExprStrStarts				= @"ExprStrStarts";
SPKTreeType __strong const kExprStrEnds					= @"ExprStrEnds";
SPKTreeType __strong const kExprContains				= @"ExprContains";
SPKTreeType __strong const kExprEncodeForURI			= @"ExprEncodeForURI";
SPKTreeType __strong const kExprTZ						= @"ExprTZ";
SPKTreeType __strong const kExprRand					= @"ExprRand";
SPKTreeType __strong const kExprAbs						= @"ExprAbs";
SPKTreeType __strong const kExprRound					= @"ExprRound";
SPKTreeType __strong const kExprCeil					= @"ExprCeil";
SPKTreeType __strong const kExprFloor					= @"ExprFloor";
SPKTreeType __strong const kExprMD5						= @"ExprMD5";
SPKTreeType __strong const kExprSHA1					= @"ExprSHA1";
SPKTreeType __strong const kExprSHA224					= @"ExprSHA224";
SPKTreeType __strong const kExprSHA256					= @"ExprSHA256";
SPKTreeType __strong const kExprSHA384					= @"ExprSHA384";
SPKTreeType __strong const kExprSHA512					= @"ExprSHA512";
SPKTreeType __strong const kExprStrBefore				= @"ExprStrBefore";
SPKTreeType __strong const kExprStrAfter				= @"ExprStrAfter";
SPKTreeType __strong const kExprReplace					= @"ExprReplace";
SPKTreeType __strong const kExprUUID					= @"ExprUUID";
SPKTreeType __strong const kExprStrUUID					= @"ExprStrUUID";
SPKTreeType __strong const kExprExists                  = @"ExprExists";
SPKTreeType __strong const kExprNotExists               = @"ExprNotExists";

SPKTreeType __strong const kTreeResult					= @"TreeResult";
SPKTreeType __strong const kTreeResultSet				= @"ResultSet";

@implementation SPKTree

- (SPKTree*) init {
    if (self = [super init]) {
        self.annotations = [NSMutableDictionary dictionary];
        self.leaf        = NO;
    }
    return self;
}

- (SPKTree*) initLeafWithType: (SPKTreeType) type treeValue: (id<SPKTree>) treeValue {
    if (self = [self initWithType:type value:nil treeValue:treeValue arguments:nil]) {
        self.leaf   = YES;
    }
    return self;
}

- (SPKTree*) initLeafWithType: (SPKTreeType) type value: (id) value {
    if (self = [self initWithType:type value:value treeValue:nil arguments:nil]) {
        self.leaf   = YES;
    }
    return self;
}

- (SPKTree*) initWithType: (SPKTreeType) type value: (id) value treeValue: (id<SPKTree>) treeValue arguments: (NSArray*) args {
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
        
        for (i = 0; i < size; i++) {
            SPKTree* n  = args[i];
            if (n == nil) {
                NSLog(@"NULL node argument passed to gtw_new_tree");
                return nil;
            }
            
            if (![n conformsToProtocol:@protocol(SPKTree)]) {
                NSLog(@"argument object isn't a tree object: %@", n);
            }
            
            [arguments addObject:n];
        }
        self.arguments  = arguments;
        if (type == kPlanHashJoin && size >= 3) {
            SPKTree* n	= args[2];
            NSUInteger count	= [n.arguments count];
            if (count == 0) {
                NSLog(@"hashjoin without join variables\n");
            }
        }
    }
    
    if (self.type == kTreeNode && !(self.value || self.treeValue)) {
        NSLog(@"TreeNode without node!");
        return nil;
    }
    
    return self;
}


- (SPKTree*) initWithType: (SPKTreeType) type value: (id) value arguments: (NSArray*) args {
    return [self initWithType:type value:value treeValue:nil arguments:args];
}

- (SPKTree*) initWithType: (SPKTreeType) type treeValue: (id<SPKTree>) treeValue arguments: (NSArray*) args {
    return [self initWithType:type value:nil treeValue:treeValue arguments:args];
}

- (SPKTree*) initWithType: (SPKTreeType) type arguments: (NSArray*) args {
    return [self initWithType:type value:nil treeValue: nil arguments:args];
}

- (id) copyReplacingValues: (NSDictionary*) map {
    id<SPKTree> replace = [map objectForKey:self];
    if (replace) {
        id r    = replace;
        return [r copy];
    } else {
        SPKTree* copy       = [[[self class] alloc] init];
        copy.leaf           = self.leaf;
        copy.type           = self.type;
        NSMutableArray* args    = [NSMutableArray array];
        for (id<SPKTree> a in self.arguments) {
            id<SPKTree> c   = [a copyReplacingValues: map];
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
        copy.annotations    = [NSMutableDictionary dictionaryWithDictionary:self.annotations];
        return copy;
    }
}

- (id)copyWithCanonicalization {
    SPKTree* copy       = [[[self class] alloc] init];
    copy.leaf           = self.leaf;
    copy.type           = self.type;
    NSMutableArray* args    = [NSMutableArray array];
    for (id<SPKTree> a in self.arguments) {
        id<SPKTree> c   = [a copyWithCanonicalization];
        [args addObject:c];
    }
    copy.arguments      = args;
    if ([self.value conformsToProtocol:@protocol(GTWRewriteable)]) {
        id<GTWRewriteable> value    = self.value;
        copy.value          = [value copyWithCanonicalization];
    } else {
        copy.value          = [self.value copy];
    }
    id tv               = self.treeValue;
    copy.treeValue      = [tv copyWithCanonicalization];
    copy.ptr            = self.ptr;
    copy.annotations    = [NSMutableDictionary dictionaryWithDictionary:self.annotations];
    return copy;
}

- (id)copyWithZone:(NSZone *)zone {
    return [self copy];
}

- (SPKTree*) copy {
    return [self copyReplacingValues:@{}];
}


- (NSString*) treeTypeName {
    return self.type;
}

- (id) _applyPrefixBlock: (SPKTreeAccessorBlock)prefix postfixBlock: (SPKTreeAccessorBlock) postfix withParent: (id<SPKTree>) parent level: (NSUInteger) level {
    BOOL stop   = NO;
    id value    = nil;
    if (prefix) {
        value    = prefix(self, parent, level, &stop);
        if (stop)
            return value;
    }
    
    for (SPKTree* child in self.arguments) {
        [child _applyPrefixBlock:prefix postfixBlock:postfix withParent: self level:level+1];
    }
    
    if (postfix) {
        value    = postfix(self, parent, level, &stop);
    }
    
    return value;
}

- (id) applyPrefixBlock: (SPKTreeAccessorBlock)prefix postfixBlock: (SPKTreeAccessorBlock) postfix {
    return [self _applyPrefixBlock:prefix postfixBlock:postfix withParent: nil level:0];
}

- (NSSet*) referencedBlanks {
    if (self.type == kTreeNode) {
        if ([self.value isKindOfClass:[GTWBlank class]]) {
            return [NSSet setWithObject:self.value];
        }
        return [NSSet set];
    } else if (self.type == kTreeTriple || self.type == kTreeQuad) {
        NSMutableSet* set   = [NSMutableSet set];
        NSArray* nodes  = [self.value allValues];
        for (id<GTWTerm> n in nodes) {
            if ([n isKindOfClass:[GTWBlank class]]) {
                [set addObject:n];
            }
        }
        return set;
    } else {
        NSMutableSet* set   = [NSMutableSet set];
        for (id<SPKTree> n in self.arguments) {
            [set addObjectsFromArray:[[n referencedBlanks] allObjects]];
        }
        return set;
    }
}

- (NSSet*) inScopeVariables {
    NSSet* set  = [NSSet setWithObjects:[GTWVariable class], nil];
    return [self inScopeNodesOfClass:set];
}

- (NSSet*) inScopeNodesOfClass: (NSSet*) types {
    if (self.type == kTreeNode) {
        for (id type in types) {
            if ([self.value isKindOfClass:type]) {
                return [NSSet setWithObject:self.value];
            }
        }
        return [NSSet set];
    } else if (self.type == kTreeTriple || self.type == kTreeQuad) {
        NSMutableSet* set   = [NSMutableSet set];
        NSArray* nodes  = [self.value allValues];
        for (id<GTWTerm> n in nodes) {
            for (id type in types) {
                if ([n isKindOfClass:type]) {
                    [set addObject:n];
                }
            }
        }
        return set;
    } else if (self.type == kAlgebraGraph) {
        NSMutableSet* set   = [[self.arguments[0] inScopeNodesOfClass:types] mutableCopy];
        id<SPKTree> tn      = self.treeValue;
        id<GTWTerm> term    = tn.value;
        for (id type in types) {
            if ([term isKindOfClass:type]) {
                [set addObject:term];
            }
        }
        return set;
    } else if (self.type == kAlgebraProject || self.type == kPlanProject) {
//        NSLog(@"computing in-scope nodes for projection: %@", self);
        id<SPKTree> project = self.treeValue;
        NSMutableSet* set   = [NSMutableSet set];
        for (id<SPKTree> t in project.arguments) {
            if (t.type == kTreeNode) {
                for (id type in types) {
                    if ([t.value isKindOfClass:type]) {
                        [set addObject:t.value];
                    }
                }
            } else if (t.type == kAlgebraExtend) {
                id<SPKTree> list    = t.treeValue;
                id<SPKTree> node    = list.arguments[1];
                for (id type in types) {
                    if ([node.value isKindOfClass:type]) {
                        [set addObject:node.value];
                    }
                }
                for (id<SPKTree> pattern in t.arguments) {
                    NSSet* patvars      = [pattern inScopeNodesOfClass:types];
                    [set addObjectsFromArray:[patvars allObjects]];
                }
            }
        }
//        NSLog(@"---> %@", set);
        return set;
    } else if (self.type == kAlgebraExtend || self.type == kPlanExtend) {
        id<SPKTree> list    = self.treeValue;
        NSMutableSet* set   = [NSMutableSet setWithSet:[self.arguments[0] inScopeNodesOfClass:types]];
        id<SPKTree> node    = list.arguments[1];
        for (id type in types) {
            if ([node.value isKindOfClass:type]) {
                [set addObject:node.value];
            }
        }
        return set;
    } else {
        NSMutableSet* set   = [NSMutableSet set];
        for (id<SPKTree> n in self.arguments) {
            [set addObjectsFromArray:[[n inScopeNodesOfClass:types] allObjects]];
        }
        return set;
    }
}

- (Class) planResultClass {
    if (self.type == kPlanConstruct || self.type == kPlanDescribe) {
        return [GTWTriple class];
    } else {
        return [NSDictionary class];
    }
}

/**
 Called on a projection tree (representing a single projected variable or expression),
 returns the set of variables used in the projection that are not used inside of an
 aggregate oepration. For example, the expression (MAX(?x) AS ?y) would return the empty set,
 while the expressions ?y, (COUNT(?x) + ?y), and FLOOR(?y) would all return the set { ?y }.
 */
- (NSSet*) nonAggregatedVariables {
    if (self.type == kTreeNode) {
        id<GTWTerm> t   = self.value;
        if ([t isKindOfClass:[GTWVariable class]]) {
            return [NSSet setWithObject:self.value];
        } else {
            return [NSSet set];
        }
    } else if (self.type == kAlgebraExtend) {
        id<SPKTree> list    = self.treeValue;
        id<SPKTree> expr    = list.arguments[0];
        return [expr nonAggregatedVariables];
    } else if (self.type == kExprCount || self.type == kExprSum || self.type == kExprMin || self.type == kExprMax || self.type == kExprAvg || self.type == kExprSample || self.type == kExprGroupConcat) {
        return [NSSet set];
    } else {
        NSMutableSet* set   = [NSMutableSet set];
        for (id<SPKTree> n in self.arguments) {
            [set addObjectsFromArray:[[n nonAggregatedVariables] allObjects]];
        }
        return [set copy];
    }
}

- (NSString*) conciseDescription {
    NSMutableString* s = [NSMutableString string];
    SPKTree* node = self;
    if (node.leaf) {
        [s appendFormat: @"%@(", [node treeTypeName]];
        if (node.treeValue) {
            [s appendFormat:@"%@", node.treeValue];
        } else if (node.value) {
            NSString* description = [[[node.value description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByReplacingOccurrencesOfString:@"\t" withString:@""];
            [s appendFormat:@"%@", description];
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
            NSString* description = [[[node.value description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByReplacingOccurrencesOfString:@"\t" withString:@""];
            [s appendFormat:@"[%@]", description];
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
    [self applyPrefixBlock:^id(id<SPKTree> node, id<SPKTree> parent, NSUInteger level, BOOL *stop) {
        NSMutableString* indent = [NSMutableString string];
        for (NSUInteger i = 0; i < level; i++) {
            [indent appendFormat:@"  "];
        }
        if (node.leaf) {
            [s appendFormat: @"%@%@", indent, [node treeTypeName]];
            if (node.treeValue) {
                [s appendFormat:@" %@", node.treeValue];
            } else if (node.value) {
                NSString* description = [[[node.value description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByReplacingOccurrencesOfString:@"\t" withString:@""];
                [s appendFormat:@" %@", description];
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
                if ([node.value conformsToProtocol:@protocol(SPKTree)]) {
                    [s appendFormat:@" %@", [node.value conciseDescription]];
                } else {
                    NSString* description = [[[node.value description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByReplacingOccurrencesOfString:@"\t" withString:@""];
                    [s appendFormat:@" %@", description];
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

- (NSComparisonResult)compare:(id<SPKTree>)tree {
    return [[self description] compare:[tree description]];
}

- (NSUInteger)hash {
    NSUInteger h    = [[self description] hash];
    return h;
}

+ (NSString*) sparqlForAlgebra: (id<SPKTree>) algebra isProjected: (BOOL*) isProjected indentLevel: (NSUInteger) indentLevel {
    NSMutableString* indent = [NSMutableString string];
    NSUInteger i;
    for (i = 0; i < indentLevel; i++) {
        [indent appendString:@"  "];
    }
    if (algebra.type == kTreeTriple) {
        id<GTWTriple> t = algebra.value;
        return [NSString stringWithFormat:@"%@%@", indent, [t description]];
    } else if (algebra.type == kTreeList || algebra.type == kAlgebraBGP) {
        NSMutableArray* s   = [NSMutableArray array];
        for (id<SPKTree> t in algebra.arguments) {
            [s addObject:[self sparqlForAlgebra:t isProjected:isProjected indentLevel:indentLevel+1]];
        }
        return [NSString stringWithFormat:@"%@%@", indent, [s componentsJoinedByString:@"\n"]];
    } else if (algebra.type == kAlgebraLeftJoin) {
        NSString* lhs   = [self sparqlForAlgebra:algebra.arguments[0] isProjected:isProjected indentLevel:indentLevel+1];
        NSString* rhs   = [self sparqlForAlgebra:algebra.arguments[1] isProjected:isProjected indentLevel:indentLevel+1];
        return [NSString stringWithFormat:@"%@%@\n%@OPTIONAL {\n%@\n%@}\n", indent, lhs, indent, indent, rhs];
    } else if (algebra.type == kAlgebraService) {
        id<SPKTree> list        = algebra.treeValue;
        id<SPKTree> eptree      = list.arguments[0];
        id<SPKTree> silenttree  = list.arguments[1];
        id<GTWTerm> epterm      = eptree.value;
        GTWLiteral* silentTerm  = silenttree.value;
        BOOL silent             = [silentTerm booleanValue];

        NSString* lhs   = [self sparqlForAlgebra:algebra.arguments[0] isProjected:isProjected indentLevel:indentLevel+1];
        NSString* sparql    = [NSString stringWithFormat:@"%@SERVICE %@%@ {\n%@\n%@}\n", indent, (silent ? @"SILENT " : @""), epterm, indent, lhs];
        return sparql;
    } else if (algebra.type == kAlgebraGraph) {
        id<SPKTree> gtree   = algebra.treeValue;
        id<GTWTerm> gterm   = gtree.value;
        NSString* lhs   = [self sparqlForAlgebra:algebra.arguments[0] isProjected:isProjected indentLevel:indentLevel+1];
        return [NSString stringWithFormat:@"%@GRAPH %@ {\n%@\n%@}\n", indent, gterm, indent, lhs];
    } else {
        // TODO: implement more coverage of Algebra types (esp. dealing with projection in subqueries)
        NSLog(@"Do not know how to serialize algebra as SPARQL: %@", algebra);
        return nil;
    }
}

+ (NSString*) sparqlForAlgebra: (id<SPKTree>) algebra {
    BOOL isProjected  = NO;
    NSString* sparql    = [self sparqlForAlgebra:algebra isProjected:&isProjected indentLevel:1];
    if (!isProjected) {
        sparql  = [NSString stringWithFormat:@"SELECT * WHERE {\n%@\n}", sparql];
    }
    
//    NSLog(@"SPARQL:\n-----------\n%@\n-------\n", sparql);
    return sparql;
}

@end

@implementation GTWQueryPlan
@end
