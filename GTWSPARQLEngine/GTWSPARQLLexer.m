#import "GTWSPARQLLexer.h"


static NSSet* SPARQLKeywords() {
    static NSSet *_SPARQLKeywords = nil;
    static dispatch_once_t keywordsOnceToken;
    dispatch_once(&keywordsOnceToken, ^{
        _SPARQLKeywords = [NSSet setWithObjects:@"ABS", @"ADD", @"ALL", @"AS", @"ASC", @"ASK", @"AVG", @"BASE", @"BIND", @"BNODE", @"BOUND", @"BY", @"CEIL", @"CLEAR", @"COALESCE", @"CONCAT", @"CONSTRUCT", @"CONTAINS", @"COPY", @"COUNT", @"CREATE", @"DATATYPE", @"DAY", @"DEFAULT", @"DELETE", @"DELETE DATA", @"DELETE WHERE", @"DESC", @"DESCRIBE", @"DISTINCT", @"DISTINCT", @"DROP", @"ENCODE_FOR_URI", @"EXISTS", @"FILTER", @"FLOOR", @"FROM", @"GRAPH", @"GROUP", @"GROUP_CONCAT", @"HAVING", @"HOURS", @"IF", @"IN", @"INSERT", @"INSERT DATA", @"INTO", @"IRI", @"ISBLANK", @"ISIRI", @"ISLITERAL", @"ISNUMERIC", @"ISURI", @"LANG", @"LANGMATCHES", @"LCASE", @"LIMIT", @"LOAD", @"MAX", @"MD5", @"MIN", @"MINUS", @"MINUTES", @"MONTH", @"MOVE", @"NAMED", @"NOT", @"NOW", @"OFFSET", @"OPTIONAL", @"ORDER", @"PREFIX", @"RAND", @"REDUCED", @"REGEX", @"REPLACE", @"ROUND", @"SAMETERM", @"SAMPLE", @"SECONDS", @"SELECT", @"SEPARATOR", @"SERVICE", @"SHA1", @"SHA256", @"SHA384", @"SHA512", @"SILENT", @"STR", @"STRAFTER", @"STRBEFORE", @"STRDT", @"STRENDS", @"STRLANG", @"STRLEN", @"STRSTARTS", @"STRUUID", @"SUBSTR", @"SUM", @"TIMEZONE", @"TO", @"TZ", @"UCASE", @"UNDEF", @"UNION", @"URI", @"USING", @"UUID", @"VALUES", @"WHERE", @"WITH", @"YEAR", nil];
    });
    
    return _SPARQLKeywords;
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
                              //		@"-": [NSNumber numberWithLong:MINUS],
                              //		@"+": [NSNumber numberWithLong:PLUS],
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

static NSDictionary* SPARQLMethodTokens() {
	static NSDictionary *_SPARQLMethodTokens = nil;
	static dispatch_once_t methodOnceToken;
	dispatch_once(&methodOnceToken, ^{
		_SPARQLMethodTokens = @{
                                @"@": [NSValue valueWithPointer:@selector(getLanguage)],
                                @"<": [NSValue valueWithPointer:@selector(getIRIRefOrRelational)],
                                @"?": [NSValue valueWithPointer:@selector(getVariable)],
                                @"$": [NSValue valueWithPointer:@selector(getVariable)],
                                @"!": [NSValue valueWithPointer:@selector(getBang)],
                                @">": [NSValue valueWithPointer:@selector(getRelational)],
                                @"|": [NSValue valueWithPointer:@selector(getOr)],
                                @"'": [NSValue valueWithPointer:@selector(getSingleLiteral)],
                                @"\"": [NSValue valueWithPointer:@selector(getDoubleLiteral)],
                                @"_": [NSValue valueWithPointer:@selector(getBnode)],
                                @":": [NSValue valueWithPointer:@selector(getPName)]
                                };
	});
	
    return _SPARQLMethodTokens;
}

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


@implementation GTWSPARQLLexer

- (GTWSPARQLLexer*) init {
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

- (GTWSPARQLLexer*) initWithString: (NSString*) string {
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

- (GTWSPARQLLexer*) initWithFileHandle: (NSFileHandle*) handle {
	if (self = [self init]) {
		self.file			= handle;
	}
	return self;
}

- (GTWSPARQLToken*) newTokenOfType: (GTWSPARQLTokenType) type withArgs: (NSArray*) args {
	NSUInteger start	= self.startCharacter;
	NSUInteger length	= self.character - start;
	NSRange range	= { .location = start, .length = length };
	return [[GTWSPARQLToken alloc] initTokenOfType:type withArguments:args fromRange:range];
}

- (void) _fillBuffer {
	NSMutableData* linebuffer	= [[NSMutableData alloc] init];
    //	NSLog(@"trying to fill buffer with existing buffer '%@' (%lu)", self.buffer, [self.buffer length]);
	if ([self.buffer length] == 0) {
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
        //			$line		=~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/ge;	 // TODO
        //			$line		=~ s/\\U([0-9A-Fa-f]{8})/chr(hex($1))/ge;	 // TODO
		[self.buffer appendString:line];
	}
    //	NSLog(@"- '%@' (%lu)", self.buffer, [self.buffer length]);
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

- (NSString*) _getCharSafe: (NSString*) expected {
	NSString* c	= [self _getChar];
	if ([c isNotEqualTo:expected]) {
		[self throwError:[NSString stringWithFormat:@"Expected '%@' but got '%@'", expected, c]];
		return nil;
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

- (BOOL) _readWord: (NSString*) word {
	while ([self.buffer length] < [word length]) {
		NSUInteger len	= [self.buffer length];
		[self _fillBuffer];
		if (len == [self.buffer length]) {
			[self throwError:[NSString stringWithFormat:@"Expected '%@', but not enough read-ahead data available", word]];
			return NO;
		}
	}
	
	if (([self.buffer length] < [word length]) || (![self.buffer hasPrefix:word])) {
		[self throwError:[NSString stringWithFormat:@"Expected '%@'", word]];
		return NO;
	}
	
	NSMutableString* mword	= [NSMutableString stringWithString: word];
	NSRange range	= {0, [mword length]};
	NSUInteger lines	= [mword replaceOccurrencesOfString:@"\n" withString:@"\n" options:NSLiteralSearch range:range];
	
	// TODO
    //	my $lastnl	= rindex($word, "\n");	// TODO
    //	my $cols	= length($word) - $lastnl - 1;
	self.line	+= lines;
    //	if (lines) {
    //		self.column	= $cols;
    //	} else {
    //		self.column	+= $cols;
    //	}
	
	self.character	+= [word length];
	range.location	= 0;
	range.length	= [word length];
	[self.buffer deleteCharactersInRange:range];
	return YES;
}

- (NSString*) _readLength: (NSUInteger) length {
	while ([self.buffer length] < length) {
		[self _fillBuffer];
	}
	
	if ([self.buffer length] < length) {
		NSUInteger remaining	= [self.buffer length];
		[self throwError:[NSString stringWithFormat:@"Expecting %lu bytes but only %lu remaining", (unsigned long)length, (unsigned long)remaining]];
		return nil;
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
	//	my $lastnl	= rindex($word, "\n");	// TODO
	//	my $cols	= length($word) - $lastnl - 1;
	self.line	+= lines;
	//	if (lines) {
	//		self.column	= $cols;
	//	} else {
	//		self.column	+= $cols;
	//	}
    
	self.character	+= [word length];
	return word;
}

- (GTWSPARQLToken*) newPName: (NSArray*) pname {
	return [self newTokenOfType:PREFIXNAME withArgs:pname];
}

- (GTWSPARQLToken*) getPName {
	NSString* r_PNAME_LN	= @"((((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[:0-9]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2}))(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})|[:.])*((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[:]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})))?))";
	NSString* r_PNAME_NS	= @"(((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)";
	NSRange range	= [self.buffer rangeOfString:r_PNAME_LN options:NSRegularExpressionSearch];
	NSRange range2	= [self.buffer rangeOfString:r_PNAME_NS options:NSRegularExpressionSearch];
	if (range.location == 0) {
		NSString* pname	= [self _readLength:range.length];
		NSArray* values	= [pname componentsSeparatedByString:@":"];
        //# 		warn "full prefixedname: '$pname'";
		return [self newPName: values];
	} else if (range2.location == 0) {
		NSString* pname	= [self _readLength:range2.length];
		NSArray* values	= [pname componentsSeparatedByString:@":"];
        //# 		warn "prefix: '$pname'";
		return [self newPName: values];
	} else {
        //		NSLog(@"returning nil pname");
		return nil;
	}
}

- (GTWSPARQLToken*) getBnode {
	[self _getCharSafe:@"_"];
	[self _getCharSafe:@":"];
    //	NSString* r_NAME_START_CHAR	= @"[A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}]";
    //	NSString* r_NAMECHAR_EXTRA	= @"[-0-9\\x{00B7}\\x{0300}-\\x{036F}\\x{203F}-\\x{2040}]";
    NSString* r_bnode   = @"^([A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])(([A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])|([-0-9\\x{00B7}\\x{0300}-\\x{036F}\\x{203F}-\\x{2040}]))*";
	NSRange range	= [self.buffer rangeOfString:r_bnode options:NSRegularExpressionSearch];
	if (range.location == 0) {
		NSString* name	= [self _readLength:range.length];
        //        NSLog(@"got bnode name ===> %@", name);
        return [self newTokenOfType:BNODE withArgs:@[name]];
	} else {
        //		NSLog(@"returning nil pname");
		return nil;
	}
}

- (GTWSPARQLToken*) _getComment {
	[self _getCharSafe:@"#"];
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

- (GTWSPARQLToken*) _getNumber {
	NSRange integer_range	= [self.buffer rangeOfString:@"[0-9]+" options:NSRegularExpressionSearch];
    NSRange double_range	= [self.buffer rangeOfString:@"[+-]?(([0-9]+[.][0-9]*[eE][+-]?[0-9]+)|([.][0-9]+[eE][+-]?[0-9]+)|([0-9]+[eE][+-]?[0-9]+))" options:NSRegularExpressionSearch];
    //	if ($self->{buffer} =~ /^${r_double}\b/) {
    //		return $self->new_token(DOUBLE, $self->_read_length($+[0]));
    //	} else if ($self->{buffer} =~ /^${r_decimal}\b/) {
    //		return $self->new_token(DECIMAL, $self->_read_length($+[0]));
    //	} else if ($self->{buffer} =~ /^${r_integer}\b/) {
	if (integer_range.location == 0) {
		NSString* integer	= [self _readLength:integer_range.length];
		return [self newTokenOfType:INTEGER withArgs:@[integer]];
    } else if (double_range.location == 0) {
		NSString* value	= [self _readLength:integer_range.length];
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
			[self throwError:@"Expected number"];
			return nil;
		}
	}
}

- (GTWSPARQLToken*) getVariable {
	NSString* c	= [self _getChar];
	NSRange range	= [self.buffer rangeOfString:@"((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9])(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])*)" options:NSRegularExpressionSearch];
    
	if (range.location != 0) {
		if ([c isEqualToString:@"?"]) {
			return [self newTokenOfType:QUESTION withArgs:@[]];
		} else {
			[self throwError:@"Expected variable name"];
			return nil;
		}
	}
	
	NSString* name	= [self _readLength:range.length];
	return [self newTokenOfType:VAR withArgs:@[name]];
}

- (GTWSPARQLToken*) _getKeyword {
	NSSet* keywords	= SPARQLKeywords();
	for (NSString* kw in keywords) {
		NSRange range	= [self.buffer rangeOfString:kw options:NSAnchoredSearch|NSCaseInsensitiveSearch];
		if (range.location != NSNotFound) {
			[self _readLength:[kw length]];
			return [self newTokenOfType:KEYWORD withArgs:@[[kw uppercaseString]]];
		}
	}
    
	NSRange range	= [self.buffer rangeOfString:@"a\\b" options:NSRegularExpressionSearch];
	if (range.location == 0) {
		[self _readLength:1];
		// TODO make sure there is a word boundary after true/false (a|true|false)\b
		return [self newTokenOfType:KEYWORD withArgs:@[@"A"]];
	} else if ([self.buffer hasPrefix:@"true"]) {
		[self _readLength:4];
		// TODO make sure there is a word boundary after true/false (true|false)\b
		return [self newTokenOfType:BOOLEAN withArgs:@[@"true"]];
	} else if ([self.buffer hasPrefix:@"false"]) {
		[self _readLength:5];
		return [self newTokenOfType:BOOLEAN withArgs:@[@"false"]];
	}
	
	[self throwError:@"Expected keyword"];
    //	NSLog(@"returning nil keyword");
	return nil;
}

- (GTWSPARQLToken*) getBang {
	if ([self.buffer hasPrefix:@"!="]) {
		if ([self _readWord:@"!="]) {
			return [self newTokenOfType:NOTEQUALS withArgs:@[]];
		} else {
			return nil;
		}
	} else {
		[self _getCharSafe:@"!"];
		return [self newTokenOfType:BANG withArgs:@[]];
	}
}

- (GTWSPARQLToken*) getOr {
	if ([self.buffer hasPrefix:@"||"]) {
		if ([self _readWord:@"||"]) {
			return [self newTokenOfType:OROR withArgs:@[]];
		} else {
			return nil;
		}
	} else {
		[self _getCharSafe:@"|"];
		return [self newTokenOfType:OR withArgs:@[]];
	}
}

- (GTWSPARQLToken*) getLanguage {
	[self _getCharSafe:@"@"];
	NSRange kwrange	= [self.buffer rangeOfString:@"(prefix|base)\\b" options:NSRegularExpressionSearch];
    NSRange range	= [self.buffer rangeOfString:@"[a-z]+(-[a-zA-Z0-9]+)*\\b" options:NSRegularExpressionSearch];
	if (kwrange.location == 0) {
		NSString* keyword	= [self _readLength:range.length];
		return [self newTokenOfType:KEYWORD withArgs:@[keyword]];
	} else if (range.location == 0) {
		NSString* lang	= [self _readLength:range.length];
		return [self newTokenOfType:LANG withArgs:@[lang]];
	} else {
		[self throwError: @"Expected language tag"];
		return nil;
	}
}

- (GTWSPARQLToken*) getDoubleLiteral {
	//	NSString* c	= [self _peekChar];
	[self _getCharSafe: @"\""];
	if ([self.buffer hasPrefix: @"\"\""]) {
		// #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
		if (![self _readWord:@"\"\""]) {
			return nil;
		}
		
		int quote_count	= 0;
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			if ([self.buffer length] == 0) {
				[self _fillBuffer];
				if ([self.buffer length] == 0) {
					[self throwError: @"Found EOF in string literal"];
					return nil;
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
						NSString* codepoint	= [self _readLength: 8];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 8) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
							return nil;
						}
					} else if ([esc isEqualToString:@"u"]) {
						NSString* codepoint	= [self _readLength: 4];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 4) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
							return nil;
						}
					} else {
						[self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc]];
						return nil;
					}
				} else {
					NSRange range	= [self.buffer rangeOfString:@"[^\"\\\\]+" options:NSRegularExpressionSearch];
                    //                    NSLog(@"reading length %lu with buffer: >>>%@", range.length, self.buffer);
					[string appendString: [self _readLength: range.length]];
				}
			}
		}
		return [self newTokenOfType:STRING3D withArgs:@[string]];
	} else {
		// #x22 scharacter* #x22
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			NSString* pat		= @"[^\"\\\\]+";
            //			NSLog(@"pattern: '%@'", pat);
			NSRange range		= [self.buffer rangeOfString:pat options:NSRegularExpressionSearch];
			NSString* c			= [self _peekChar];
            //			NSLog(@"double quoted string character ('%@'): { %lu, %lu }", c, range.location, range.length);
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe:@"\\"];
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
					NSString* codepoint	= [self _readLength: 8];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else {
					[self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc]];
					return nil;
				}
			} else if (range.location == 0) {
				[string appendString: [self _readLength: range.length]];
			} else if ([[self.buffer substringToIndex:1] isEqualToString:@"\""]) {
				break;
			} else {
				[self throwError: [NSString stringWithFormat:@"Got '%@' while expecting string character", c]];
				return nil;
			}
		}
		
		[self _getCharSafe: @"\""];
		return [self newTokenOfType:STRING1D withArgs:@[string]];
	}
}

- (GTWSPARQLToken*) getSingleLiteral {
	//	NSString* c	= [self _peekChar];
	[self _getCharSafe: @"'"];
	if ([self.buffer hasPrefix: @"''"]) {
		if (![self _readWord:@"''"]) {
			return nil;
		}
		
		int quote_count	= 0;
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			if ([self.buffer length] == 0) {
				[self _fillBuffer];
				if ([self.buffer length] == 0) {
					[self throwError: @"Found EOF in string literal"];
					return nil;
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
						NSString* codepoint	= [self _readLength: 8];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 8) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
							return nil;
						}
					} else if ([esc isEqualToString:@"u"]) {
						NSString* codepoint	= [self _readLength: 4];
						NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
						if (range.location == 0 && range.length == 4) {
							NSScanner *scanner = [NSScanner scannerWithString:codepoint];
							unsigned int ucint;
							[scanner scanHexInt:&ucint];
							unichar uc	= (unichar) ucint;
							NSString* str	= [NSString stringWithCharacters:&uc length:1];
							[string appendString: str];
						} else {
							[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
							return nil;
						}
					} else {
						[self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc]];
						return nil;
					}
				} else {
					NSRange range	= [self.buffer rangeOfString:@"[^'\\\\]+" options:NSRegularExpressionSearch];
					[string appendString: [self _readLength: range.length]];
				}
			}
		}
		return [self newTokenOfType:STRING3S withArgs:@[string]];
	} else {
		NSMutableString* string	= [NSMutableString string];
		while (1) {
			NSString* pat		= @"[^'\\\\]+";
            //			NSLog(@"pattern: '%@'", pat);
			NSRange range		= [self.buffer rangeOfString:pat options:NSRegularExpressionSearch];
			NSString* c			= [self _peekChar];
            //			NSLog(@"single quoted string character ('%@'): { %lu, %lu }", c, range.location, range.length);
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe:@"\\"];
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
					NSString* codepoint	= [self _readLength: 8];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4];
					NSRange hex_range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (hex_range.location == 0 && hex_range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[string appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else {
					[self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc]];
					return nil;
				}
			} else if (range.location == 0) {
				[string appendString: [self _readLength: range.length]];
			} else if ([[self.buffer substringToIndex:1] isEqualToString:@"'"]) {
				break;
			} else {
				[self throwError: [NSString stringWithFormat:@"Got '%@' while expecting string character", c]];
				return nil;
			}
		}
		
		[self _getCharSafe: @"'"];
		return [self newTokenOfType:STRING1S withArgs:@[string]];
	}
}

- (GTWSPARQLToken*) getIRIRefOrRelational {
	NSRange iri_range		= [self.buffer rangeOfString:@"<([^<>\"{}|^`\\x{00}-\\x{20}])*>" options:NSRegularExpressionSearch];
	if (iri_range.location == 0) {
		[self _getCharSafe:@"<"];
		NSMutableString* iri	= [NSMutableString string];
		while (1) {
			NSRange iri_char_range	= [self.buffer rangeOfString:@"[^>\\\\]+" options:NSRegularExpressionSearch];
			NSString* c	= [self _peekChar];
			if (c == nil) {
				break;
			}
			if ([[self.buffer substringToIndex:1] isEqualToString:@"\\"]) {
				[self _getCharSafe: @"\\"];
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
					NSString* codepoint	= [self _readLength: 8];
					NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (range.location == 0 && range.length == 8) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[iri appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else if ([esc isEqualToString:@"u"]) {
					NSString* codepoint	= [self _readLength: 4];
					NSRange range	= [codepoint rangeOfString:@"[0-9A-Fa-f]+" options:NSRegularExpressionSearch];
					if (range.location == 0 && range.length == 4) {
						NSScanner *scanner = [NSScanner scannerWithString:codepoint];
						unsigned int ucint;
						[scanner scanHexInt:&ucint];
						unichar uc	= (unichar) ucint;
						NSString* str	= [NSString stringWithCharacters:&uc length:1];
						[iri appendString: str];
					} else {
						[self throwError: [NSString stringWithFormat: @"Bad unicode escape codepoint '%@'", codepoint]];
						return nil;
					}
				} else {
					[self throwError: [NSString stringWithFormat:@"Unrecognized string escape '%@'", esc]];
					return nil;
				}
			} else if (iri_char_range.location == 0) {
				[iri appendString: [self _readLength: iri_char_range.length]];
			} else if ([c isEqualToString:@">"]) {
				break;
			} else {
				[self throwError: [NSString stringWithFormat: @"Got '%@' while expecting IRI character", c]];
				return nil;
			}
		}
		[self _getCharSafe:@">"];
		return [self newTokenOfType:IRI withArgs:@[iri]];
	} else {
		[self _getCharSafe:@"<"];
		NSString* c	= [self _peekChar];
		if ([c isEqualToString:@"="]) {
			[self _getCharSafe:@"="];
			return [self newTokenOfType:LE withArgs:@[]];
		} else {
			return [self newTokenOfType:LT withArgs:@[]];
		}
	}
}

- (void) _lookahead {
    if (!self.lookahead) {
        GTWSPARQLToken* t   = [self _getToken];
        self.lookahead      = t;
    }
}

- (GTWSPARQLToken*) peekToken {
    [self _lookahead];
    return self.lookahead;
}

- (GTWSPARQLToken*) getToken {
    [self _lookahead];
    GTWSPARQLToken* t   = self.lookahead;
    self.lookahead      = nil;
    return t;
}

- (GTWSPARQLToken*) _getToken {
	NSDictionary* charTokens	= SPARQLCharTokens();
    //	NSDictionary* methodTokens	= SPARQLMethodTokens();
	NSCharacterSet* pnCharSet	= SPARQLPrefixNameStartChar();
	while (1) {
	NEXT:		;
		if ([self.buffer length] == 0) {
			[self _fillBuffer];
		}
		if ([self.buffer length] == 0) {
			return nil;
		}
		
        //		NSLog(@"- getToken called with buffer '%@'\n", self.buffer);
		NSString* c;
		unichar cc;
		// 		warn "getting token with buffer: " . Dumper($self->{buffer});
		c	= [self _peekChar];
		cc	= [c characterAtIndex:0];
		self.startColumn	= self.column;
		self.startLine		= self.line;
		self.startCharacter	= self.character;
		
		NSRange bnode_range		= [self.buffer rangeOfString:@"[(][ \r\n\t]*[)]" options:NSRegularExpressionSearch];
		NSRange double_range	= [self.buffer rangeOfString:@"[-+]?(([0-9]+[.][0-9]*[eE][+-]?[0-9]+)|([.][0-9]+[eE][+-]?[0-9]+)|([0-9]+[eE][+-]?[0-9]+))" options:NSRegularExpressionSearch];
        NSRange decimal_range   = [self.buffer rangeOfString:@"[-+]?[0-9]*[.][0-9]+" options:NSRegularExpressionSearch];
		NSRange integer_range	= [self.buffer rangeOfString:@"[-+]?[0-9]+" options:NSRegularExpressionSearch];
//		NSRange anon_range		= [self.buffer rangeOfString:@"\\[\\]" options:NSRegularExpressionSearch];
		
		// WS
		if ([c isEqualToString:@" "] || [c isEqualToString:@"\r"] || [c isEqualToString:@"\n"] || [c isEqualToString:@"\t"]) {
			while ([c length] > 0 && ([c isEqualToString:@" "] || [c isEqualToString:@"\r"] || [c isEqualToString:@"\n"] || [c isEqualToString:@"\t"])) {
				[self _getChar];
				
				c	= [self _peekChar];
			}
			
            // we're ignoring whitespace tokens, but we could return them here instead of falling through to the 'next':
			// 			return $self->new_token(WS);
			goto NEXT;
		}
		
		// COMMENT
		if ([c isEqualToString:@"#"]) {
            // we're ignoring comment tokens, but we could return them here instead of falling through to the 'next':
			GTWSPARQLToken* t	= [self _getComment];
			if (self.comments) {
				return t;
			} else {
				goto NEXT;
			}
		}
		
		// NIL
		if (bnode_range.location == 0) {
			[self _readLength:bnode_range.length];
			return [self newTokenOfType:NIL withArgs:@[]];
		}
		
        // ANON
        if ([self.buffer hasPrefix:@"[]"]) {
			[self _readLength:2];
			return [self newTokenOfType:ANON withArgs:@[]];
        }
        // DOUBLE
        if (double_range.location == 0) {
            NSString* value  = [self _readLength:double_range.length];
            return [self newTokenOfType:DOUBLE withArgs:@[value]];
        }
        
        // DECIMAL
        if (decimal_range.location == 0) {
            NSString* value  = [self _readLength:decimal_range.length];
            return [self newTokenOfType:DECIMAL withArgs:@[value]];
        }
        
        // INTEGER
		if (integer_range.location == 0) {
            NSString* value  = [self _readLength:integer_range.length];
            return [self newTokenOfType:INTEGER withArgs:@[value]];
		}
        
        // HAT / HATHAT
		if ([c isEqualToString:@"^"]) {
			if ([self.buffer hasPrefix:@"^^"]) {
				if ([self _readWord: @"^^"]) {
					return [self newTokenOfType:HATHAT withArgs:@[]];
				} else {
					return nil;
				}
			} else {
				if ([self _readWord: @"^"]) {
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
			return [self getLanguage];
        } else if ([c isEqualToString: @"<"]) {
            //           NSLog(@"saw '<'; IRIRef or Relational expression.");
			return [self getIRIRefOrRelational];
        } else if ([c isEqualToString: @"?"]) {
			return [self getVariable];
        } else if ([c isEqualToString: @"$"]) {
			return [self getVariable];
        } else if ([c isEqualToString: @"!"]) {
			return [self getBang];
        } else if ([c isEqualToString: @">"]) {
			return [self getIRIRefOrRelational];
        } else if ([c isEqualToString: @"|"]) {
			return [self getOr];
        } else if ([c isEqualToString: @"'"]) {
			return [self getSingleLiteral];
        } else if ([c isEqualToString: @"\""]) {
			return [self getDoubleLiteral];
        } else if ([c isEqualToString: @"_"]) {
			return [self getBnode];
        } else if ([c isEqualToString: @":"]) {
			return [self getPName];
        }
        // 		NSValue* value	= [methodTokens objectForKey:c];
        // 		if (value != nil) {
        // 			SEL selector	= [value pointerValue];
        // 			return [self performSelector:selector];
        // 		}
        //	   else if (defined(my $method = $METHOD_TOKEN{$c})) { return $self->$method() }
        
        
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
			return [self newTokenOfType:(GTWSPARQLTokenType)[number integerValue] withArgs:@[c]];
		}
        // - ANDAND
		else if ([c isEqualToString:@"&"]) {
			if ([self _readWord: @"&&"]) {
				return [self newTokenOfType:ANDAND withArgs:@[]];
			} else {
				return nil;
			}
        }
        // PREFIXNAME
		else if ([pnCharSet characterIsMember:cc]) {
            //			NSLog(@"getting pname");
			GTWSPARQLToken* t	= [self getPName];
			if (t) {
				return t;
			}
		}
        
        // KEYWORD / BOOLEAN
		return [self _getKeyword];
    }
}

- (void)throwError: (NSString*) error {
	NSLog(@"%lu:%lu: %@\n", self.line, (unsigned long)self.column, error);
	NSLog(@"buffer: '%@'", self.buffer);
	;
}

@end

/**
 
 sub check_for_bom {
 my $self	= shift;
 my $c	= $self->_peek_char();
 if ($c eq "\x{FEFF}") {
 $self->_get_char;
 }
 }
 
 
 
 
 sub _new_pname {
 my $self	= shift;
 my @pname	= @_;
 if (scalar(@pname) == 2) {
 my $local	= $pname[1];
 if ($local =~ /[%\\]/) {
 my $new	= '';
 my $len		= length($local);
 my $index	= 0;
 while ($index < $len) {
 my $c	= substr($local, $index, 1);
 if ($c eq '\\') {
 $new	.= substr($local, ++$index, 1);
 } else if ($c eq '%') {
 my $ord	= substr($local, $index+1, 2);
 $new	.= chr(hex($ord));
 $index	+= 2;
 } else {
 $new	.= $c;
 }
 $index++;
 }
 $pname[1]	= $new;
 }
 }
 return $self->new_token(PREFIXNAME, @pname);
 }
 
 sub get_pname {
 my $self	= shift;
 
 if ($self->{buffer} =~ /^$r_PNAME_LN/) {
 my $pname	= $self->_read_length($+[0]);
 my @values	= split(/:/, $pname, 2);
 # 		warn "full prefixedname: '$pname'";
 return $self->_new_pname( @values );
 } else if ($self->{buffer} =~ /^$r_PNAME_NS/) {
 my $pname	= $self->_read_length($+[0]);
 my @values	= split(/:/, $pname, 2);
 # 		warn "prefix: '$pname'";
 return $self->_new_pname( @values );
 } else {
 return;
 }
 }
 
 sub get_iriref_or_relational {
 my $self	= shift;
 if ($self->{buffer} =~ /^${r_IRI_REF}/) {
 $self->_get_char_safe('<');
 my $iri	= '';
 while (1) {
 my $c	= $self->_peek_char;
 last unless defined($c);
 if (substr($self->{buffer}, 0, 1) eq '\\') {
 $self->_get_char_safe('\\');
 my $esc	= $self->_get_char;
 given ($esc) {
 when('\\'){ $iri .= "\\" }
 when('"'){ $iri .= '"' }
 when('r'){ $iri .= "\r" }
 when('t'){ $iri .= "\t" }
 when('n'){ $iri .= "\n" }
 when('>'){ $iri .= ">" }
 when('U'){
 my $codepoint	= $self->_read_length(8);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $iri .= chr(hex($codepoint));
 }
 when('u'){
 my $codepoint	= $self->_read_length(4);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $iri .= chr(hex($codepoint));
 }
 default {
 $self->throw_error("Unrecognized iri escape '$esc'");
 }
 }
 } else if ($self->{buffer} =~ /^[^>\\]+/) {
 $iri	.= $self->_read_length($+[0]);
 } else if (substr($self->{buffer}, 0, 1) eq '>') {
 last;
 } else {
 $self->throw_error("Got '$c' while expecting IRI character");
 }
 }
 $self->_get_char_safe(q[>]);
 return $self->new_token(IRI, $iri);
 } else {
 $self->_get_char_safe('<');
 my $c	= $self->_peek_char;
 if ($c eq '=') {
 $self->_get_char_safe('=');
 return $self->new_token(LE);
 } else {
 return $self->new_token(LT);
 }
 }
 }
 
 
 sub get_bnode {
 my $self	= shift;
 $self->_read_word('_:');
 unless ($self->{buffer} =~ /^(?:${r_PN_CHARS_U}|[0-9])(?:(?:${r_PN_CHARS}|[.])*${r_PN_CHARS})?/o) {
 $self->throw_error("Expected: name");
 }
 my $name	= $self->_read_length($+[0]);
 return $self->new_token(BNODE, $name);
 }
 
 sub get_double_literal {
 my $self	= shift;
 my $c		= $self->_peek_char();
 $self->_get_char_safe(q["]);
 if (substr($self->{buffer}, 0, 2) eq q[""]) {
 # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
 $self->_read_word(q[""]);
 
 my $quote_count	= 0;
 my $string	= '';
 while (1) {
 if (length($self->{buffer}) == 0) {
 $self->fill_buffer;
 if (length($self->{buffer}) == 0) {
 $self->throw_error("Found EOF in string literal");
 }
 }
 if (substr($self->{buffer}, 0, 1) eq '"') {
 my $c	= $self->_get_char;
 $quote_count++;
 if ($quote_count == 3) {
 last;
 }
 } else {
 if ($quote_count) {
 $string	.= '"' foreach (1..$quote_count);
 $quote_count	= 0;
 }
 if (substr($self->{buffer}, 0, 1) eq '\\') {
 my $c	= $self->_get_char;
 # 					$self->_get_char_safe('\\');
 my $esc	= $self->_get_char_fill_buffer;
 given ($esc) {
 when('\\'){ $string .= "\\" }
 when('"'){ $string .= '"' }
 when("'"){ $string .= "'" }
 when('r'){ $string .= "\r" }
 when('t'){ $string .= "\t" }
 when('n'){ $string .= "\n" }
 when('>'){ $string .= ">" }
 when('U'){
 my $codepoint	= $self->_read_length(8);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 when('u'){
 my $codepoint	= $self->_read_length(4);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 default {
 $self->throw_error("Unrecognized string escape '$esc'");
 }
 }
 } else {
 $self->{buffer}	=~ /^[^"\\]+/;
 $string	.= $self->_read_length($+[0]);
 }
 }
 }
 return $self->new_token(STRING3D, $string);
 } else {
 ### #x22 scharacter* #x22
 my $string	= '';
 while (1) {
 if (substr($self->{buffer}, 0, 1) eq '\\') {
 my $c	= $self->_peek_char;
 $self->_get_char_safe('\\');
 my $esc	= $self->_get_char;
 given ($esc) {
 when('\\'){ $string .= "\\" }
 when('"'){ $string .= '"' }
 when("'"){ $string .= "'" }
 when('r'){ $string .= "\r" }
 when('t'){ $string .= "\t" }
 when('n'){ $string .= "\n" }
 when('>'){ $string .= ">" }
 when('U'){
 my $codepoint	= $self->_read_length(8);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 when('u'){
 my $codepoint	= $self->_read_length(4);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 default {
 $self->throw_error("Unrecognized string escape '$esc'");
 }
 }
 } else if ($self->{buffer} =~ /^[^"\\]+/) {
 $string	.= $self->_read_length($+[0]);
 } else if (substr($self->{buffer}, 0, 1) eq '"') {
 last;
 } else {
 $self->throw_error("Got '$c' while expecting string character");
 }
 }
 $self->_get_char_safe(q["]);
 return $self->new_token(STRING1D, $string);
 }
 }
 
 sub get_single_literal {
 my $self	= shift;
 my $c		= $self->_peek_char();
 $self->_get_char_safe("'");
 if (substr($self->{buffer}, 0, 2) eq q['']) {
 # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
 $self->_read_word(q['']);
 
 my $quote_count	= 0;
 my $string	= '';
 while (1) {
 if (length($self->{buffer}) == 0) {
 $self->fill_buffer;
 if (length($self->{buffer}) == 0) {
 $self->throw_error("Found EOF in string literal");
 }
 }
 if (substr($self->{buffer}, 0, 1) eq "'") {
 my $c	= $self->_get_char;
 $quote_count++;
 if ($quote_count == 3) {
 last;
 }
 } else {
 if ($quote_count) {
 $string	.= "'" foreach (1..$quote_count);
 $quote_count	= 0;
 }
 if (substr($self->{buffer}, 0, 1) eq '\\') {
 my $c	= $self->_get_char;
 # 					$self->_get_char_safe('\\');
 my $esc	= $self->_get_char_fill_buffer;
 given ($esc) {
 when('\\'){ $string .= "\\" }
 when('"'){ $string .= '"' }
 when("'"){ $string .= "'" }
 when('r'){ $string .= "\r" }
 when('t'){ $string .= "\t" }
 when('n'){ $string .= "\n" }
 when('>'){ $string .= ">" }
 when('U'){
 my $codepoint	= $self->_read_length(8);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 when('u'){
 my $codepoint	= $self->_read_length(4);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 default {
 $self->throw_error("Unrecognized string escape '$esc'");
 }
 }
 } else {
 $self->{buffer}	=~ /^[^'\\]+/;
 $string	.= $self->_read_length($+[0]);
 }
 }
 }
 return $self->new_token(STRING3S, $string);
 } else {
 ### #x22 scharacter* #x22
 my $string	= '';
 while (1) {
 if (substr($self->{buffer}, 0, 1) eq '\\') {
 my $c	= $self->_peek_char;
 $self->_get_char_safe('\\');
 my $esc	= $self->_get_char;
 given ($esc) {
 when('\\'){ $string .= "\\" }
 when('"'){ $string .= '"' }
 when("'"){ $string .= "'" }
 when('r'){ $string .= "\r" }
 when('t'){ $string .= "\t" }
 when('n'){ $string .= "\n" }
 when('>'){ $string .= ">" }
 when('U'){
 my $codepoint	= $self->_read_length(8);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 when('u'){
 my $codepoint	= $self->_read_length(4);
 unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
 $self->throw_error("Bad unicode escape codepoint '$codepoint'");
 }
 $string .= chr(hex($codepoint));
 }
 default {
 $self->throw_error("Unrecognized string escape '$esc'");
 }
 }
 } else if ($self->{buffer} =~ /^[^'\\]+/) {
 $string	.= $self->_read_length($+[0]);
 } else if (substr($self->{buffer}, 0, 1) eq "'") {
 last;
 } else {
 $self->throw_error("Got '$c' while expecting string character");
 }
 }
 $self->_get_char_safe(q[']);
 return $self->new_token(STRING1S, $string);
 }
 }
 
 sub get_relational {
 my $self	= shift;
 $self->_get_char_safe('>');
 my $c	= $self->_peek_char;
 if ($c eq '=') {
 $self->_get_char_safe('=');
 return $self->new_token(GE);
 } else {
 return $self->new_token(GT);
 }
 }
 
 sub throw_error {
 my $self	= shift;
 my $error	= shift;
 my $line	= $self->start_line;
 my $col		= $self->start_column;
 # 	Carp::cluck "$line:$col: $error: " . Dumper($self->{buffer});
 RDF::Trine::Error::ParserError::Positioned->throw(
 -text => "$error at $line:$col",
 -value => [$line, $col],
 );
 }
 
 **/
