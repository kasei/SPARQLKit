#import "GTWTree.h"

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
		default:
			return "(unknown)";
	}
}

@implementation GTWTree

- (GTWTree*) initWithType: (GTWTreeType) type pointer: (void*) ptr arguments: (NSArray*) args {
    if (self = [self init]) {
        int i;
        self.type   = type;
        self.ptr	= ptr;
        self.annotation = NULL;
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
            
            if (type == TREE_NODE || type == TREE_TRIPLE || type == TREE_QUAD || type == TREE_EXPRESSION) {
                
            } else {
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
            }
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

- (NSString*) descriptionWithIndentLevel: (NSUInteger) level {
    NSMutableString* indent = [NSMutableString string];
    int i;
    for (i = 0; i < level; i++) {
        [indent appendString:@"  "];
    }
    BOOL inLine = NO;
    NSString* newline   = @"\n";
    if ([self.arguments count] == 0 || self.type == TREE_QUAD || self.type == TREE_TRIPLE || self.type == TREE_NODE) {
        inLine  = YES;
        newline = @" ";
    }
    NSMutableString* s  = [NSMutableString stringWithFormat:@"%@%s%@", indent, gtw_tree_type_name(self.type), newline];
    for (id o in self.arguments) {
        if ([o isKindOfClass:[GTWTree class]]) {
            [s appendFormat:@"%@%@", (inLine ? @"" : indent), [o descriptionWithIndentLevel:level+1]];
        } else {
            [s appendFormat:@"%@%@\n", (inLine ? @"" : indent), o];
        }
    }
    return s;
}

- (NSString*) description {
    return [self descriptionWithIndentLevel:0];
}

@end
