#import "GTWTree.h"
#import "SPARQLEngine.h"
#import "GTWVariable.h"

NSString* __strong const kUsedVariables   = @"us.kasei.sparql.variables.used";

static const char* gtw_tree_type_name ( GTWTreeType t ) {
	switch (t) {
        case PLAN_EMPTY:
            return "Empty";
		case PLAN_JOIN_IDENTITY:
			return "JoinIdentity";
		case PLAN_SCAN:
			return "Scan";
		case PLAN_BKAJOIN:
			return "BKAJoin";
		case PLAN_FEDSTUB:
			return "FedStub";
		case PLAN_NLJOIN:
			return "NLJoin";
		case PLAN_HASHJOIN:
			return "HashJoin";
		case PLAN_NLLEFTJOIN:
			return "NLLeftJoin";
		case PLAN_PROJECT:
			return "Project";
		case PLAN_FILTER:
			return "Filter";
		case PLAN_UNION:
			return "Union";
		case PLAN_EXTEND:
			return "Extend";
		case PLAN_MINUS:
			return "Minus";
		case PLAN_ORDER:
			return "Order";
		case PLAN_DISTINCT:
			return "Distinct";
		case PLAN_SLICE:
			return "Slice";
		case PLAN_DESCRIBE:
			return "Describe";
		case ALGEBRA_BGP:
			return "BGP";
		case ALGEBRA_JOIN:
			return "Join";
		case ALGEBRA_LEFTJOIN:
			return "LeftJoin";
		case ALGEBRA_FILTER:
			return "Filter";
		case ALGEBRA_UNION:
			return "Union";
		case ALGEBRA_GRAPH:
			return "Graph";
		case ALGEBRA_EXTEND:
			return "Extend";
		case ALGEBRA_MINUS:
			return "Minus";
		case ALGEBRA_ZEROLENGTHPATH:
			return "ZeroLengthPath";
		case ALGEBRA_ZEROORMOREPATH:
			return "ZeroOrMorePath";
		case ALGEBRA_ONEORMOREPATH:
			return "OneOrMorePath";
		case ALGEBRA_NEGATEDPROPERTYSET:
			return "NegatedPropertySet";
		case ALGEBRA_GROUP:
			return "Group";
		case ALGEBRA_AGGREGATION:
			return "Aggregation";
		case ALGEBRA_AGGREGATEJOIN:
			return "AggregateJoin";
		case ALGEBRA_TOLIST:
			return "ToList";
		case ALGEBRA_ORDERBY:
			return "OrderBy";
		case ALGEBRA_PROJECT:
			return "Project";
		case ALGEBRA_DISTINCT:
			return "Distinct";
		case ALGEBRA_REDUCED:
			return "Reduced";
		case ALGEBRA_SLICE:
			return "Slice";
		case ALGEBRA_TOMULTISET:
			return "ToMultiset";
		case ALGEBRA_DESCRIBE:
			return "Describe";
		case TREE_SET:
			return "set";
		case TREE_LIST:
			return "list";
		case TREE_DICTIONARY:
			return "dictionary";
		case TREE_AGGREGATE:
			return "aggregate";
		case TREE_TRIPLE:
			return "triple";
		case TREE_QUAD:
			return "quad";
		case TREE_EXPRESSION:
			return "expr";
		case TREE_NODE:
			return "node";
		case TREE_PATH:
			return "path";
		case TREE_ORDER_CONDITION:
			return "ordercondition";
		case TREE_SOLUTION_SEQUENCE:
			return "solutionsequence";
		case TREE_STRING:
			return "string";
		case EXPR_AND:
			return "EXPR_AND";
		case EXPR_OR:
			return "EXPR_OR";
		case EXPR_EQ:
			return "EXPR_EQ";
		case EXPR_NEQ:
			return "EXPR_NEQ";
		case EXPR_LT:
			return "EXPR_LT";
		case EXPR_GT:
			return "EXPR_GT";
		case EXPR_LE:
			return "EXPR_LE";
		case EXPR_GE:
			return "EXPR_GE";
		case EXPR_UMINUS:
			return "EXPR_UMINUS";
		case EXPR_PLUS:
			return "EXPR_PLUS";
		case EXPR_MINUS:
			return "EXPR_MINUS";
		case EXPR_BANG:
            return "EXPR_BANG";
		case EXPR_LITERAL:
            return "EXPR_LITERAL";
		case EXPR_FUNCTION:
            return "EXPR_FUNCTION";
		case EXPR_BOUND:
            return "EXPR_BOUND";
		case EXPR_STR:
            return "EXPR_STR";
		case EXPR_LANG:
            return "EXPR_LANG";
		case EXPR_DATATYPE:
            return "EXPR_DATATYPE";
		case EXPR_ISURI:
            return "EXPR_ISURI";
		case EXPR_ISBLANK:
            return "EXPR_ISBLANK";
		case EXPR_ISLITERAL:
            return "EXPR_ISLITERAL";
		case EXPR_CAST:
            return "EXPR_CAST";
		case EXPR_LANGMATCHES:
            return "EXPR_LANGMATCHES";
		case EXPR_REGEX:
            return "EXPR_REGEX";
		case EXPR_COUNT:
            return "EXPR_COUNT";
		case EXPR_SAMETERM:
            return "EXPR_SAMETERM";
		case EXPR_SUM:
            return "EXPR_SUM";
		case EXPR_AVG:
            return "EXPR_AVG";
		case EXPR_MIN:
            return "EXPR_MIN";
		case EXPR_MAX:
            return "EXPR_MAX";
		case EXPR_COALESCE:
            return "EXPR_COALESCE";
		case EXPR_IF:
            return "EXPR_IF";
		case EXPR_URI:
            return "EXPR_URI";
		case EXPR_IRI:
            return "EXPR_IRI";
		case EXPR_STRLANG:
            return "EXPR_STRLANG";
		case EXPR_STRDT:
            return "EXPR_STRDT";
		case EXPR_BNODE:
            return "EXPR_BNODE";
		case EXPR_GROUP_CONCAT:
            return "EXPR_GROUP_CONCAT";
		case EXPR_SAMPLE:
            return "EXPR_SAMPLE";
		case EXPR_IN:
            return "EXPR_IN";
		case EXPR_NOT_IN:
            return "EXPR_NOT_IN";
		case EXPR_ISNUMERIC:
            return "EXPR_ISNUMERIC";
		case EXPR_YEAR:
            return "EXPR_YEAR";
		case EXPR_MONTH:
            return "EXPR_MONTH";
		case EXPR_DAY:
            return "EXPR_DAY";
		case EXPR_HOURS:
            return "EXPR_HOURS";
		case EXPR_MINUTES:
            return "EXPR_MINUTES";
		case EXPR_SECONDS:
            return "EXPR_SECONDS";
		case EXPR_TIMEZONE:
            return "EXPR_TIMEZONE";
		case EXPR_CURRENT_DATETIME:
            return "EXPR_CURRENT_DATETIME";
		case EXPR_NOW:
            return "EXPR_NOW";
		case EXPR_FROM_UNIXTIME:
            return "EXPR_FROM_UNIXTIME";
		case EXPR_TO_UNIXTIME:
            return "EXPR_TO_UNIXTIME";
		case EXPR_CONCAT:
            return "EXPR_CONCAT";
		case EXPR_STRLEN:
            return "EXPR_STRLEN";
		case EXPR_SUBSTR:
            return "EXPR_SUBSTR";
		case EXPR_UCASE:
            return "EXPR_UCASE";
		case EXPR_LCASE:
            return "EXPR_LCASE";
		case EXPR_STRSTARTS:
            return "EXPR_STRSTARTS";
		case EXPR_STRENDS:
            return "EXPR_STRENDS";
		case EXPR_CONTAINS:
            return "EXPR_CONTAINS";
		case EXPR_ENCODE_FOR_URI:
            return "EXPR_ENCODE_FOR_URI";
		case EXPR_TZ:
            return "EXPR_TZ";
		case EXPR_RAND:
            return "EXPR_RAND";
		case EXPR_ABS:
            return "EXPR_ABS";
		case EXPR_ROUND:
            return "EXPR_ROUND";
		case EXPR_CEIL:
            return "EXPR_CEIL";
		case EXPR_FLOOR:
            return "EXPR_FLOOR";
		case EXPR_MD5:
            return "EXPR_MD5";
		case EXPR_SHA1:
            return "EXPR_SHA1";
		case EXPR_SHA224:
            return "EXPR_SHA224";
		case EXPR_SHA256:
            return "EXPR_SHA256";
		case EXPR_SHA384:
            return "EXPR_SHA384";
		case EXPR_SHA512:
            return "EXPR_SHA512";
		case EXPR_STRBEFORE:
            return "EXPR_STRBEFORE";
		case EXPR_STRAFTER:
            return "EXPR_STRAFTER";
		case EXPR_REPLACE:
            return "EXPR_REPLACE";
		case EXPR_UUID:
            return "EXPR_UUID";
		case EXPR_STRUUID:
            return "EXPR_STRUUID";
		default:
			return "(unknown)";
	}
}

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
        
        if (type == PLAN_HASHJOIN) {
            // PLAN_HASHJOIN's 3rd child is the list of join vars, not a subplan, so it shouldn't participate in invocation counting
            locsize--;
        }
        
        for (i = 0; i < size; i++) {
            GTWTree* n  = [args objectAtIndex:i];
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
        if (type == PLAN_HASHJOIN && size >= 3) {
            GTWTree* n	= [args objectAtIndex:2];
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
    return [NSString stringWithCString:gtw_tree_type_name(self.type) encoding:NSUTF8StringEncoding];
}

- (id) _applyBlock: (id(^)(GTWTree* node, NSUInteger level, BOOL* stop))block inOrder: (GTWTreeTraversalOrder) order level: (NSUInteger) level {
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

- (id) _applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix level: (NSUInteger) level {
    BOOL stop   = NO;
    id value    = nil;
    if (prefix) {
        value    = prefix(self, level, &stop);
        if (stop)
            return value;
    }
    
    for (GTWTree* child in self.arguments) {
        [child _applyPrefixBlock:prefix postfixBlock:postfix level:level+1];
    }
    
    if (postfix) {
        value    = postfix(self, level, &stop);
    }
    
    return value;
}

- (id) applyPrefixBlock: (GTWTreeAccessorBlock)prefix postfixBlock: (GTWTreeAccessorBlock) postfix {
    return [self _applyPrefixBlock:prefix postfixBlock:postfix level:0];
}

- (id) applyBlock: (GTWTreeAccessorBlock)block inOrder: (GTWTreeTraversalOrder) order {
    return [self _applyBlock:block inOrder:order level:0];
}

- (id) annotationForKey: (NSString*) key {
    return [self.annotations objectForKey:key];
}

- (void) computeScopeVariables {
    [self applyPrefixBlock:nil postfixBlock:^id(GTWTree *node, NSUInteger level, BOOL *stop) {
        if (node.type == TREE_NODE) {
            id<GTWTerm> term    = node.value;
            // TODO: This should be using a protocol to check if the term is a variable
            if ([term isKindOfClass:[GTWVariable class]]) {
                NSSet* set          = [NSSet setWithObject:term];
//                    NSLog(@"variables: %@ for plan: %@", set, node);
                [node.annotations setObject:set forKey:kUsedVariables];
            }
        } else if (node.type == TREE_QUAD) {
            id<Quad> q  = node.value;
            NSArray* array  = @[q.subject, q.predicate, q.object, q.graph];
            NSMutableSet* set   = [NSMutableSet set];
            for (id<GTWTerm> term in array) {
                if ([term isKindOfClass:[GTWVariable class]]) {
                    [set addObject:term];
                }
                [node.annotations setObject:set forKey:kUsedVariables];
            }
        } else {
            NSUInteger count    = [node.arguments count];
            if (count) {
                GTWTree* firstchild  = node.arguments[0];
                NSMutableSet* set   = [NSMutableSet setWithSet:[firstchild.annotations objectForKey:kUsedVariables]];
                NSUInteger i;
                for (i = 1; i < count; i++) {
                    GTWTree* nextchild  = node.arguments[i];
                    NSSet* newset  = [nextchild.annotations objectForKey:kUsedVariables];
                    if (newset) {
                        [set unionSet:newset];
                    }
                }
                if (node.value && [node.value isKindOfClass:[GTWTree class]]) {
                    GTWTree* tree   = node.value;
                    [tree computeScopeVariables];
                    NSSet* newset  = [tree.annotations objectForKey:kUsedVariables];
                    if (newset) {
                        [set unionSet:newset];
                    }
                }
                
                [node.annotations setObject:set forKey:kUsedVariables];
            }
        }
        return nil;
    }];
}

- (BOOL) isExpression {
    switch (self.type) {
        case EXPR_AND:
        case EXPR_OR:
        case EXPR_EQ:
        case EXPR_NEQ:
        case EXPR_LT:
        case EXPR_GT:
        case EXPR_LE:
        case EXPR_GE:
        case EXPR_UMINUS:
        case EXPR_PLUS:
        case EXPR_MINUS:
        case EXPR_BANG:
        case EXPR_LITERAL:
        case EXPR_FUNCTION:
        case EXPR_BOUND:
        case EXPR_STR:
        case EXPR_LANG:
        case EXPR_DATATYPE:
        case EXPR_ISURI:
        case EXPR_ISBLANK:
        case EXPR_ISLITERAL:
        case EXPR_CAST:
        case EXPR_LANGMATCHES:
        case EXPR_REGEX:
        case EXPR_COUNT:
        case EXPR_SAMETERM:
        case EXPR_SUM:
        case EXPR_AVG:
        case EXPR_MIN:
        case EXPR_MAX:
        case EXPR_COALESCE:
        case EXPR_IF:
        case EXPR_URI:
        case EXPR_IRI:
        case EXPR_STRLANG:
        case EXPR_STRDT:
        case EXPR_BNODE:
        case EXPR_GROUP_CONCAT:
        case EXPR_SAMPLE:
        case EXPR_IN:
        case EXPR_NOT_IN:
        case EXPR_ISNUMERIC:
        case EXPR_YEAR:
        case EXPR_MONTH:
        case EXPR_DAY:
        case EXPR_HOURS:
        case EXPR_MINUTES:
        case EXPR_SECONDS:
        case EXPR_TIMEZONE:
        case EXPR_CURRENT_DATETIME:
        case EXPR_NOW:
        case EXPR_FROM_UNIXTIME:
        case EXPR_TO_UNIXTIME:
        case EXPR_CONCAT:
        case EXPR_STRLEN:
        case EXPR_SUBSTR:
        case EXPR_UCASE:
        case EXPR_LCASE:
        case EXPR_STRSTARTS:
        case EXPR_STRENDS:
        case EXPR_CONTAINS:
        case EXPR_ENCODE_FOR_URI:
        case EXPR_TZ:
        case EXPR_RAND:
        case EXPR_ABS:
        case EXPR_ROUND:
        case EXPR_CEIL:
        case EXPR_FLOOR:
        case EXPR_MD5:
        case EXPR_SHA1:
        case EXPR_SHA224:
        case EXPR_SHA256:
        case EXPR_SHA384:
        case EXPR_SHA512:
        case EXPR_STRBEFORE:
        case EXPR_STRAFTER:
        case EXPR_REPLACE:
        case EXPR_UUID:
        case EXPR_STRUUID:
            return YES;
        default:
            return NO;
    }
}

- (NSString*) conciseDescription {
    NSMutableString* s = [NSMutableString string];
    GTWTree* node = self;
    if (node.leaf) {
        [s appendFormat: @"%s(", gtw_tree_type_name(node.type)];
        if (node.value) {
            [s appendFormat:@"%@", node.value];
        }
        if (node.ptr) {
            [s appendFormat:@"<%p>", node.ptr];
        }
        [s appendString:@")"];
    } else {
        [s appendFormat: @"%s", gtw_tree_type_name(node.type)];
        if (node.value) {
            [s appendFormat:@"[%@]", node.value];
        }
        int i;
        [s appendString:@"("];
        NSUInteger count    = [node.arguments count];
        if (count > 0) {
            [s appendFormat:@"%@", [node.arguments[0] conciseDescription]];
            for (i = 1; i < count; i++) {
                [s appendFormat:@", %@", [node.arguments[0] conciseDescription]];
            }
        }
        [s appendString:@")"];
    }
    return s;
}

- (NSString*) longDescription {
    NSMutableString* s = [NSMutableString string];
    [self applyPrefixBlock:^id(GTWTree *node, NSUInteger level, BOOL *stop) {
        NSMutableString* indent = [NSMutableString string];
        for (NSUInteger i = 0; i < level; i++) {
            [indent appendFormat:@"  "];
        }
        //        [s appendFormat: @"%@%s\n", indent, gtw_tree_type_name(node.type)];
        if (node.leaf) {
            [s appendFormat: @"%@%s", indent, gtw_tree_type_name(node.type)];
            if (node.value) {
                [s appendFormat:@" %@", node.value];
            }
            if (node.ptr) {
                [s appendFormat:@"<%p>", node.ptr];
            }
            [s appendFormat:@"\n"];
        } else {
            [s appendFormat: @"%@%s", indent, gtw_tree_type_name(node.type)];
            if (node.value) {
                if ([node isKindOfClass:[GTWTree class]]) {
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
    if ([self isExpression]) {
        return [self conciseDescription];
    } else {
        return [self longDescription];
    }
}

@end
