#import "GTWTurtleToken.h"

@interface GTWTurtleLexer : NSObject {
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
@property (strong) GTWTurtleToken* lookahead;

- (GTWTurtleLexer*) initWithFileHandle: (NSFileHandle*) handle;
- (GTWTurtleLexer*) initWithString: (NSString*) string;
- (GTWTurtleToken*) getToken;
- (GTWTurtleToken*) peekToken;

@end
