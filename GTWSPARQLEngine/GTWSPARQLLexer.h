#import "GTWSPARQLToken.h"

@interface GTWSPARQLLexer : NSObject {
	NSFileHandle* _file;
	NSString* _string;
	NSUInteger _stringPos;
	NSMutableString* _linebuffer;
	NSUInteger _line;
	NSUInteger _column;
	NSUInteger _character;
	NSMutableString* _buffer;
	NSUInteger _startColumn;
	NSUInteger _startLine;
	NSUInteger _startCharacter;
	BOOL _comments;
}

@property (strong) NSFileHandle* file;
@property (strong) NSString* string;
@property (strong) NSMutableString* linebuffer;
@property NSUInteger stringPos;
@property NSUInteger line;
@property NSUInteger column;
@property NSUInteger character;
@property (strong) NSMutableString* buffer;
@property NSUInteger startColumn;
@property NSUInteger startLine;
@property NSUInteger startCharacter;
@property BOOL comments;
@property (strong) GTWSPARQLToken* lookahead;

- (GTWSPARQLLexer*) initWithFileHandle: (NSFileHandle*) handle;
- (GTWSPARQLLexer*) initWithString: (NSString*) string;
- (GTWSPARQLToken*) getToken;
- (GTWSPARQLToken*) peekToken;

@end
