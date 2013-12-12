#import "SPKSPARQLToken.h"

NSArray* SPKSPARQLKeywords(void);

@interface SPKSPARQLLexer : NSObject {
	NSFileHandle* _file;
	NSString* _string;
	NSUInteger _stringPos;
	NSUInteger _line;
	NSUInteger _column;
	NSUInteger _character;
	NSMutableString* _buffer;
	NSUInteger _startColumn;
	NSUInteger _startLine;
	NSUInteger _startCharacter;
	BOOL _comments;
    NSMutableData* _linebuffer;
    NSRegularExpression* _multiLineAnonRegex;
    NSRegularExpression* _pNameLNre;
    NSRegularExpression* _pNameNSre;
    NSRegularExpression* _escapedCharRegex;
    NSRegularExpression* _alphanumRegex;
    NSRegularExpression* _unescapedDoubleLiteralRegex;
    NSRegularExpression* _unescapedLiteralRegex;
    NSRegularExpression* _iriRegex;
    NSRegularExpression* _unescapedIRIRegex;
    NSRegularExpression* _nilRegex;
    NSRegularExpression* _doubleRegex;
    NSRegularExpression* _decimalRegex;
    NSRegularExpression* _integerRegex;
    NSRegularExpression* _anonRegex;
}

@property (retain) NSFileHandle* file;
@property (retain) NSString* string;
@property NSUInteger stringPos;
@property NSUInteger line;
@property NSUInteger column;
@property NSUInteger character;
@property (retain) NSMutableString* buffer;
@property NSUInteger startColumn;
@property NSUInteger startLine;
@property NSUInteger startCharacter;
@property BOOL comments;
@property (retain) SPKSPARQLToken* lookahead;

- (SPKSPARQLLexer*) initWithFileHandle: (NSFileHandle*) handle;
- (SPKSPARQLLexer*) initWithString: (NSString*) string;
- (SPKSPARQLToken*) getTokenWithError:(NSError*__autoreleasing*)error;
- (SPKSPARQLToken*) peekTokenWithError:(NSError*__autoreleasing*)error;

@end
