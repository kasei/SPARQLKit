#import "GTWTurtleToken.h"

static const char* sparql_token_type_name( GTWTurtleTokenType t ) {
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
		case IRIREF:
			return "IRIREF";
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

@implementation GTWTurtleToken


- (GTWTurtleToken*) initTokenOfType: (GTWTurtleTokenType) type withArguments: (NSArray*) args fromRange: (NSRange) range {
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


/**

 sub is_relop {
 my $self	= shift;
 my $type	= $self->type;
 return ($type == LT or $type == LE or $type == GT or $type == GE or $type == EQUALS or $type == NOTEQUALS or $type == ANDAND or $type == OROR);
 }
 
**/


@end

