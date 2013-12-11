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
}

@property (strong) NSFileHandle* file;
@property (strong) NSString* string;
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
- (SPKSPARQLToken*) getTokenWithError:(NSError*__autoreleasing*)error;
- (SPKSPARQLToken*) peekTokenWithError:(NSError*__autoreleasing*)error;

@end
