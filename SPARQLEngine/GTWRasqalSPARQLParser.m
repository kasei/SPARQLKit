// TODO: TREE_NODE should keep id<GTWTerm> objects in the arguments array and not the void* ptr field.

#import "GTWRasqalSPARQLParser.h"
#import "GTWBlank.h"
#import "GTWIRI.h"
#import "GTWLiteral.h"
#import "GTWTriple.h"
#import "GTWVariable.h"

static int _fix_leftjoin ( rasqal_world* rasqal_world_ptr, GTWTree* c, NSMutableArray* array, int* size ) {
    //	fprintf(stderr, "attempting fix on %s\n", gtw_tree_name(c));
    //	gtw_tree_print(c, stderr);
    GTWTreeType type    = c.type;
//	gtw_tree_type type	= gtw_tree_node_type(c);
	if ((type == kAlgebraLeftJoin || type == kAlgebraMinus) && [c.arguments count] == 1) {
		//		fprintf(stderr, "fixing %s\n", algebra_name(c));
//        GTWTree *tmp;
        GTWTree *lhs, *rhs;
        rhs = c.arguments[0];
//		gtw_tree_node* tmp;
//		gtw_tree_node* lhs;
//		gtw_tree_node* rhs	= tree_child(c, 0);
		if (*size == 0) {
            lhs = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:@[]];
//			lhs	= gtw_new_tree(ALGEBRA_BGP, NULL, 0, NULL);
		} else {
			(*size)--;
			lhs	= array[*size];
			array[*size]	= NULL;
		}
		
		if (type == kAlgebraLeftJoin) {
//            GTWTree* e;
//			if (rhs.type == ALGEBRA_FILTER) {
//				e	= [rhs.arguments objectAtIndex:0];
////                tree_child(rhs, 0);
//                tmp = [rhs.arguments objectAtIndex:1];
////				tmp	= tree_child(rhs, 1);
////				gtw_free_tree(rhs);
//				rhs	= tmp;
//			} else {
//				rasqal_literal* true		= rasqal_new_typed_literal(rasqal_world_ptr, RASQAL_LITERAL_BOOLEAN, (const unsigned char*) "true");
//				rasqal_expression* expr		= rasqal_new_literal_expression(rasqal_world_ptr, true);
//				e	= gtw_new_tree_va(TREE_EXPRESSION, rasqal_new_expression_from_expression(expr), 0);
//			}
//			array[(*size)++]	= gtw_new_tree_va(type, NULL, 3, lhs, rhs, e);
            // TODO: this should include the filter expression
            array[(*size)++]    = [[GTWTree alloc] initWithType:type arguments:@[lhs, rhs]];
            
		} else {
            array[(*size)++]    = [[GTWTree alloc] initWithType:type arguments:@[lhs, rhs]];
//			array[(*size)++]	= gtw_new_tree_va(type, NULL, 2, lhs, rhs);
		}
		return 1;
	} else {
		return 0;
	}
}

id<GTWTerm> rasqal_literal_to_object (rasqal_literal* l) {
	rasqal_variable* v;
	raptor_uri* dt;
	//	rasqal_literal_print(l, fh);
	switch (l->type) {
		case RASQAL_LITERAL_BLANK:
            //			fprintf(fh, "%s\n", rasqal_literal_as_string(l));
            return [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"%s", rasqal_literal_as_string(l)]];
			break;
		case RASQAL_LITERAL_URI:
			//			fprintf(fh, "<%s>\n", rasqal_literal_as_string(l));
            return [[GTWIRI alloc] initWithIRI:[NSString stringWithFormat:@"%s", rasqal_literal_as_string(l)]];
			break;
		case RASQAL_LITERAL_STRING:
		case RASQAL_LITERAL_XSD_STRING:
		case RASQAL_LITERAL_BOOLEAN:
		case RASQAL_LITERAL_INTEGER:
		case RASQAL_LITERAL_FLOAT:
		case RASQAL_LITERAL_DOUBLE:
		case RASQAL_LITERAL_DECIMAL:
		case RASQAL_LITERAL_DATETIME:
		case RASQAL_LITERAL_UDT:
		case RASQAL_LITERAL_PATTERN:
		case RASQAL_LITERAL_QNAME:
			dt	= rasqal_literal_datatype(l);
            //			fprintf(fh, "\"%s\"", rasqal_literal_as_string(l));
			if (dt) {
                //				fprintf(stderr, "^^<%s>\n", raptor_uri_as_string(dt));
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%s", rasqal_literal_as_string(l)] datatype:[NSString stringWithFormat:@"%s", raptor_uri_as_string(dt)]];
			} else if (l->language) {
                //				fprintf(fh, "@%s\n", l->language);
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%s", rasqal_literal_as_string(l)] language:[NSString stringWithFormat:@"%s", l->language]];
			} else {
                //				fprintf(fh, "\n");
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%s", rasqal_literal_as_string(l)]];
			}
			break;
		case RASQAL_LITERAL_VARIABLE:
			v	= rasqal_literal_as_variable(l);
//			fprintf(stderr, "?%s\n", v->name);
            return [[GTWVariable alloc] initWithName:[NSString stringWithFormat:@"%s", v->name]];
//			return gtw_new_term(NODE_TYPE_VARIABLE, (const char*) v->name, NULL, NULL);
			break;
		default:
            //			fprintf(fh, "(unknown type %d)\n", rasqal_literal_get_rdf_term_type(l));
			return NULL;
			break;
	};
}

static GTWTreeType rasqal_op_type_to_tree_type ( rasqal_op type ) {
    switch (type) {
        case RASQAL_EXPR_AND:
            return kExprAnd;
        case RASQAL_EXPR_OR:
            return kExprOr;
        case RASQAL_EXPR_EQ:
            return kExprEq;
        case RASQAL_EXPR_NEQ:
            return kExprNeq;
        case RASQAL_EXPR_LT:
            return kExprLt;
        case RASQAL_EXPR_GT:
            return kExprGt;
        case RASQAL_EXPR_LE:
            return kExprLe;
        case RASQAL_EXPR_GE:
            return kExprGe;
        case RASQAL_EXPR_UMINUS:
            return kExprUMinus;
        case RASQAL_EXPR_PLUS:
            return kExprPlus;
        case RASQAL_EXPR_MINUS:
            return kExprMinus;
		case RASQAL_EXPR_BANG:
            return kExprBang;
		case RASQAL_EXPR_LITERAL:
            return kExprLiteral;
		case RASQAL_EXPR_FUNCTION:
            return kExprFunction;
		case RASQAL_EXPR_BOUND:
            return kExprBound;
		case RASQAL_EXPR_STR:
            return kExprStr;
		case RASQAL_EXPR_LANG:
            return kExprLang;
		case RASQAL_EXPR_DATATYPE:
            return kExprDatatype;
		case RASQAL_EXPR_ISURI:
            return kExprIsURI;
		case RASQAL_EXPR_ISBLANK:
            return kExprIsBlank;
		case RASQAL_EXPR_ISLITERAL:
            return kExprIsLiteral;
		case RASQAL_EXPR_CAST:
            return kExprCast;
		case RASQAL_EXPR_LANGMATCHES:
            return kExprLangMatches;
		case RASQAL_EXPR_REGEX:
            return kExprRegex;
		case RASQAL_EXPR_COUNT:
            return kExprCount;
		case RASQAL_EXPR_SAMETERM:
            return kExprSameTerm;
		case RASQAL_EXPR_SUM:
            return kExprSum;
		case RASQAL_EXPR_AVG:
            return kExprAvg;
		case RASQAL_EXPR_MIN:
            return kExprMin;
		case RASQAL_EXPR_MAX:
            return kExprMax;
		case RASQAL_EXPR_COALESCE:
            return kExprCoalesce;
		case RASQAL_EXPR_IF:
            return kExprIf;
		case RASQAL_EXPR_URI:
            return kExprURI;
		case RASQAL_EXPR_IRI:
            return kExprIRI;
		case RASQAL_EXPR_STRLANG:
            return kExprStrLang;
		case RASQAL_EXPR_STRDT:
            return kExprStrDT;
		case RASQAL_EXPR_BNODE:
            return kExprBNode;
		case RASQAL_EXPR_GROUP_CONCAT:
            return kExprGroupConcat;
		case RASQAL_EXPR_SAMPLE:
            return kExprSample;
		case RASQAL_EXPR_IN:
            return kExprIn;
		case RASQAL_EXPR_NOT_IN:
            return kExprNotIn;
		case RASQAL_EXPR_ISNUMERIC:
            return kExprIsNumeric;
		case RASQAL_EXPR_YEAR:
            return kExprYear;
		case RASQAL_EXPR_MONTH:
            return kExprMonth;
		case RASQAL_EXPR_DAY:
            return kExprDay;
		case RASQAL_EXPR_HOURS:
            return kExprHours;
		case RASQAL_EXPR_MINUTES:
            return kExprMinutes;
		case RASQAL_EXPR_SECONDS:
            return kExprSeconds;
		case RASQAL_EXPR_TIMEZONE:
            return kExprTimeZone;
		case RASQAL_EXPR_CURRENT_DATETIME:
            return kExprCurrentDatetime;
		case RASQAL_EXPR_NOW:
            return kExprNow;
		case RASQAL_EXPR_FROM_UNIXTIME:
            return kExprFromUnixTime;
		case RASQAL_EXPR_TO_UNIXTIME:
            return kExprToUnixTime;
		case RASQAL_EXPR_CONCAT:
            return kExprConcat;
		case RASQAL_EXPR_STRLEN:
            return kExprStrLen;
		case RASQAL_EXPR_SUBSTR:
            return kExprSubStr;
		case RASQAL_EXPR_UCASE:
            return kExprUCase;
		case RASQAL_EXPR_LCASE:
            return kExprLCase;
		case RASQAL_EXPR_STRSTARTS:
            return kExprStrStarts;
		case RASQAL_EXPR_STRENDS:
            return kExprStrEnds;
		case RASQAL_EXPR_CONTAINS:
            return kExprContains;
		case RASQAL_EXPR_ENCODE_FOR_URI:
            return kExprEncodeForURI;
		case RASQAL_EXPR_TZ:
            return kExprTZ;
		case RASQAL_EXPR_RAND:
            return kExprRand;
		case RASQAL_EXPR_ABS:
            return kExprAbs;
		case RASQAL_EXPR_ROUND:
            return kExprRound;
		case RASQAL_EXPR_CEIL:
            return kExprCeil;
		case RASQAL_EXPR_FLOOR:
            return kExprFloor;
		case RASQAL_EXPR_MD5:
            return kExprMD5;
		case RASQAL_EXPR_SHA1:
            return kExprSHA1;
		case RASQAL_EXPR_SHA224:
            return kExprSHA224;
		case RASQAL_EXPR_SHA256:
            return kExprSHA256;
		case RASQAL_EXPR_SHA384:
            return kExprSHA384;
		case RASQAL_EXPR_SHA512:
            return kExprSHA512;
		case RASQAL_EXPR_STRBEFORE:
            return kExprStrBefore;
		case RASQAL_EXPR_STRAFTER:
            return kExprStrAfter;
		case RASQAL_EXPR_REPLACE:
            return kExprReplace;
		case RASQAL_EXPR_UUID:
            return kExprUUID;
		case RASQAL_EXPR_STRUUID:
            return kExprStrUUID;
        default:
            NSLog(@"unknown rasqal type: %s", rasqal_expression_op_label(type));
            return 0;
    }
}

static GTWTree* rasqal_expression_to_tree ( rasqal_expression* expr ) {
//    fprintf( stderr, "expression op: %s\n", rasqal_expression_op_label(expr->op) );
    id<GTWTerm> term;
    GTWTreeType ttype   = rasqal_op_type_to_tree_type(expr->op);
    switch (expr->op) {
        // 0-ary
        case RASQAL_EXPR_NOW:
        case RASQAL_EXPR_RAND:
        case RASQAL_EXPR_UUID:
        case RASQAL_EXPR_STRUUID:
            return [[GTWTree alloc] initLeafWithType:ttype value:nil pointer:NULL];
        // 1-ary
        case RASQAL_EXPR_UMINUS:
        case RASQAL_EXPR_BANG:
        case RASQAL_EXPR_BOUND:
        case RASQAL_EXPR_STR:
        case RASQAL_EXPR_LANG:
        case RASQAL_EXPR_DATATYPE:
        case RASQAL_EXPR_ISURI:
        case RASQAL_EXPR_ISBLANK:
        case RASQAL_EXPR_ISLITERAL:
        case RASQAL_EXPR_URI:
        case RASQAL_EXPR_IRI:
        case RASQAL_EXPR_ISNUMERIC:
        case RASQAL_EXPR_YEAR:
        case RASQAL_EXPR_MONTH:
        case RASQAL_EXPR_DAY:
        case RASQAL_EXPR_HOURS:
        case RASQAL_EXPR_MINUTES:
        case RASQAL_EXPR_SECONDS:
        case RASQAL_EXPR_TIMEZONE:
        case RASQAL_EXPR_TZ:
        case RASQAL_EXPR_STRLEN:
        case RASQAL_EXPR_UCASE:
        case RASQAL_EXPR_LCASE:
        case RASQAL_EXPR_ENCODE_FOR_URI:
        case RASQAL_EXPR_ABS:
        case RASQAL_EXPR_ROUND:
        case RASQAL_EXPR_CEIL:
        case RASQAL_EXPR_FLOOR:
        case RASQAL_EXPR_MD5:
        case RASQAL_EXPR_SHA1:
        case RASQAL_EXPR_SHA224:
        case RASQAL_EXPR_SHA256:
        case RASQAL_EXPR_SHA384:
        case RASQAL_EXPR_SHA512:
            return [[GTWTree alloc] initWithType:ttype arguments:@[rasqal_expression_to_tree(expr->arg1)]];
        // 2-ary
        case RASQAL_EXPR_EQ:
        case RASQAL_EXPR_NEQ:
        case RASQAL_EXPR_LT:
        case RASQAL_EXPR_GT:
        case RASQAL_EXPR_LE:
        case RASQAL_EXPR_GE:
        case RASQAL_EXPR_MINUS:
        case RASQAL_EXPR_PLUS:
        case RASQAL_EXPR_OR:
        case RASQAL_EXPR_AND:
        case RASQAL_EXPR_LANGMATCHES:
        case RASQAL_EXPR_SAMETERM:
        case RASQAL_EXPR_STRLANG:
        case RASQAL_EXPR_STRDT:
        case RASQAL_EXPR_STRSTARTS:
        case RASQAL_EXPR_STRENDS:
        case RASQAL_EXPR_CONTAINS:
        case RASQAL_EXPR_STRBEFORE:
        case RASQAL_EXPR_STRAFTER:
            return [[GTWTree alloc] initWithType:ttype arguments:@[rasqal_expression_to_tree(expr->arg1), rasqal_expression_to_tree(expr->arg2)]];
        // other
        case RASQAL_EXPR_LITERAL:
            term    = rasqal_literal_to_object(expr->literal);
            return [[GTWTree alloc] initLeafWithType:kTreeNode value:term pointer:NULL];
        case RASQAL_EXPR_BNODE:
        case RASQAL_EXPR_REGEX:
        case RASQAL_EXPR_SUBSTR:
        case RASQAL_EXPR_FUNCTION:
        case RASQAL_EXPR_REPLACE:
        case RASQAL_EXPR_COALESCE:
        case RASQAL_EXPR_CONCAT:
        case RASQAL_EXPR_COUNT:
        case RASQAL_EXPR_SUM:
        case RASQAL_EXPR_AVG:
        case RASQAL_EXPR_MIN:
        case RASQAL_EXPR_MAX:
        case RASQAL_EXPR_SAMPLE:
        case RASQAL_EXPR_GROUP_CONCAT:
        case RASQAL_EXPR_CAST:
        case RASQAL_EXPR_IF:
        case RASQAL_EXPR_IN:
        case RASQAL_EXPR_NOT_IN:
        case RASQAL_EXPR_CURRENT_DATETIME:
        case RASQAL_EXPR_FROM_UNIXTIME:
        case RASQAL_EXPR_TO_UNIXTIME:
        default:
            // TODO
            fprintf(stderr, "*** don't know how to convert this op: %s\n", rasqal_expression_op_label(expr->op));
            break;
    }
    return nil;
}


static void
roqet_query_write_variable(FILE* fh, rasqal_variable* v)
{
	fputs((const char*)v->name, fh);
	if(v->expression) {
		fputc('=', fh);
		rasqal_expression_print(v->expression, fh);
	}
}

static GTWTree* roqet_graph_pattern_walk(rasqal_world* rasqal_world_ptr, rasqal_graph_pattern *gp, int gp_index, FILE *fh) {
	//	fprintf(stderr, "(\n");
	int triple_index = 0;
	rasqal_graph_pattern_operator op;
	raptor_sequence *seq;
	//	int idx;
	rasqal_expression* expr;
	rasqal_variable* var;
	rasqal_literal* literal;
	
	op = rasqal_graph_pattern_get_operator(gp);
	
	//	fprintf(fh, "%s graph pattern",  rasqal_graph_pattern_operator_as_string(op));
	//	idx = rasqal_graph_pattern_get_index(gp);
	
	//	if(idx >= 0)
	//		fprintf(fh, "[%d]", idx);
	
	//	if(gp_index >= 0)
	//		fprintf(fh, " #%d", gp_index);
	//	fputs(" {\n", fh);
	
	/* look for LET variable and value */
	var = rasqal_graph_pattern_get_variable(gp);
	if(var) {
		fprintf(stderr, "bind\n");
		fprintf(fh, "%s := ", var->name);
		fprintf(stderr, "(expression : %p)\n", (void*) var->expression);
		rasqal_expression_print(var->expression, fh);
	}
	
	/* look for SERVICE literal */
	literal = rasqal_graph_pattern_get_service(gp);
	if(literal) {
		fprintf(stderr, "service\n");
		// @@ SERVICE not handled yet
	}
	
	/* look for triples */
	while(1) {
		rasqal_triple* t = rasqal_graph_pattern_get_triple(gp, triple_index);
		if(!t)
			break;
		
		//		if(!seen) {
		//			fputs("triples {\n", fh);
		//			seen = 1;
		//		}
		//		fprintf(fh, "triple #%d { ", triple_index);
		//		fputs(" }\n", fh);
		triple_index++;
	}
	
	GTWTree* a	= nil;
	if(triple_index) {
		//		fprintf(stderr, "bgp\n");
		int i;
        NSMutableArray* triples = [NSMutableArray arrayWithCapacity:triple_index];
		for (i = 0; i < triple_index; i++) {
			rasqal_triple* t = rasqal_graph_pattern_get_triple(gp, i);
			if(!t)
				break;
			
			id<GTWTerm> s	= rasqal_literal_to_object(t->subject);
			id<GTWTerm> p	= rasqal_literal_to_object(t->predicate);
			id<GTWTerm> o	= rasqal_literal_to_object(t->object);
			
//            NSLog(@"triple: %@ %@ %@", s, p, o);
            
            id<GTWTriple> triple   = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
			triples[i]          = [[GTWTree alloc] initLeafWithType:kTreeTriple value: triple pointer:NULL];
		}
		//		fprintf(fh, "bgp\t%d\n", triple_index);
        a   = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:triples];
	}
	
	/* look for sub-graph patterns */
	seq = rasqal_graph_pattern_get_sub_graph_pattern_sequence(gp);
	int size	= seq ? raptor_sequence_size(seq) : -1;
	//	fprintf(stderr, "seq size %d\n", size);
	if (seq && size > 0) {
		int i;
		gp_index = 0;
        NSMutableArray* children    = [NSMutableArray arrayWithCapacity:size];
//		for (i = 0; i < size; i++)
//			children[i]	= NULL;
		while(1) {
			rasqal_graph_pattern* sgp;
			sgp = rasqal_graph_pattern_get_sub_graph_pattern(gp, gp_index);
			if(!sgp) {
//				children[gp_index]	= NULL;
				break;
			}
			
            [children addObject:roqet_graph_pattern_walk(rasqal_world_ptr, sgp, gp_index, fh)];
//			children[gp_index]	= roqet_graph_pattern_walk(rasqal_world_ptr, sgp, gp_index, fh);
			
            //			fprintf(stderr, "Pattern child #%d:\n", gp_index);
            //			gtw_tree_print(children[gp_index], stderr);
			
			if (!children[gp_index]) {
				return NULL;
			}
			gp_index++;
		}
		
//		size	= gp_index;
        size    = (int) [children count];
		if (op == RASQAL_GRAPH_PATTERN_OPERATOR_UNION) {
			//			fprintf(stderr, "union\n");
			//			fprintf(fh, "union\t%d\n", gp_index);
            a   = [[GTWTree alloc] initWithType:kAlgebraUnion arguments:children];
		} else if (op == RASQAL_GRAPH_PATTERN_OPERATOR_OPTIONAL) {
			//			fprintf(stderr, "optional\n");
			//			fprintf(fh, "optional\t%d\n", gp_index);
			//			fprintf(stderr, "LeftJoin size %d\n", size);
            a   = [[GTWTree alloc] initWithType:kAlgebraLeftJoin arguments:@[children[0]]];
		} else if (op == RASQAL_GRAPH_PATTERN_OPERATOR_MINUS) {
			//			fprintf(stderr, "minus\n");
            a   = [[GTWTree alloc] initWithType:kAlgebraMinus arguments:@[children[0]]];
		} else if (size > 0) {
			//			fprintf(stderr, "group\n");
			//			fprintf(fh, "group\t%d\n", gp_index);
			//			fprintf(stderr, "Group size %d\n", size);
			NSMutableArray* children2    = [NSMutableArray arrayWithCapacity:size];
//			gtw_tree_node** children2	= (gtw_tree_node**) alloca(size*sizeof(gtw_tree_node*));
			int size2					= 0;
			for (i = 0; i < size; i++) {
                GTWTree* c  = children[i];
//				gtw_tree_node* c	= children[i];
				if (_fix_leftjoin(rasqal_world_ptr, c, children2, &size2)) {
				} else if (c.type == kAlgebraFilter && [c.arguments count] == 0) {
					GTWTree* pat;
					if (size2 == 0) {
                        pat = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:@[]];
//						pat	= gtw_new_tree(ALGEBRA_BGP, NULL, 0, NULL);
					} else {
						size2--;
						pat	= children2[size2];
                        [children2 removeObject:pat];
//						children2[size2]	= NULL;
					}
//					children2[size2++]	= gtw_new_tree_va(ALGEBRA_FILTER, NULL, 2, gtw_tree_copy(tree_child(c,0)), pat);
                    //					gtw_free_tree(c);
                    
                    GTWTree* expr       = c.value;
//                    NSLog(@"FILTER expression: %@", expr);
                    
                    if (expr) {
                        children2[size2++]  = [[GTWTree alloc] initWithType:kAlgebraFilter value: expr arguments:@[pat]];
                    } else {
                        NSLog(@"Failed to construct filter expression tree");
                        children2[size2++]  = pat;
                    }
				} else {
					children2[size2++]	= c;
				}
			}
			
			// @@ don't produce groups here. instead, produce joins.
			if (size2 == 0) {
                a   = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:@[]];
//				a	= gtw_new_tree(ALGEBRA_BGP, NULL, 0, NULL);
			} else if (size2 == 1) {
				a	= children2[0];
			} else {
				a	= children2[0];
				for (i = 1; i < size2; i++) {
                    a   = [[GTWTree alloc] initWithType:kAlgebraJoin arguments:@[a, children2[i]]];
//					a	= gtw_new_tree_va(ALGEBRA_JOIN, NULL, 2, a, children2[i]);
				}
			}
			
			//			free(children2);
		}
	}
	
	
	/* look for filter */
	expr = rasqal_graph_pattern_get_filter_expression(gp);
	if (expr) {
        //		fprintf(stderr, "filter\n");
        //		rasqal_expression_print(expr, stderr);
        
        GTWTree* expression = rasqal_expression_to_tree(expr);
//        GTWTree* e  = [[GTWTree alloc] initLeafWithType:TREE_EXPRESSION value: nil pointer:rasqal_new_expression_from_expression(expr)];
//		gtw_tree_node* e	= gtw_new_tree_va(TREE_EXPRESSION, rasqal_new_expression_from_expression(expr), 0);
        a   = [[GTWTree alloc] initWithType:kAlgebraFilter value: expression arguments:@[]];
//		a	= gtw_new_tree_va(ALGEBRA_FILTER, NULL, 1, e);
		if (!a) {
			return NULL;
		}
	}
	
	
	//	fprintf(stderr, ")\n");
	
	if (!a) {
        a   = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:@[]];
//		a	= gtw_new_tree(ALGEBRA_BGP, NULL, 0, NULL);
	}
	
	
	/* look for GRAPH literal */
	literal = rasqal_graph_pattern_get_origin(gp);
	if(literal) {
        id<GTWTerm> t   = rasqal_literal_to_object(literal);
//		gtw_term* t	= rasqal_literal_to_term(literal);
//		gtw_node* n	= gtw_new_node(NODE_NULL, t);
//		gtw_free_term(t);
        GTWTree* g  = [[GTWTree alloc] initLeafWithType:kTreeNode value: t pointer:NULL];
//		gtw_tree_node* g	= gtw_new_tree_va(TREE_NODE, n, 0);
        a   = [[GTWTree alloc] initWithType:kAlgebraGraph arguments:@[g, a]];
//		a	= gtw_new_tree_va(ALGEBRA_GRAPH, NULL, 2, g, a);
	}
	
	return a;
}

static GTWTree* roqet_query_walk(rasqal_world* rasqal_world_ptr, raptor_world* raptor_world_ptr, rasqal_query *rq, FILE *fh) {
	int i;
	rasqal_graph_pattern* gp;
	raptor_sequence *seq;
	
	
	gp = rasqal_query_get_query_graph_pattern(rq);
	if(!gp)
		return NULL;
	
	if (0) {
		/* look for binding rows */
		seq = rasqal_query_get_bindings_variables_sequence(rq);
		if(seq) {
			fprintf(fh, "bindings variables (%d): ",	raptor_sequence_size(seq));
			
			i = 0;
			while(1) {
				rasqal_variable* v = rasqal_query_get_bindings_variable(rq, i);
				if(!v)
					break;
				
				if(i > 0)
					fputs(", ", fh);
				
				roqet_query_write_variable(fh, v);
				i++;
			}
			fputc('\n', fh);
			
			seq = rasqal_query_get_bindings_rows_sequence(rq);
			
			fprintf(fh, "bindings rows (%d) {\n", raptor_sequence_size(seq));
			i = 0;
			while(1) {
				rasqal_row* row;
				
				row = rasqal_query_get_bindings_row(rq, i);
				if(!row)
					break;
				
				fprintf(fh, "row #%d { ", i);
				//@@ rasqal_row_print(row, fh);
				fputs("}\n", fh);
				
				i++;
			}
		}
	}
	
	GTWTree* a	= roqet_graph_pattern_walk(rasqal_world_ptr, gp, -1, fh);
	if (!a) {
		return NULL;
	}
	
	
    // TODO: re-implement this
//	{
//		// if the outermost pattern is an OPTIONAL or MINUS,
//		// it needs to be 'fixed' to be in the proper algebra form
//		int j	= 0;
//		_fix_leftjoin(rasqal_world_ptr, a, &a, &j);
//	}
    
	{
		raptor_sequence* order	= rasqal_query_get_order_conditions_sequence(rq);
		int osize	= order ? raptor_sequence_size(order) : -1;
		if (order && osize > 0) {
            NSMutableArray* vars    = [NSMutableArray arrayWithCapacity:osize];
//			gtw_tree_node** vars	= (gtw_tree_node**) alloca(sizeof(gtw_tree_node*) * osize);
			for (i = 0; i < osize; i++) {
//                NSLog(@"array: %@", vars);
				rasqal_expression* e	= raptor_sequence_get_at(order, i);
				int order	= 0;
				if (e->op == RASQAL_EXPR_ORDER_COND_ASC) {
					order	= 1;
					e	= e->arg1;
				} else if (e->op == RASQAL_EXPR_ORDER_COND_DESC) {
					order	= -1;
					e	= e->arg1;
				} else {
                    NSLog(@"unexpected order direction expression = %s\n", rasqal_expression_op_label(e->op));
//					fprintf(stderr, "*** unexpected order direction expression = %s\n", rasqal_expression_op_label(e->op));
//					gtw_error_trap();
				}
				
				if (e->op == RASQAL_EXPR_LITERAL) {
					rasqal_literal* l		= e->literal;
                    id<GTWTerm> t   = rasqal_literal_to_object(l);
                    [vars addObject:[[GTWTree alloc] initLeafWithType:kTreeNode value: t pointer:NULL]];
                    [vars addObject:[[GTWTree alloc] initLeafWithType:kTreeNode value: [GTWLiteral integerLiteralWithValue:order] pointer:NULL]];
				} else {
                    NSLog(@"ORDERing by non-literal not implemented yet");
                    NSLog(@"order expression = %s\n", rasqal_expression_op_label(e->op));
//					fprintf(stderr, "*** ORDERing by non-literal not implemented yet\n");
//					fprintf(stderr, "    order expression = %s\n", rasqal_expression_op_label(e->op));
//					gtw_error_trap();
				}
			}
            
            GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:vars];
//			gtw_tree_node* vlist	= gtw_new_tree(kTreeList, NULL, osize, vars);
            a   = [[GTWTree alloc] initWithType:kAlgebraOrderBy value: vlist arguments:@[a]];
//			a	= gtw_new_tree_va(ALGEBRA_ORDERBY, NULL, 2, a, vlist);
		}
	}
	
	{
		seq = rasqal_query_get_bound_variable_sequence(rq);
		int psize	= seq ? raptor_sequence_size(seq) : -1;
		if(seq && psize > 0) {
            NSMutableArray* vars    = [NSMutableArray arrayWithCapacity:psize];
//			gtw_tree_node** vars	= (gtw_tree_node**) alloca(sizeof(gtw_tree_node*) * psize);
			i = 0;
			while(1) {
				rasqal_variable* v = (rasqal_variable*)raptor_sequence_get_at(seq, i);
				if(!v)
					break;
                id<GTWTerm> t   = [[GTWVariable alloc] initWithName:[NSString stringWithFormat:@"%s", v->name]];
                GTWTree* var = [[GTWTree alloc] initLeafWithType:kTreeNode value: t pointer:NULL];
                vars[i]         = var;
//				gtw_term* t	= gtw_new_term(NODE_TYPE_VARIABLE, (const char*) v->name, NULL, NULL);
//				vars[i]	= gtw_new_tree_va(kTreeNode, gtw_new_node(NODE_NULL, t), 0);
//				gtw_free_term(t);
                
                // TODO: re-implement
				if(v->expression) {
//					gtw_tree_node* expr	= gtw_new_tree_va(TREE_EXPRESSION, rasqal_new_expression_from_expression(v->expression), 0);
//					a	= gtw_new_tree_va(ALGEBRA_EXTEND, NULL, 3, a, gtw_new_tree_va(kTreeNode, gtw_new_node(NODE_NULL, gtw_new_term(NODE_TYPE_VARIABLE, (const char*) v->name, NULL, NULL)), 0), expr);
				}
				i++;
			}
            GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:vars];
//			gtw_tree_node* vlist	= gtw_new_tree(kTreeList, NULL, psize, vars);
			//		fprintf(fh, "project\t%d\n", raptor_sequence_size(seq));
            a   = [[GTWTree alloc] initWithType:kAlgebraProject value: vlist arguments:@[a]];
//			a	= gtw_new_tree_va(ALGEBRA_PROJECT, NULL, 2, a, vlist);
		}
	}
	
	i = rasqal_query_get_distinct(rq);
	if(i != 0) {
		//		fprintf(fh, "distinct\n");
		a   = [[GTWTree alloc] initWithType:kAlgebraDistinct arguments:@[a]];
//        a	= gtw_new_tree_va(ALGEBRA_DISTINCT, NULL, 1, a);
	}
	
	{
		int _offset	= rasqal_query_get_offset(rq);
		int _limit	= rasqal_query_get_limit(rq);
		if (_offset >= 0 || _limit >= 0) {
			if (_offset < 0)
				_offset	= 0;
            //			char* length_str	= alloca(21);
            //			char* start_str		= alloca(21);
            //			snprintf(length_str, 20, "%"PRId64, (int64_t) limit);
            //			snprintf(start_str, 20, "%"PRId64, (int64_t) offset);
            GTWLiteral* limit  = [GTWLiteral integerLiteralWithValue:_limit];
            GTWLiteral* offset  = [GTWLiteral integerLiteralWithValue:_offset];
//			gtw_term* length	= gtw_new_term_integer(limit);
//			gtw_term* start		= gtw_new_term_integer(offset);
			
//			node_pack_ctx* ctx	= new_node_pack_ctx();
//			node_id sid	= term_packed_node_id(ctx, start);
//			node_id lid	= term_packed_node_id(ctx, length);
//			free_node_pack_ctx(ctx);
//			
//			gtw_node* limit		= gtw_new_node(lid, length);
//			gtw_node* offset	= gtw_new_node(sid, start);
            a   = [[GTWTree alloc] initWithType:kAlgebraSlice arguments:@[
                   a,
                   [[GTWTree alloc] initLeafWithType:kTreeNode value: offset pointer:NULL],
                   [[GTWTree alloc] initLeafWithType:kTreeNode value: limit pointer:NULL],
                   ]];
//			a	= gtw_new_tree_va(
//                                  ALGEBRA_SLICE, NULL, 3,
//                                  a,
//                                  gtw_new_tree_va(kTreeNode, offset, 0),
//                                  gtw_new_tree_va(kTreeNode, limit, 0)
//                                  );
//			gtw_free_term(start);
//			gtw_free_term(length);
		}
	}
	
	{
		rasqal_query_verb verb;
		verb = rasqal_query_get_verb(rq);
		if (verb == RASQAL_QUERY_VERB_DESCRIBE) {
			raptor_sequence* seq	= rasqal_query_get_describe_sequence(rq);
			int size	= seq ? raptor_sequence_size(seq) : -1;
			if (seq && size > 0) {
                NSMutableArray* vars    = [NSMutableArray arrayWithCapacity:size];
//				gtw_tree_node** vars	= (gtw_tree_node**) alloca(sizeof(gtw_tree_node*) * size);
				for (i = 0; i < size; i++) {
					rasqal_literal* l	= raptor_sequence_get_at(seq, i);
                    id<GTWTerm> t   = rasqal_literal_to_object(l);
//					gtw_term* t	= rasqal_literal_to_term(l);
                    vars[i] = [[GTWTree alloc] initLeafWithType:kTreeNode value: t pointer:NULL];
//					vars[i]	= gtw_new_tree_va(kTreeNode, gtw_new_node(NODE_NULL, t), 0);
//					gtw_free_term(t);
				}
                GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:vars];
//				gtw_tree_node* vlist	= gtw_new_tree(kTreeList, NULL, size, vars);
                a   = [[GTWTree alloc] initWithType:kAlgebraDescribe arguments:@[a, vlist]];
//				a	= gtw_new_tree_va(ALGEBRA_DESCRIBE, NULL, 2, a, vlist);
			}
		}
	}
	
	return a;
}

@implementation GTWRasqalSPARQLParser

- (GTWRasqalSPARQLParser*) initWithRasqalWorld: (rasqal_world*) rasqal_world_ptr {
    if (self = [self init]) {
        self.rasqal_world_ptr   = rasqal_world_ptr;
    }
    return self;
}

- (GTWTree*) parserSPARQL: (NSString*) queryString withBaseURI: (NSString*) base {
	raptor_world* raptor_world_ptr = rasqal_world_get_raptor(self.rasqal_world_ptr);
	//	fprintf(stderr, "Running query '%s'\n", query_string);
	raptor_uri *base_uri	= raptor_new_uri(raptor_world_ptr, (const unsigned char*) [base UTF8String]);
	
	const char* ql_name	= "sparql11";
	rasqal_query* rq	= rasqal_new_query(self.rasqal_world_ptr, ql_name, NULL);
	if(!rq) {
		fprintf(stderr, "Failed to create %s query\n", ql_name);
		return NULL;
	}
	
	if(rasqal_query_prepare(rq, (const unsigned char*) [queryString UTF8String], base_uri)) {
        NSLog(@"Parsing query '%@' failed\n", queryString);
		rasqal_free_query(rq);
		rq = NULL;
	}
	
	
	if(rq) {
        GTWTree* a	= roqet_query_walk(self.rasqal_world_ptr, raptor_world_ptr, rq, stdout);
        if(rq)
            rasqal_free_query(rq);
        raptor_free_uri(base_uri);
        return a;
    } else {
        raptor_free_uri(base_uri);
        return NULL;
    }
}

@end
