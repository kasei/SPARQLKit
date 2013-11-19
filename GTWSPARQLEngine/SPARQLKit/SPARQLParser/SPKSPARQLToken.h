#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWBlank.h>
#import <GTWSWBase/GTWLiteral.h>

typedef NS_ENUM(NSInteger, SPKSPARQLTokenType) {
	WS,
	COMMENT,
	NIL,
	ANON,
	DOUBLE,
	DECIMAL,
	INTEGER,
	HATHAT,
	LANG,
	LPAREN,
	RPAREN,
	LBRACE,
	RBRACE,
	LBRACKET,
	RBRACKET,
	EQUALS,
	NOTEQUALS,
	BANG,
	IRIREF,
	LE,
	GE,
	LT,
	GT,
	ANDAND,
	OROR,
	SEMICOLON,
	DOT,
	COMMA,
	PLUS,
	MINUS,
	STAR,
	SLASH,
	VAR,
	STRING3D,
	STRING3S,
	STRING1D,
	STRING1S,
	BNODE,
	HAT,
	QUESTION,
	OR,
	PREFIXNAME,
	BOOLEAN,
	KEYWORD,
	IRI,
};

@interface SPKSPARQLToken : NSObject {
	SPKSPARQLTokenType _type;
	NSRange _range;
	NSArray* _args;
}

@property SPKSPARQLTokenType type;
@property NSRange range;
@property (strong) NSArray* args;

+ (NSString*) nameOfSPARQLTokenOfType: (SPKSPARQLTokenType) type;
- (SPKSPARQLToken*) initTokenOfType: (SPKSPARQLTokenType) type withArguments: (NSArray*) args fromRange: (NSRange) range;
- (id) value;
- (BOOL) isTerm;
- (BOOL) isTermOrVar;
- (BOOL) isNumber;
- (BOOL) isString;
- (BOOL) isRelationalOperator;
// - (id) asNode;

@end
