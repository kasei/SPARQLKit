#import "SPKSPARQLToken.h"

@interface SPKSPARQLLexer : NSObject {
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
@property (strong) SPKSPARQLToken* lookahead;

- (SPKSPARQLLexer*) initWithFileHandle: (NSFileHandle*) handle;
- (SPKSPARQLLexer*) initWithString: (NSString*) string;
- (SPKSPARQLToken*) getTokenWithError:(NSError**)error;
- (SPKSPARQLToken*) peekTokenWithError:(NSError**)error;

@end
