#import "SPKSPARQLLexer.h"


NSArray* SPKSPARQLKeywords(void) {
    static NSArray *_SPKSPARQLKeywords = nil;
    static dispatch_once_t keywordsOnceToken;
    dispatch_once(&keywordsOnceToken, ^{
        _SPKSPARQLKeywords = [NSArray arrayWithObjects:@"ABS", @"ADD", @"ALL", @"ASC", @"ASK", @"AS", @"AVG", @"BASE", @"BIND", @"BNODE", @"BOUND", @"BY", @"CEIL", @"CLEAR", @"COALESCE", @"CONCAT", @"CONSTRUCT", @"CONTAINS", @"COPY", @"COUNT", @"CREATE", @"DATATYPE", @"DAY", @"DEFAULT", @"DELETE", @"DELETE WHERE", @"DESCRIBE", @"DESC", @"DISTINCT", @"DISTINCT", @"DROP", @"ENCODE_FOR_URI", @"EXISTS", @"FILTER", @"FLOOR", @"FROM", @"GRAPH", @"GROUP_CONCAT", @"GROUP", @"HAVING", @"HOURS", @"IF", @"INSERT", @"INSERT", @"DATA", @"INTO", @"IN", @"IRI", @"ISBLANK", @"ISIRI", @"ISLITERAL", @"ISNUMERIC", @"ISURI", @"LANGMATCHES", @"LANG", @"LCASE", @"LIMIT", @"LOAD", @"MAX", @"MD5", @"MINUS", @"MINUTES", @"MIN", @"MONTH", @"MOVE", @"NAMED", @"NOT", @"NOW", @"OFFSET", @"OPTIONAL", @"ORDER", @"PREFIX", @"RAND", @"REDUCED", @"REGEX", @"REPLACE", @"ROUND", @"SAMETERM", @"SAMPLE", @"SECONDS", @"SELECT", @"SEPARATOR", @"SERVICE", @"SHA1", @"SHA256", @"SHA384", @"SHA512", @"SILENT", @"STRAFTER", @"STRBEFORE", @"STRDT", @"STRENDS", @"STRLANG", @"STRLEN", @"STRSTARTS", @"STRUUID", @"STR", @"SUBSTR", @"SUM", @"TIMEZONE", @"TO", @"TZ", @"UCASE", @"UNDEF", @"UNION", @"URI", @"USING", @"UUID", @"VALUES", @"WHERE", @"WITH", @"YEAR", nil];
    });
    
    return _SPKSPARQLKeywords;
}

static NSDictionary* SPARQLCharTokens() {
	static NSDictionary *_SPARQLCharTokens = nil;
	static dispatch_once_t charOnceToken;
	dispatch_once(&charOnceToken, ^{
		_SPARQLCharTokens = @{
                              @",": @(COMMA),
                              @".": @(DOT),
                              @"=": @(EQUALS),
                              @"{": @(LBRACE),
                              @"[": @(LBRACKET),
                              @"(": @(LPAREN),
                              @"-": [NSNumber numberWithLong:MINUS],
                              @"+": [NSNumber numberWithLong:PLUS],
                              @"}": @(RBRACE),
                              @"]": @(RBRACKET),
                              @")": @(RPAREN),
                              @";": @(SEMICOLON),
                              @"/": @(SLASH),
                              @"*": @(STAR)
                              };
	});
	
    return _SPARQLCharTokens;
}

//static NSDictionary* SPARQLMethodTokens() {
//	static NSDictionary *_SPARQLMethodTokens = nil;
//	static dispatch_once_t methodOnceToken;
//	dispatch_once(&methodOnceToken, ^{
//		_SPARQLMethodTokens = @{
//                                @"@": [NSValue valueWithPointer:@selector(getLanguage)],
//                                @"<": [NSValue valueWithPointer:@selector(getIRIRefOrRelational)],
//                                @"?": [NSValue valueWithPointer:@selector(getVariable)],
//                                @"$": [NSValue valueWithPointer:@selector(getVariable)],
//                                @"!": [NSValue valueWithPointer:@selector(getBang)],
//                                @">": [NSValue valueWithPointer:@selector(getRelational)],
//                                @"|": [NSValue valueWithPointer:@selector(getOr)],
//                                @"'": [NSValue valueWithPointer:@selector(getSingleLiteral)],
//                                @"\"": [NSValue valueWithPointer:@selector(getDoubleLiteral)],
//                                @"_": [NSValue valueWithPointer:@selector(getBnode)],
//                                @":": [NSValue valueWithPointer:@selector(getPName)]
//                                };
//	});
//
//    return _SPARQLMethodTokens;
//}

static NSCharacterSet* SPARQLPrefixNameStartChar() {
	static NSCharacterSet *_SPARQLPrefixNameStartChar = nil;
	static dispatch_once_t pnameStartCharOnceToken;
	dispatch_once(&pnameStartCharOnceToken, ^{
		NSRange range_0	= {0xC0, (0xD6-0xC0)};
		NSRange range_1	= {0xD8, (0xF6-0xD8)};
		NSRange range_2	= {0xF8, (0xFF-0xF8)};
		NSRange range_3	= {0x370, (0x37D-0x370)};
		NSRange range_4	= {0x37F, (0x1FFF-0x37F)};
		NSRange range_5	= {0x200C, (0x200D-0x200C)};
		NSRange range_6	= {0x2070, (0x218F-0x2070)};
		NSRange range_7	= {0x2C00, (0x2FEF-0x2C00)};
		NSRange range_8	= {0x3001, (0xD7FF-0x3001)};
		NSRange range_9	= {0xF900, (0xFDCF-0xF900)};
		NSRange range_a	= {0xFDF0, (0xFFFD-0xFDF0)};
		NSRange range_b	= {0x10000, (0xEFFFF-0x10000)};
		
		NSMutableCharacterSet* pn	= [[NSMutableCharacterSet alloc] init];
		[pn addCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"];
		[pn addCharactersInRange:range_0];
		[pn addCharactersInRange:range_1];
		[pn addCharactersInRange:range_2];
		[pn addCharactersInRange:range_3];
		[pn addCharactersInRange:range_4];
		[pn addCharactersInRange:range_5];
		[pn addCharactersInRange:range_6];
		[pn addCharactersInRange:range_7];
		[pn addCharactersInRange:range_8];
		[pn addCharactersInRange:range_9];
		[pn addCharactersInRange:range_a];
		[pn addCharactersInRange:range_b];
		
		_SPARQLPrefixNameStartChar	= pn;
	});
	
	return _SPARQLPrefixNameStartChar;
}


@implementation SPKSPARQLLexer

- (SPKSPARQLLexer*) init {
	if (self = [super init]) {
		self.file			= nil;
		self.string			= nil;
		self.buffer			= [NSMutableString string];
		self.linebuffer		= [NSMutableString string];
		self.line			= 1;
		self.column			= 1;
		self.character		= 0;
		self.startColumn	= -1;
		self.startLine		= -1;
		self.startLine		= 0;
		self.comments		= YES;
	}
	return self;
}

- (SPKSPARQLLexer*) initWithString: (NSString*) string {
	if (self = [self init]) {
		self.file			= nil;
		self.string			= string;
		self.stringPos		= 0;
		self.buffer			= [NSMutableString string];
		self.linebuffer		= [NSMutableString string];
		self.line			= 1;
		self.column			= 1;
		self.character		= 0;
		self.startColumn	= -1;
		self.startLine		= -1;
		self.startLine		= 0;
		self.comments		= YES;
	}
	return self;
}

- (SPKSPARQLLexer*) initWithFileHandle: (NSFileHandle*) handle {
	if (self = [self init]) {
		self.file			= handle;
	}
	return self;
}

- (SPKSPARQLToken*) newTokenOfType: (SPKSPARQLTokenType) type withArgs: (NSArray*) args {
	NSUInteger start	= self.startCharacter;
	NSUInteger length	= self.character - start;
	NSRange range	= { .location = start, .length = length };
	return [[SPKSPARQLToken alloc] initTokenOfType:type withArguments:args fromRange:range];
}

- (void) _fillBuffer {
	NSMutableData* linebuffer	= [[NSMutableData alloc] init];
    //	NSLog(@"trying to fill buffer with existing buffer '%@' (%lu)", self.buffer, [self.buffer length]);
	if ([self.buffer length] == 0) {
    FILL_LOOP:
		while (1) {
			if (self.file) {
				NSData* data	= [self.file readDataOfLength:1];
				if ([data length] == 0) {
					break;
				}
				[linebuffer appendData:data];
				NSString* c		= [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
				if ([c isEqualToString:@"\n"] || [c isEqualToString:@"\r"]) {
					break;
				}
			} else {
				if (self.stringPos >= [self.string length])
					break;
				NSRange range	= { .location = self.stringPos++, .length = 1 };
				NSString* c		= [self.string substringWithRange:range];
				NSData* data	= [c dataUsingEncoding:NSUTF8StringEncoding];
				[linebuffer appendData:data];
				if ([c isEqualToString:@"\n"] || [c isEqualToString:@"\r"]) {
					break;
				}
			}
		}
		NSString* line	= [[NSString alloc] initWithData:linebuffer encoding:NSUTF8StringEncoding];
        NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:@"(\\[|\\()[\\t\\r\\n ]*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
        NSRange range   = [re rangeOfFirstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
        if ((range.location + range.length) == [line length]) {
            goto FILL_LOOP;
        }
		[self.buffer appendString:line];
	}
}

- (NSString*) _peekChar {
	if ([self.buffer length] == 0) {
		[self _fillBuffer];
		if ([self.buffer length] == 0) {
			return nil;
		}
	}
	NSString* c	= [self.buffer substringToIndex:1];
	return c;
}

- (NSString*) _getChar {
	NSString* c	= [self.buffer substringToIndex:1];
	NSRange range	= { 0, 1 };
	[self.buffer deleteCharactersInRange:range];
	self.character++;
	if ([c isEqualToString:@"\n"]) {
		self.line++;
		self.column	= 1;
	} else {
		self.column++;
	}
	return c;
}

- (NSString*) _getCharSafe: (NSString*) expected error:(NSError*__autoreleasing*)error {
	NSString* c	= [self _getChar];
	if ([c isNotEqualTo:expected]) {
		return [self throwError:[NSString stringWithFormat:@"Expected '%@' but got '%@'", expected, c] withError:error];
	}
	return c;
}

- (NSString*) _getCharFillBuffer {
	if ([self.buffer length] == 0) {
		[self _fillBuffer];
		if ([self.buffer length] == 0) {
			return nil;
		}
	}
	NSString* c	= [self.buffer substringToIndex:1];
	NSRange range	= { 0, 1 };
	[self.buffer deleteCharactersInRange:range];
	self.character++;
	if ([c isEqualToString:@"\n"]) {
		self.line++;
		self.column	= 1;
	} else {
		self.column++;
	}
	return c;
}

- (BOOL) _readWord: (NSString*) word error:(NSError*__autoreleasing*)error {
	while ([self.buffer length] < [word length]) {
		NSUInteger len	= [self.buffer length];
		[self _fillBuffer];
		if (len == [self.buffer length]) {
			[self throwError:[NSString stringWithFormat:@"Expected '%@', but not enough read-ahead data available", word] withError:error];
			return NO;
		}
	}
	
	if (([self.buffer length] < [word length]) || (![self.buffer hasPrefix:word])) {
		[self throwError:[NSString stringWithFormat:@"Expected '%@'", word] withError:error];
		return NO;
	}
	
	NSMutableString* mword	= [NSMutableString stringWithString: word];
	NSRange range	= {0, [mword length]};
	NSUInteger lines	= [mword replaceOccurrencesOfString:@"\n" withString:@"\n" options:NSLiteralSearch range:range];
	
	self.line	+= lines;
	self.character	+= [word length];
	range.location	= 0;
	range.length	= [word length];
	[self.buffer deleteCharactersInRange:range];
	return YES;
}

- (NSString*) _readLength: (NSUInteger) length error:(NSError*__autoreleasing*)error {
	while ([self.buffer length] < length) {
		[self _fillBuffer];
	}
	
	if ([self.buffer length] < length) {
		NSUInteger remaining	= [self.buffer length];
		return [self throwError:[NSString stringWithFormat:@"Expecting %lu bytes but only %lu remaining", (unsigned long)length, (unsigned long)remaining] withError:error];
	}
	
	NSRange range;
	NSString* word	= [self.buffer substringToIndex:length];
	range.location	= 0;
	range.length	= [word length];
	[self.buffer deleteCharactersInRange:range];
    
	NSMutableString* mword	= [NSMutableString stringWithString: word];
	range.location	= 0;
	range.length	= [mword length];
	NSUInteger lines	= [mword replaceOccurrencesOfString:@"\n" withString:@"\n" options:NSLiteralSearch range:range];
	self.line	+= lines;
	self.character	+= [word length];
	return word;
}

- (SPKSPARQLToken*) newPName: (NSArray*) pname {
	return [self newTokenOfType:PREFIXNAME withArgs:pname];
}

- (SPKSPARQLToken*) getPNameWithError:(NSError*__autoreleasing*)error {
	NSString* r_PNAME_LN	= @"((((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[:0-9]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2}))(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})|[:.])*((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[:]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})))?))";
	NSString* r_PNAME_NS	= @"(((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)";
	NSRange range	= [self.buffer rangeOfString:r_PNAME_LN options:NSRegularExpressionSearch];
	NSRange range2	= [self.buffer rangeOfString:r_PNAME_NS options:NSRegularExpressionSearch];
	if (range.location == 0) {
		NSString* pname	= [self _readLength:range.length error:error];
        if ([pname rangeOfString:@"\\"].location != NSNotFound) {
            NSRegularExpression* regex  = [NSRegularExpression regularExpressionWithPattern:@"\\\\(.)" options:0 error:error];
            if (*error) {
                return nil;
            }
            pname  = [regex stringByReplacingMatchesInString:pname options:0 range:NSMakeRange(0, [pname length]) withTemplate:@"$1"];
        }
        
        
		NSArray* values	= [pname componentsSeparatedByString:@":"];
        if ([values count] != 2) {
            NSMutableArray* mvalues = [NSMutableArray arrayWithArray:values];
            [mvalues removeObjectAtIndex:0];
            NSString* first = values[0];
            NSString* rest  = [mvalues componentsJoinedByString:@":"];
            values  = @[ first, rest ];
        }
		return [self newPName: values];
	} else if (range2.location == 0) {
		NSString* pname	= [self _readLength:range2.length error:error];
		NSArray* values	= [pname componentsSeparatedByString:@":"];
		return [self newPName: values];
	} else {
        return nil;
	}
}

- (SPKSPARQLToken*) getBnodeWithError:(NSError*__autoreleasing*)error {
	[self _getCharSafe:@"_" error:error];
	[self _getCharSafe:@":" error:error];
    NSString* r_bnode   = @"^([0-9A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])(([A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])|([-0-9\\x{00B7}\\x{0300}-\\x{036F}\\x{203F}-\\x{2040}]))*";
	NSRange range	= [self.buffer rangeOfString:r_bnode options:NSRegularExpressionSearch];
	if (range.location == 0) {
		NSString* name	= [self _readLength:range.length error:error];
        return [self newTokenOfType:BNODE withArgs:@[name]];
	} else {
		return nil;
	}
}

- (SPKSPARQLToken*) _getCommentWithError:(NSError*__autoreleasing*)error {
	[self _getCharSafe:@"#" error:error];
	NSMutableString* comment	= [NSMutableString string];
	NSString* c	= [self _peekChar];
	while (c != nil && [c length] > 0 && ([c isNotEqualTo:@"\r"] && [c isNotEqualTo:@"\n"])) {
		[comment appendString:[self _getChar]];
		c	= [self _peekChar];
	}
	
	if (c != nil && [c length] > 0 && ([c isEqualTo:@"\r"] || [c isEqualTo:@"\n"])) {
		[self _getChar];
	}
	
	return [self newTokenOfType:COMMENT withArgs:@[comment]];
}

- (SPKSPARQLToken*) _getNumberWithError:(NSError*__autoreleasing*)error {
	NSRange integer_range	= [self.buffer rangeOfString:@"[0-9]+" options:NSRegularExpressionSearch];
    NSRange double_range	= [self.buffer rangeOfString:@"[+-]?(([0-9]+[.][0-9]*[eE][+-]?[0-9]+)|([.][0-9]+[eE][+-]?[0-9]+)|([0-9]+[eE][+-]?[0-9]+))" options:NSRegularExpressionSearch];
	if (integer_range.location == 0) {
		NSString* integer	= [self _readLength:integer_range.length error:error];
		return [self newTokenOfType:INTEGER withArgs:@[integer]];
    } else if (double_range.location == 0) {
		NSString* value	= [self _readLength:integer_range.length error:error];
		return [self newTokenOfType:DOUBLE withArgs:@[value]];
	} else {
		NSString* c	= [self _peekChar];
		if ([c isEqualToString:@"-"]) {
			[self _getChar];
			return [self newTokenOfType:MINUS withArgs:@[]];
		} else if ([c isEqualToString:@"+"]) {
			[self _getChar];
			return [self newTokenOfType:PLUS withArgs:@[]];
		} else {
			return [self throwError:@"Expected number" withError:error];
		}
	}
}

- (SPKSPARQLToken*) getVariableWithError:(NSError*__autoreleasing*)error {
	NSString* c	= [self _getChar];
	NSRange range	= [self.buffer rangeOfString:@"((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9])(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])*)" options:NSRegularExpressionSearch];
    
	if (range.location != 0) {
		if ([c isEqualToString:@"?"]) {
			return [self newTokenOfType:QUESTION withArgs:@[]];
		} else {
			return [self throwError:@"Expected variable name" withError:error];
		}
	}
	
	NSString* name	= [self _readLength:range.length error:error];
	return [self newTokenOfType:VAR withArgs:@[name]];
}

- (SPKSPARQLToken*) _getKeywordWithError:(NSError*__autoreleasing*)error {
	NSArray* keywords	= SPKSPARQLKeywords();
	for (NSString* kw in keywords) {
		NSRange range	= [self.buffer rangeOfString:kw options:NSAnchoredSearch|NSCaseInsensitiveSearch];
		if (range.location != NSNotFound) {
			[self _readLength:[kw length] error:error];
			return [self newTokenOfType:KEYWORD withArgs:@[[kw uppercaseString]]];
		}
	}
    
	NSRange range	= [self.buffer rangeOfString:@"a\\b" options:NSRegularExpressionSearch];
	if (range.location == 0) {
		[self _readLength:1 error:error];
		return [self newTokenOfType:KEYWORD withArgs:@[@"A"]];
	} else if ([self.buffer rangeOfString:@"true\\b" options:NSRegularExpressionSearch].location != NSNotFound) {
		[self _readLength:4 error:error];
		return [self newTokenOfType:BOOLEAN withArgs:@[@"true"]];
	} else if ([self.buffer rangeOfString:@"false\\b" options:NSRegularExpressionSearch].location != NSNotFound) {
		[self _readLength:5 error:error];
		return [self newTokenOfType:BOOLEAN withArgs:@[@"false"]];
	}
	
	return [self throwError:@"Expected keyword" withError:error];
}

- (SPKSPARQLToken*) getBangWithError:(NSError*__autoreleasing*)error {
	if ([self.buffer hasPrefix:@"!="]) {
		if ([self _readWord:@"!=" error:error]) {
			return [self newTokenOfType:NOTEQUALS withArgs:@[]];
		} else {
			return nil;
		}
	} else {
		[self _getCharSafe:@"!" error:error];
		return [self newTokenOfType:BANG withArgs:@[]];
	}
}

- (SPKSPARQLToken*) getOrWithError:(NSError*__autoreleasing*)error {
	if ([self.buffer hasPrefix:@"||"]) {
		if ([self _readWord:@"||" error:error]) {
			return [self newTokenOfType:OROR withArgs:@[]];
		} else {
			return nil;
		}
	} else {
		[self _getCharSafe:@"|" error:error];
		return [self newTokenOfType:OR withArgs:@[]];
	}
}

- (SPKSPARQLToken*) getLanguageWithError:(NSError*__autoreleasing*)error {
	[self _getCharSafe:@"@" error:error];
	NSRange kwrange	= [self.buffer rangeOfString:@"(prefix|base)\\b" options:NSRegularExpressionSearch];
    NSRange range	= [self.buffer rangeOfString:@"[a-zA-Z]+(-[a-zA-Z0-9]+)*\\b" options:NSRegularExpressionSearch];
	if (kwrange.location == 0) {
		NSString* keyword	= [self _readLength:range.length error:error];
		return [self newTokenOfType:KEYWORD withArgs:@[[keyword uppercaseString]]];
	} else if (range.location == 0) {
		NSString* lang	= [self _readLength:range.length error:error];
		return [self newTokenOfType:LANG withArgs:@[lang]];
	} else {
		return [self throwError: @"Expected language tag" withError:error];
	}
}

- (SPKSPARQLToken*) getDoubleLiteralWithError:(NSError*__autoreleasing*)error {
	[self _getCharSafe: @"\"" error:error];
	if ([self.buffer hasPrefix: @"\"\""]) {
		// #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
		if (![self _readWord:@"\"\"" error:error]) {
			return nil;
		}
		
		int quote_count	= 0;
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			if ([self.buffer length] == 0) {
				[self _fillBuffer];
				if ([self.buffer length] == 0) {
					return [self throwError: @"Found EOF in string literal" withError:error];
				}
			}
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\""]) {
				[self _getChar];
				quote_count++;
				if (quote_count == 3) {
					break;
				}
			} else {
				if (quote_count) {
					int i;
					for (i = 0; i < quote_count; i++) {
						[string appendString: @"\""];
					}
					quote_count	= 0;
				}
				if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
					[self _getChar];
					NSString* esc	= [self _getCharFillBuffer];
					if ([esc isEqualToString:@"\\"]) {
						[string appendString:@"\\"];
					} else if ([esc isEqualToString:@"\""]) {
						[string appendString:@"\""];
					} else if ([esc isEqualToString:@"'"]) {
						[string appendString:@"'"];
					} else if ([esc isEqualToString:@"r"]) {
						[string appendString:@"\r"];
					} else if ([esc isEqualToString:@"t"]) {
						[string appendString:@"\t"];
					} else if ([esc isEqualToString:@"n"]) {
						[string appendString:@"\n"];
					} else if ([esc isEqualToString:@">"]) {
						[string appendString:@">"];
					} else if ([esc isEqualToString:@"U"]) {
						NSString* codepoint	= [self _readLength: 8 error:error];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 8) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
						}
					} else if ([esc isEqualToString:@"u"]) {
						NSString* codepoint	= [self _readLength: 4 error:error];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 4) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
						}
					} else {
						return [self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc] withError:error];
					}
				} else {
					NSRange range	= [self.buffer rangeOfString:@"[^\"\\\\]+" options:NSRegularExpressionSearch];
					[string appendString: [self _readLength: range.length error:error]];
				}
			}
		}
		return [self newTokenOfType:STRING3D withArgs:@[string]];
	} else {
		// #x22 scharacter* #x22
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			NSString* pat		= @"[^\"\\\\]+";
			NSRange range		= [self.buffer rangeOfString:pat options:NSRegularExpressionSearch];
			NSString* c			= [self _peekChar];
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe:@"\\" error:error];
				NSString* esc	= [self _getChar];
				if ([esc isEqualToString:@"\\"]) {
					[string appendString:@"\\"];
				} else if ([esc isEqualToString:@"\""]) {
					[string appendString:@"\""];
				} else if ([esc isEqualToString:@"'"]) {
					[string appendString:@"'"];
				} else if ([esc isEqualToString:@"r"]) {
					[string appendString:@"\r"];
				} else if ([esc isEqualToString:@"t"]) {
					[string appendString:@"\t"];
				} else if ([esc isEqualToString:@"n"]) {
					[string appendString:@"\n"];
				} else if ([esc isEqualToString:@">"]) {
					[string appendString:@">"];
				} else if ([esc isEqualToString:@"U"]) {
					NSString* codepoint	= [self _readLength: 8 error:error];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4 error:error];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else {
					return [self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc] withError:error];
				}
			} else if (range.location == 0) {
				[string appendString: [self _readLength: range.length error:error]];
			} else if ([[self.buffer substringToIndex:1] isEqualToString:@"\""]) {
				break;
			} else {
				return [self throwError: [NSString stringWithFormat:@"Got '%@' while expecting string character", c] withError:error];
			}
		}
		
		[self _getCharSafe: @"\"" error:error];
		return [self newTokenOfType:STRING1D withArgs:@[string]];
	}
}

- (SPKSPARQLToken*) getSingleLiteralWithError:(NSError*__autoreleasing*)error {
	[self _getCharSafe: @"'" error:error];
	if ([self.buffer hasPrefix: @"''"]) {
		if (![self _readWord:@"''" error:error]) {
			return nil;
		}
		
		int quote_count	= 0;
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			if ([self.buffer length] == 0) {
				[self _fillBuffer];
				if ([self.buffer length] == 0) {
					return [self throwError: @"Found EOF in string literal" withError:error];
				}
			}
			if ([[self.buffer substringToIndex:1] isEqualToString:@"'"]) {
				[self _getChar];
				quote_count++;
				if (quote_count == 3) {
					break;
				}
			} else {
				if (quote_count) {
					int i;
					for (i = 0; i < quote_count; i++) {
						[string appendString: @"'"];
					}
					quote_count	= 0;
				}
				if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
					[self _getChar];
					NSString* esc	= [self _getCharFillBuffer];
					if ([esc isEqualToString:@"\\"]) {
						[string appendString:@"\\"];
					} else if ([esc isEqualToString:@"\""]) {
						[string appendString:@"\""];
					} else if ([esc isEqualToString:@"'"]) {
						[string appendString:@"'"];
					} else if ([esc isEqualToString:@"r"]) {
						[string appendString:@"\r"];
					} else if ([esc isEqualToString:@"t"]) {
						[string appendString:@"\t"];
					} else if ([esc isEqualToString:@"n"]) {
						[string appendString:@"\n"];
					} else if ([esc isEqualToString:@">"]) {
						[string appendString:@">"];
					} else if ([esc isEqualToString:@"U"]) {
						NSString* codepoint	= [self _readLength: 8 error:error];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 8) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
						}
					} else if ([esc isEqualToString:@"u"]) {
						NSString* codepoint	= [self _readLength: 4 error:error];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 4) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
						}
					} else {
						return [self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc] withError:error];
					}
				} else {
					NSRange range	= [self.buffer rangeOfString:@"[^'\\\\]+" options:NSRegularExpressionSearch];
					[string appendString: [self _readLength: range.length error:error]];
				}
			}
		}
		return [self newTokenOfType:STRING3S withArgs:@[string]];
	} else {
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			NSString* pat		= @"[^'\\\\]+";
			NSRange range		= [self.buffer rangeOfString:pat options:NSRegularExpressionSearch];
			NSString* c			= [self _peekChar];
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe:@"\\" error:error];
				NSString* esc	= [self _getChar];
				if ([esc isEqualToString:@"\\"]) {
					[string appendString:@"\\"];
				} else if ([esc isEqualToString:@"\""]) {
					[string appendString:@"\""];
				} else if ([esc isEqualToString:@"'"]) {
					[string appendString:@"'"];
				} else if ([esc isEqualToString:@"r"]) {
					[string appendString:@"\r"];
				} else if ([esc isEqualToString:@"t"]) {
					[string appendString:@"\t"];
				} else if ([esc isEqualToString:@"n"]) {
					[string appendString:@"\n"];
				} else if ([esc isEqualToString:@">"]) {
					[string appendString:@">"];
				} else if ([esc isEqualToString:@"U"]) {
					NSString* codepoint	= [self _readLength: 8 error:error];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4 error:error];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else {
					return [self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc] withError:error];
				}
			} else if (range.location == 0) {
				[string appendString: [self _readLength: range.length error:error]];
			} else if ([[self.buffer substringToIndex:1] isEqualToString:@"'"]) {
				break;
			} else {
				return [self throwError: [NSString stringWithFormat:@"Got '%@' while expecting string character", c] withError:error];
			}
		}
		
		[self _getCharSafe: @"'" error:error];
		return [self newTokenOfType:STRING1S withArgs:@[string]];
	}
}

- (SPKSPARQLToken*) getIRIRefOrRelationalWithError:(NSError*__autoreleasing*)error {
	NSRange iri_range		= [self.buffer rangeOfString:@"<([^<>\"{}|^`\\x{00}-\\x{20}])*>" options:NSRegularExpressionSearch];
	if (iri_range.location == 0) {
		[self _getCharSafe:@"<" error:error];
		NSMutableString* iri	= [NSMutableString string];
		while (1) {
			NSRange iri_char_range	= [self.buffer rangeOfString:@"[^>\\\\]+" options:NSRegularExpressionSearch];
			NSString* c	= [self _peekChar];
			if (c == nil) {
				break;
			}
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe: @"\\" error:error];
				NSString* esc	= [self _getChar];
				if ([esc isEqualToString:@"\\"]) {
					[iri appendString:@"\\"];
				} else if ([esc isEqualToString:@"\""]) {
					[iri appendString:@"\""];
				} else if ([esc isEqualToString:@"'"]) {
					[iri appendString:@"'"];
				} else if ([esc isEqualToString:@"r"]) {
					[iri appendString:@"\r"];
				} else if ([esc isEqualToString:@"t"]) {
					[iri appendString:@"\t"];
				} else if ([esc isEqualToString:@"n"]) {
					[iri appendString:@"\n"];
				} else if ([esc isEqualToString:@">"]) {
					[iri appendString:@">"];
				} else if ([esc isEqualToString:@"U"]) {
					NSString* codepoint	= [self _readLength: 8 error:error];
					NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (range.location == 0 && range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[iri appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4 error:error];
					NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (range.location == 0 && range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[iri appendString: str];
					} else {
						return [self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint] withError:error];
					}
				} else {
					return [self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc] withError:error];
				}
			} else if (iri_char_range.location == 0) {
				[iri appendString: [self _readLength: iri_char_range.length error:error]];
			} else if ([c isEqualToString:@">"]) {
				break;
			} else {
				return [self throwError: [NSString stringWithFormat: @"Got '%@' while expecting IRI character", c] withError:error];
			}
		}
		[self _getCharSafe:@">" error:error];
		return [self newTokenOfType:IRI withArgs:@[iri]];
	} else {
        if ([self.buffer hasPrefix:@"<"]) {
            [self _getCharSafe:@"<" error:error];
            NSString* c	= [self _peekChar];
            if ([c isEqualToString:@"="]) {
                [self _getCharSafe:@"=" error:error];
                return [self newTokenOfType:LE withArgs:@[]];
            } else {
                return [self newTokenOfType:LT withArgs:@[]];
            }
        } else {
            [self _getCharSafe:@">" error:error];
            NSString* c	= [self _peekChar];
            if ([c isEqualToString:@"="]) {
                [self _getCharSafe:@"=" error:error];
                return [self newTokenOfType:GE withArgs:@[]];
            } else {
                return [self newTokenOfType:GT withArgs:@[]];
            }
        }
	}
}

- (BOOL) _lookaheadWithError:(NSError*__autoreleasing*)error {
    if (!self.lookahead) {
        SPKSPARQLToken* t   = [self _getTokenWithError:error];
        if (*error)
            return NO;
        self.lookahead      = t;
    }
    return YES;
}

- (SPKSPARQLToken*) peekTokenWithError:(NSError*__autoreleasing*)error {
    BOOL ok = [self _lookaheadWithError:error];
    if (!ok)
        return nil;
    return self.lookahead;
}

- (SPKSPARQLToken*) getTokenWithError:(NSError*__autoreleasing*)error {
    [self _lookaheadWithError:error];
    SPKSPARQLToken* t   = self.lookahead;
    self.lookahead      = nil;
    return t;
}

- (SPKSPARQLToken*) _getTokenWithError:(NSError*__autoreleasing*)error {
	NSDictionary* charTokens	= SPARQLCharTokens();
	NSCharacterSet* pnCharSet	= SPARQLPrefixNameStartChar();
	while (1) {
	NEXT:		;
		if ([self.buffer length] == 0) {
			[self _fillBuffer];
		}
		if ([self.buffer length] == 0) {
			return nil;
		}
		
		NSString* c;
		unichar cc;
		c	= [self _peekChar];
		cc	= [c characterAtIndex:0];
		self.startColumn	= self.column;
		self.startLine		= self.line;
		self.startCharacter	= self.character;
		
		NSRange nil_range		= [self.buffer rangeOfString:@"[(][ \r\n\t]*[)]" options:NSRegularExpressionSearch];
		NSRange double_range	= [self.buffer rangeOfString:@"(([0-9]+[.][0-9]*[eE][+-]?[0-9]+)|([.][0-9]+[eE][+-]?[0-9]+)|([0-9]+[eE][+-]?[0-9]+))" options:NSRegularExpressionSearch];
        NSRange decimal_range   = [self.buffer rangeOfString:@"[0-9]*[.][0-9]+" options:NSRegularExpressionSearch];
		NSRange integer_range	= [self.buffer rangeOfString:@"[0-9]+" options:NSRegularExpressionSearch];
        NSRange anon_range      = [self.buffer rangeOfString:@"\\[[ \x0a\x0d\x09]*\\]" options:NSRegularExpressionSearch];
		
		// WS
		if ([c isEqualToString:@" "] || [c isEqualToString:@"\r"] || [c isEqualToString:@"\n"] || [c isEqualToString:@"\t"]) {
			while ([c length] > 0 && ([c isEqualToString:@" "] || [c isEqualToString:@"\r"] || [c isEqualToString:@"\n"] || [c isEqualToString:@"\t"])) {
				[self _getChar];
				
				c	= [self _peekChar];
			}
			
            // we're ignoring whitespace tokens, but we could return them here instead of falling through to the 'next':
			goto NEXT;
		}
		
		// COMMENT
		if ([c isEqualToString:@"#"]) {
            // we're ignoring comment tokens, but we could return them here instead of falling through to the 'next':
			SPKSPARQLToken* t	= [self _getCommentWithError:error];
			if (self.comments) {
				return t;
			} else {
				goto NEXT;
			}
		}
		
		// NIL
		if (nil_range.location == 0) {
			[self _readLength:nil_range.length error:error];
			return [self newTokenOfType:NIL withArgs:@[]];
		}
		
        // ANON
        if (anon_range.location == 0) {
			[self _readLength:anon_range.length error:error];
			return [self newTokenOfType:ANON withArgs:@[]];
        }
        // DOUBLE
        if (double_range.location == 0) {
            NSString* value  = [self _readLength:double_range.length error:error];
            return [self newTokenOfType:DOUBLE withArgs:@[value]];
        }
        
        // DECIMAL
        if (decimal_range.location == 0) {
            NSString* value  = [self _readLength:decimal_range.length error:error];
            return [self newTokenOfType:DECIMAL withArgs:@[value]];
        }
        
        // INTEGER
		if (integer_range.location == 0) {
            NSString* value  = [self _readLength:integer_range.length error:error];
            return [self newTokenOfType:INTEGER withArgs:@[value]];
		}
        
        // HAT / HATHAT
		if ([c isEqualToString:@"^"]) {
			if ([self.buffer hasPrefix:@"^^"]) {
				if ([self _readWord: @"^^" error:error]) {
					return [self newTokenOfType:HATHAT withArgs:@[]];
				} else {
					return nil;
				}
			} else {
				if ([self _readWord: @"^" error:error]) {
					return [self newTokenOfType:HAT withArgs:@[]];
				} else {
					return nil;
				}
			}
        }
        // Single char dispatch:
        // - LANG
        // - IRIREF
        // - VAR / QUESTION
        // - NOTEQUALS / BANG
        // - LE / LT
        // - GE / GT
        // - OROR / OR
        // - STRING3D / STRING1D
        // - STRING3S / STRING1S
        // - BNODE
        if ([c isEqualToString: @"@"]) {
			return [self getLanguageWithError:error];
        } else if ([c isEqualToString: @"<"]) {
			return [self getIRIRefOrRelationalWithError:error];
        } else if ([c isEqualToString: @"?"]) {
			return [self getVariableWithError:error];
        } else if ([c isEqualToString: @"$"]) {
			return [self getVariableWithError:error];
        } else if ([c isEqualToString: @"!"]) {
			return [self getBangWithError:error];
        } else if ([c isEqualToString: @">"]) {
			return [self getIRIRefOrRelationalWithError:error];
        } else if ([c isEqualToString: @"|"]) {
			return [self getOrWithError:error];
        } else if ([c isEqualToString: @"'"]) {
			return [self getSingleLiteralWithError:error];
        } else if ([c isEqualToString: @"\""]) {
			return [self getDoubleLiteralWithError:error];
        } else if ([c isEqualToString: @"_"]) {
			return [self getBnodeWithError:error];
        } else if ([c isEqualToString: @":"]) {
			return [self getPNameWithError:error];
        }
        
        
        // Direct mapping:
        // - COMMA
        // - DOT
        // - EQUALS
        // - LBRACE
        // - LBRACKET
        // - LPAREN
        // - MINUS
        // - PLUS
        // - RBRACE
        // - RBRACKET
        // - RPAREN
        // - SEMICOLON
        // - SLASH
        // - STAR
		
		NSNumber* number;
		if ((number = charTokens[c])) {
			[self _getChar];
			return [self newTokenOfType:(SPKSPARQLTokenType)[number integerValue] withArgs:@[c]];
		}
        // - ANDAND
		else if ([c isEqualToString:@"&"]) {
			if ([self _readWord: @"&&" error:error]) {
				return [self newTokenOfType:ANDAND withArgs:@[]];
			} else {
				return nil;
			}
        }
        // PREFIXNAME
		else if ([pnCharSet characterIsMember:cc]) {
			SPKSPARQLToken* t	= [self getPNameWithError:error];
			if (t) {
				return t;
			}
		}
        
        // KEYWORD / BOOLEAN
		SPKSPARQLToken* t   = [self _getKeywordWithError:error];
        return t;
    }
}

- (id)throwError: (NSString*) message withError:(NSError*__autoreleasing*)error {
    NSDictionary* dict  = @{@"description": message, @"line": @(self.line), @"column": @(self.column), @"buffer": self.buffer};
    NSError* e  = [NSError errorWithDomain:@"us.kasei.sparql.lexer" code:1 userInfo:dict];
    if (error) {
        *error  = e;
    } else {
        NSLog(@"No error object to set for error: %@", e);
    }
    //	NSLog(@"%lu:%lu: %@\n", self.line, (unsigned long)self.column, message);
    //	NSLog(@"buffer: '%@'", self.buffer);
	return nil;
}

@end
