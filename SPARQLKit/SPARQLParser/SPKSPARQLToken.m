#import "SPKSPARQLToken.h"
#import "SPKSPARQLLexer.h"

static const char* sparql_token_type_name( SPKSPARQLTokenType t ) {
	switch (t) {
		case WS:
			return "WS";
		case COMMENT:
			return "COMMENT";
		case NIL:
			return "NIL";
		case ANON:
			return "ANON";
		case DOUBLE:
			return "DOUBLE";
		case DECIMAL:
			return "DECIMAL";
		case INTEGER:
			return "INTEGER";
		case HATHAT:
			return "HATHAT";
		case LANG:
			return "LANG";
		case LPAREN:
			return "LPAREN";
		case RPAREN:
			return "RPAREN";
		case LBRACE:
			return "LBRACE";
		case RBRACE:
			return "RBRACE";
		case LBRACKET:
			return "LBRACKET";
		case RBRACKET:
			return "RBRACKET";
		case EQUALS:
			return "EQUALS";
		case NOTEQUALS:
			return "NOTEQUALS";
		case BANG:
			return "BANG";
//		case IRIREF:
//			return "IRIREF";
		case LE:
			return "LE";
		case GE:
			return "GE";
		case LT:
			return "LT";
		case GT:
			return "GT";
		case ANDAND:
			return "ANDAND";
		case OROR:
			return "OROR";
		case SEMICOLON:
			return "SEMICOLON";
		case DOT:
			return "DOT";
		case COMMA:
			return "COMMA";
		case PLUS:
			return "PLUS";
		case MINUS:
			return "MINUS";
		case STAR:
			return "STAR";
		case SLASH:
			return "SLASH";
		case VAR:
			return "VAR";
		case STRING3D:
			return "STRING3D";
		case STRING3S:
			return "STRING3S";
		case STRING1D:
			return "STRING1D";
		case STRING1S:
			return "STRING1S";
		case BNODE:
			return "BNODE";
		case HAT:
			return "HAT";
		case QUESTION:
			return "QUESTION";
		case OR:
			return "OR";
		case PREFIXNAME:
			return "PREFIXNAME";
		case BOOLEAN:
			return "BOOLEAN";
		case KEYWORD:
			return "KEYWORD";
		case IRI:
			return "IRI";
		default:
			return "unknown token type";
	}
}

@implementation SPKSPARQLToken

+ (NSString*) nameOfSPARQLTokenOfType: (SPKSPARQLTokenType) type {
    return [NSString stringWithFormat:@"%s", sparql_token_type_name(type)];
}

- (SPKSPARQLToken*) initTokenOfType: (SPKSPARQLTokenType) type withArguments: (NSArray*) args fromRange: (NSRange) range {
	if (self = [super init]) {
		self.type	= type;
		self.range	= range;
		self.args	= args;
	}
	return self;
}

- (id) value {
	return (self.args)[0];
}

- (BOOL) isTerm {
	return (self.type == INTEGER || self.type == DECIMAL || self.type == DOUBLE || self.type == ANON || self.type == BOOLEAN || self.type == BNODE || self.type == IRI || self.type == PREFIXNAME || self.type == STRING1D || self.type == STRING3D || (self.type == KEYWORD && [self.value isEqualToString:@"A"]));
}

- (BOOL) isTermOrVar {
	return (self.type == VAR || [self isTerm]);
}

- (BOOL) isNumber {
	return (self.type == INTEGER || self.type == DECIMAL || self.type == DOUBLE);
}

- (BOOL) isString {
	return (self.type == STRING1D || self.type == STRING3D || self.type == STRING1S || self.type == STRING3S);
}

- (BOOL) isRelationalOperator {
	return (self.type == LT || self.type == LE || self.type == GT || self.type == GE || self.type == EQUALS || self.type == NOTEQUALS || self.type == ANDAND || self.type == OROR);
}

- (NSString*) description {
	NSMutableArray* args	= [NSMutableArray array];
	for (id a in self.args) {
		[args addObject:[a description]];
	}
	NSString* d	= [args componentsJoinedByString:@", "];
	return [NSString stringWithFormat:@"%s\t%@", sparql_token_type_name(self.type), d];
}

- (NSString*) sparqlIRIStringWithResource:(NSString*)iri prefixes:(NSDictionary*)prefixes {
    // TODO: check prefixes
    // TODO: escape
    return [NSString stringWithFormat:@"<%@>", iri];
}

- (NSString*) sparqlLiteralString {
    NSString *value, *escaped;
    SPKSPARQLTokenType t    = self.type;
    switch (t) {
        case STRING3D:
            // TODO: escape
            return [NSString stringWithFormat: @"\"\"\"%@\"\"\"", self.args[0]];
        case STRING3S:
            // TODO: escape
            return [NSString stringWithFormat: @"'''%@'''", self.args[0]];
        case STRING1D:
            value   = self.args[0];
            escaped = [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            return [NSString stringWithFormat: @"\"%@\"", escaped];
        case STRING1S:
            value   = self.args[0];
            escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            return [NSString stringWithFormat: @"'%@'", escaped];
        default:
            return nil;
    }
}

- (NSString*) sparqlStringWithDefinedPrefixes:(NSDictionary*)prefixes {
    NSError* error;
    NSRegularExpression* _doubleRegex        = [NSRegularExpression regularExpressionWithPattern:r_DOUBLE options:0 error:&error];
    NSRegularExpression* _decimalRegex       = [NSRegularExpression regularExpressionWithPattern:r_DECIMAL options:0 error:&error];
    NSRegularExpression* _integerRegex       = [NSRegularExpression regularExpressionWithPattern:r_INTEGER options:0 error:&error];
    NSString* value;
    SPKSPARQLTokenType t    = self.type;
    NSRange range;
    switch (t) {
        case WS:
            return @" ";
        case KEYWORD:
            if ([self.args[0] isEqualTo:@"A"]) {
                return @"a";
            }
            return [self.args[0] uppercaseString];
        case STAR:
        case HATHAT:
        case HAT:
        case LBRACE:
        case RBRACE:
        case LBRACKET:
        case RBRACKET:
        case LPAREN:
        case RPAREN:
        case EQUALS:
        case NOTEQUALS:
        case BANG:
        case LE:
        case GE:
        case LT:
        case GT:
        case ANDAND:
        case OROR:
        case PLUS:
        case MINUS:
        case DOT:
        case COMMA:
        case SLASH:
        case QUESTION:
        case SEMICOLON:
        case OR:
        case NIL:
            return self.args[0];
        case LANG:
            return [NSString stringWithFormat: @"@%@", self.args[0]];
        case VAR:
            return [NSString stringWithFormat: @"?%@", self.args[0]];
        case BNODE:
            return [NSString stringWithFormat: @"_:%@", self.args[0]];
        case COMMENT:
            return [NSString stringWithFormat: @"#%@", self.args[0]];
        case BOOLEAN:
            value   = self.args[0];
            if ([value isEqualToString:@"true"] || [value isEqualToString:@"false"]) {
                return value;
            } else {
                return [NSString stringWithFormat: @"\"%@\"^^%@", self.args[0], [self sparqlIRIStringWithResource:@"http://www.w3.org/2001/XMLSchema#boolean" prefixes:prefixes]];
            }
        case DOUBLE:
            range	= [_doubleRegex rangeOfFirstMatchInString:self.args[0] options:0 range:NSMakeRange(0, [self.args[0] length])];
            if (range.location == 0) {
                return self.args[0];
            } else {
                return [NSString stringWithFormat: @"\"%@\"^^%@", self.args[0], [self sparqlIRIStringWithResource:@"http://www.w3.org/2001/XMLSchema#double" prefixes:prefixes]];
            }
        case DECIMAL:
            range	= [_decimalRegex rangeOfFirstMatchInString:self.args[0] options:0 range:NSMakeRange(0, [self.args[0] length])];
            if (range.location == 0) {
                return self.args[0];
            } else {
                return [NSString stringWithFormat: @"\"%@\"^^%@", self.args[0], [self sparqlIRIStringWithResource:@"http://www.w3.org/2001/XMLSchema#decimal" prefixes:prefixes]];
            }
        case INTEGER:
            range	= [_integerRegex rangeOfFirstMatchInString:self.args[0] options:0 range:NSMakeRange(0, [self.args[0] length])];
            if (range.location == 0) {
                return self.args[0];
            } else {
                return [NSString stringWithFormat: @"\"%@\"^^%@", self.args[0], [self sparqlIRIStringWithResource:@"http://www.w3.org/2001/XMLSchema#integer" prefixes:prefixes]];
            }
        case PREFIXNAME:
            return [NSString stringWithFormat: @"%@:%@", self.args[0], self.args[1]];
        case IRI:
            return [self sparqlIRIStringWithResource:self.args[0] prefixes:prefixes];
        case STRING3D:
        case STRING3S:
        case STRING1D:
        case STRING1S:
            return [self sparqlLiteralString];
        case ANON:
            return @"[]";
        default:
            NSLog(@"Unexpected token type %s seen in sparqlStringWithDefinedPrefixes:", sparql_token_type_name(self.type));
            return nil;
    }
}


/**
 
 sub is_relop {
 my $self	= shift;
 my $type	= $self->type;
 return ($type == LT or $type == LE or $type == GT or $type == GE or $type == EQUALS or $type == NOTEQUALS or $type == ANDAND or $type == OROR);
 }
 
 **/


@end

