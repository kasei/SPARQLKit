#import "GTWTurtleParser.h"
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWBlank.h>

#define ASSERT_EMPTY(e) if ([e count] > 0) return NO;

typedef NS_ENUM(NSInteger, GTWTurtleParserState) {
    GTWTurtleParserInSubject,
};


@implementation GTWTurtleParser
@synthesize baseURI;

- (GTWTurtleParser*) initWithLexer: (GTWSPARQLLexer*) lex base: (GTWIRI*) base {
    if (self = [self init]) {
        self.lexer  = lex;
        self.baseIRI   = base;
    }
    return self;
}

- (GTWTurtleParser*) init {
    if (self = [super init]) {
        self.stack  = [[NSMutableArray alloc] init];
        self.namespaces = [[NSMutableDictionary alloc] init];
//        self.bnodeID    = 0;
        __block NSUInteger bnodeID  = 0;
        self.bnodeIDGenerator   = ^(NSString* name) {
            if (name == nil) {
                NSUInteger ident    = ++bnodeID;
                GTWBlank* subj  = [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"b%lu", ident]];
                return subj;
            } else {
                return [[GTWBlank alloc] initWithValue:name];
            }
        };
    }
    return self;
}

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    self.tripleBlock    = block;
    return [self parseWithError:error];
}

- (GTWSPARQLToken*) peekNextNonCommentToken {
    while (YES) {
        GTWSPARQLToken* t   = [self.lexer peekToken];
        if (!t)
            return nil;
        if (t.type == COMMENT) {
            [self.lexer getToken];
        } else {
            return t;
        }
    }
}

- (GTWSPARQLToken*) nextNonCommentToken {
    GTWSPARQLToken* t   = [self.lexer getToken];
    while (t.type == COMMENT) {
        t   = [self.lexer getToken];
    }
    return t;
}

//[1]	turtleDoc	::=	statement*
//[2]	statement	::=	directive | triples '.'
//[3]	directive	::=	prefixID | base | sparqlPrefix | sparqlBase
//[4]	prefixID	::=	'@prefix' PNAME_NS IRIREF '.'
//[5]	base	::=	'@base' IRIREF '.'
//[5s]	sparqlBase	::=	"BASE" IRIREF
//[6s]	sparqlPrefix	::=	"PREFIX" PNAME_NS IRIREF
- (BOOL) parseWithError: (NSError**) error {
    NSMutableArray* errors  = [NSMutableArray array];
    @autoreleasepool {
        GTWSPARQLToken* t   = [self peekNextNonCommentToken];
        while (t) {
            if (t.type == KEYWORD) {
                if ([t.value isEqual:@"PREFIX"]) {
                    [self parseExpectedTokenOfType:KEYWORD withValue:@"PREFIX" withErrors:errors];
                    if ([errors count]) goto cleanup;
                    
                    GTWSPARQLToken* name    = [self nextNonCommentToken];
                    if ([name.args count] > 2 || ([name.args count] == 2 && ![[name.args objectAtIndex:1] isEqual: @""])) {
                        [self errorMessage:[NSString stringWithFormat: @"Expecting PNAME_NS in PREFIX declaration, but found PNAME_LN %@", [name.args componentsJoinedByString:@":"]] withErrors:errors];
                        return NO;
                    }
                    GTWSPARQLToken* iri     = [self nextNonCommentToken];
                    if (name && iri) {
                        if (self.verbose)
                            NSLog(@"-> prefix %@ -> %@", name, iri);
                        [self.namespaces setValue:iri.value forKey:name.value];
                    } else {
                        [self errorMessage:@"Failed to parse PREFIX declaration" withErrors:errors];
                        return NO;
                    }
                    //            NSLog(@"PREFIX %@: %@\n", name.value, iri.value);
                } else if ([t.value isEqual:@"BASE"]) {
                    [self nextNonCommentToken];
                    GTWSPARQLToken* iri     = [self nextNonCommentToken];
                    if (iri) {
                        self.baseIRI   = (id<GTWIRI>) [self tokenAsTerm:iri withErrors:errors];
                    } else {
                        [self errorMessage:@"Failed to parse BASE declaration" withErrors:errors];
                        return NO;
                    }
                    //            NSLog(@"BASE %@\n", iri.value);
                }
                [self parseOptionalTokenOfType:DOT];
            } else {
                if (self.verbose)
                    NSLog(@"-> parsing triples: %@", t);
                [self parseTriplesWithErrors:errors];
                if ([errors count]) goto cleanup;
                [self parseExpectedTokenOfType:DOT withErrors:errors];
                if ([errors count]) goto cleanup;
            }
            
            t   = [self peekNextNonCommentToken];
        }
        
        t   = [self peekNextNonCommentToken];
        if (self.verbose)
            NSLog(@"last token: %@", t);
    }
    return YES;
    
cleanup:
    NSLog(@"parsing error: %@", errors);
    return NO;
}


//[6]	triples	::=	subject predicateObjectList | blankNodePropertyList predicateObjectList?
- (BOOL) parseTriplesWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (self.verbose)
        NSLog(@"-> parseTriplesWithErrors: %@", t);
    if (t.type == LBRACKET) {
        [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        id<GTWTerm> subject = [self parseSubjectWithErrors:errors];
        ASSERT_EMPTY(errors);
        if (self.verbose)
            NSLog(@"-> subject: %@", subject);
        [self parsePredicateObjectListForSubject: subject errors: errors];
    }
    return YES;
}

//[7]	predicateObjectList	::=	verb objectList (';' (verb objectList)?)*
- (BOOL) parsePredicateObjectListForSubject: (id<GTWTerm>) subject errors: (NSMutableArray*) errors {
    id<GTWTerm> verb = [self parseVerbWithErrors:errors];
    ASSERT_EMPTY(errors);

    if (self.verbose)
        NSLog(@"-> verb: %@", verb);

    [self parseObjectListForSubject: subject predicate: verb errors: errors];
    ASSERT_EMPTY(errors);
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type == SEMICOLON) {
        [self parseExpectedTokenOfType:SEMICOLON withErrors:errors];
        t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD || t.type == IRI || t.type == PREFIXNAME) {
            ASSERT_EMPTY(errors);
            id<GTWTerm> verb = [self parseVerbWithErrors:errors];
            ASSERT_EMPTY(errors);

            if (self.verbose)
                NSLog(@"-> verb: %@", verb);
            
            [self parseObjectListForSubject: subject predicate: verb errors: errors];
            ASSERT_EMPTY(errors);
            t   = [self peekNextNonCommentToken];
        }
    }
    
    return YES;
}

//[8]	objectList	::=	object (',' object)*
- (BOOL) parseObjectListForSubject: (id<GTWTerm>) subject predicate: (id<GTWTerm>) predicate errors: (NSMutableArray*) errors {
    id<GTWTerm> object = [self parseObjectForSubject: subject predicate: predicate errors: errors];
    ASSERT_EMPTY(errors);
    
    if (self.verbose)
        NSLog(@"-> object: %@", object);
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type == COMMA) {
        [self parseExpectedTokenOfType:COMMA withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTerm> object = [self parseObjectForSubject: subject predicate: predicate errors: errors];
        ASSERT_EMPTY(errors);
        
        if (self.verbose)
            NSLog(@"-> object: %@", object);

        t   = [self peekNextNonCommentToken];
    }
    return YES;
}

//[9]	verb	::=	predicate | 'a'
- (id<GTWTerm>) parseVerbWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t     = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString:@"A"]) {
        [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
        ASSERT_EMPTY(errors);
        return [self tokenAsTerm:t withErrors:errors];
    } else {
        return [self parsePredicateWithErrors:errors];
    }
}

//[10]	subject	::=	iri | BlankNode | collection
- (id<GTWTerm>) parseSubjectWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t     = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        id<GTWTerm> subject = [self parseCollectionWithErrors: errors];
        return subject;
    } else {
        id<GTWTerm> subject = [self parseTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        return subject;
    }
}

//[11]	predicate	::=	iri
- (id<GTWTerm>) parsePredicateWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    if ([t termType] == GTWTermIRI) {
        return t;
    } else {
        [self errorMessage:[NSString stringWithFormat:@"Expected IRI predicate but found %@", t] withErrors:errors];
        return nil;
    }
}

//[12]	object	::=	iri | BlankNode | collection | blankNodePropertyList | literal
//[13]	literal	::=	RDFLiteral | NumericLiteral | BooleanLiteral
//[16]	NumericLiteral	::=	INTEGER | DECIMAL | DOUBLE
//[128s]	RDFLiteral	::=	String (LANGTAG | '^^' iri)?
//[133s]	BooleanLiteral	::=	'true' | 'false'
//[17]	String	::=	STRING_LITERAL_QUOTE | STRING_LITERAL_SINGLE_QUOTE | STRING_LITERAL_LONG_SINGLE_QUOTE | STRING_LITERAL_LONG_QUOTE
//[135s]	iri	::=	IRIREF | PrefixedName
//[136s]	PrefixedName	::=	PNAME_LN | PNAME_NS
//[137s]	BlankNode	::=	BLANK_NODE_LABEL | ANON
- (id<GTWTerm>) parseObjectForSubject: (id<GTWTerm>) subject predicate: (id<GTWTerm>) predicate errors: (NSMutableArray*) errors {
    GTWSPARQLToken* t     = [self peekNextNonCommentToken];
    if ([self tokenIsTerm:t]) {
        [self nextNonCommentToken];
        id<GTWTerm> object    = [self tokenAsTerm:t withErrors:errors];
        ASSERT_EMPTY(errors);
        [self emitSubject:subject predicate:predicate object:object];
        return object;
    } else if (t.type == LBRACKET) {
        id<GTWTerm> object  = [self parseBlankNodePropertyListWithErrors:errors];
        ASSERT_EMPTY(errors);
        [self emitSubject:subject predicate:predicate object:object];
        return object;
    } else if (t.type == LPAREN) {
        id<GTWTerm> object  = [self parseCollectionWithErrors:errors];
        ASSERT_EMPTY(errors);
        [self emitSubject:subject predicate:predicate object:object];
        return object;
    } else {
        NSLog(@"don't know how to turn token into an object: %@", t);
        return nil;
    }
}

//[14]	blankNodePropertyList	::=	'[' predicateObjectList ']'
- (id<GTWTerm>) parseBlankNodePropertyListWithErrors: (NSMutableArray*) errors {
    GTWBlank* subject  = self.bnodeIDGenerator(nil);
    if (self.verbose)
        NSLog(@"-> parsing blank node property list");
    
    [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    
    [self parsePredicateObjectListForSubject:subject errors:errors];
    ASSERT_EMPTY(errors);
    
    [self parseExpectedTokenOfType:RBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    
    return subject;
}

//[15]	collection	::=	'(' object* ')'
- (id<GTWTerm>) parseCollectionWithErrors: (NSMutableArray*) errors {
    GTWBlank* subject  = self.bnodeIDGenerator(nil);
    if (self.verbose)
        NSLog(@"-> parsing collection");

    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);

    GTWIRI* rdffirst    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rdfrest     = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
    GTWIRI* rdfnil      = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"];

    GTWSPARQLToken* t     = [self peekNextNonCommentToken];
    id<GTWTerm> head        = subject;
    while (t.type != RPAREN) {
        [self parseObjectForSubject:head predicate:rdffirst errors:errors];
        ASSERT_EMPTY(errors);
        t     = [self peekNextNonCommentToken];
        if (t.type == RPAREN) {
            [self emitSubject:head predicate:rdfrest object:rdfnil];
        } else {
            GTWBlank* newhead  = self.bnodeIDGenerator(nil);
            [self emitSubject:head predicate:rdfrest object:newhead];
            head    = newhead;
        }
    }

    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    return subject;
}

#pragma mark -

- (BOOL) emitSubject:(id<GTWTerm>) subject predicate: (id<GTWTerm>) predicate object: (id<GTWTerm>) object {
    GTWTriple* t    = [[GTWTriple alloc] initWithSubject:subject predicate:predicate object:object];
    self.tripleBlock(t);
    return YES;
}

- (id<GTWTerm>) parseTermWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    return t;
}

#pragma mark -


- (GTWSPARQLToken*) parseExpectedTokenOfType: (GTWSPARQLTokenType) type withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        NSString* reason    = [NSString stringWithFormat:@"Expecting %@ but found %@", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], t];
        return [self errorMessage:reason withErrors:errors];
        //        NSException* e  = [NSException exceptionWithName:@"us.kasei.sparql.parse-error" reason:reason userInfo:@{}];
        //        NSLog(@"%@; %@", reason, [e callStackSymbols]);
        //        NSLog(@"buffer: %@", self.lexer.buffer);
        //        NSLog(@"token: %@", [self peekNextNonCommentToken]);
        //        return nil;
    } else {
        return t;
    }
}

- (GTWSPARQLToken*) parseOptionalTokenOfType: (GTWSPARQLTokenType) type {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        return nil;
    } else {
        [self nextNonCommentToken];
        return t;
    }
}

- (GTWSPARQLToken*) parseExpectedTokenOfType: (GTWSPARQLTokenType) type withValue: (NSString*) string withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        return [self errorMessage:[NSString stringWithFormat:@"Expecting %@['%@'] but found %@", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], string, t] withErrors:errors];
    } else {
        if ([t.value isEqual: string]) {
            return t;
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting %@ value '%@' but found '%@'", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], string, t.value] withErrors:errors];
        }
    }
}

- (GTWSPARQLToken*) parseOptionalTokenOfType: (GTWSPARQLTokenType) type withValue: (NSString*) string {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type != type) {
        return nil;
    } else {
        if ([t.value isEqual: string]) {
            [self nextNonCommentToken];
            return t;
        } else {
            return nil;
        }
    }
}

#pragma mark -

- (BOOL) tokenIsTerm: (GTWSPARQLToken*) t {
    switch (t.type) {
        case NIL:
        case IRI:
        case ANON:
        case PREFIXNAME:
        case BNODE:
        case STRING1D:
        case STRING3D:
        case STRING1S:
        case STRING3S:
        case BOOLEAN:
        case DECIMAL:
        case DOUBLE:
        case INTEGER:
        case MINUS:
        case PLUS:
            return YES;
        case KEYWORD:
            if ([t.value isEqualToString:@"A"]) {
                return YES;
            } else {
                return NO;
            }
        default:
            return NO;
    }
    
    return NO;
}

- (id<GTWTerm>) tokenAsTerm: (GTWSPARQLToken*) t withErrors: (NSMutableArray*) errors {
    if (t.type == NIL) {
        return [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"];
    } else if (t.type == VAR) {
        id<GTWTerm> var = [[GTWVariable alloc] initWithValue:t.value];
        return var;
    } else if (t.type == IRI) {
        id<GTWTerm> iri     = [[GTWIRI alloc] initWithValue:t.value base:self.baseIRI];
        if (!iri) {
            return [self errorMessage:[NSString stringWithFormat:@"Failed to create IRI with token %@ and base %@", t, self.baseIRI] withErrors:errors];
        }
        return iri;
    } else if (t.type == ANON) {
        return self.bnodeIDGenerator(nil);
        //        NSUInteger ident    = ++self.bnodeID;
        //        return [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
    } else if (t.type == PREFIXNAME) {
        NSString* ns    = t.args[0];
        NSString* base  = (self.namespaces)[ns];
        if (!base) {
            return [self errorMessage:[NSString stringWithFormat:@"Use of undeclared prefix '%@' in PrefixName %@", ns, [t.args componentsJoinedByString:@":"]] withErrors:errors];
        }
        if ([t.args count] > 1) {
            NSString* local = t.args[1];
            //            NSLog(@"constructing IRI from prefixname <%@> <%@> with base: %@", base, local, self.base);
            NSString* value   = [NSString stringWithFormat:@"%@%@", base, local];
            id<GTWTerm> iri     = [[GTWIRI alloc] initWithValue:value base:self.baseIRI];
            if (!iri) {
                return [self errorMessage:[NSString stringWithFormat:@"Failed to create IRI with token %@ and base %@", t, self.baseIRI] withErrors:errors];
            }
            return iri;
        } else {
            id<GTWTerm> iri     = [[GTWIRI alloc] initWithValue:base base:self.baseIRI];
            if (!iri) {
                return [self errorMessage:[NSString stringWithFormat:@"Failed to create IRI with token %@ and base %@", t, self.baseIRI] withErrors:errors];
            }
            return iri;
        }
    } else if (t.type == BNODE) {
        return self.bnodeIDGenerator(t.value);
        //        return [[GTWBlank alloc] initWithID:t.value];
    } else if (t.type == STRING1D || t.type == STRING1S) {
        NSString* value = t.value;
        GTWSPARQLToken* hh  = [self parseOptionalTokenOfType:HATHAT];
        if (hh) {
            t   = [self nextNonCommentToken];
            id<GTWTerm> dt  = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWLiteral alloc] initWithValue:value datatype:dt.value];
        }
        GTWSPARQLToken* lang  = [self parseOptionalTokenOfType:LANG];
        if (lang) {
            return [[GTWLiteral alloc] initWithValue:value language:lang.value];
        }
        return [[GTWLiteral alloc] initWithValue:value];
    } else if (t.type == STRING3D || t.type == STRING3S) {
        NSString* value = t.value;
        GTWSPARQLToken* hh  = [self parseOptionalTokenOfType:HATHAT];
        if (hh) {
            t   = [self nextNonCommentToken];
            id<GTWTerm> dt  = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWLiteral alloc] initWithValue:value datatype:dt.value];
        }
        return [[GTWLiteral alloc] initWithValue:value];
    } else if ((t.type == KEYWORD) && [t.value isEqual:@"A"]) {
        return [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    } else if (t.type == BOOLEAN) {
        return [[GTWLiteral alloc] initWithValue:t.value datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    } else if (t.type == DECIMAL) {
        return [[GTWLiteral alloc] initWithValue:t.value datatype:@"http://www.w3.org/2001/XMLSchema#decimal"];
    } else if (t.type == DOUBLE) {
        return [[GTWLiteral alloc] initWithValue:t.value datatype:@"http://www.w3.org/2001/XMLSchema#double"];
    } else if (t.type == INTEGER) {
        return [[GTWLiteral alloc] initWithValue:t.value datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
    } else if (t.type == PLUS) {
        t   = [self nextNonCommentToken];
        return [self tokenAsTerm:t withErrors:errors];
    } else if (t.type == MINUS) {
        t   = [self nextNonCommentToken];
        NSString* value = [NSString stringWithFormat:@"-%@", t.value];
        if (t.type == INTEGER) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else if (t.type == DECIMAL) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#decimal"];
        } else if (t.type == DOUBLE) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#double"];
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting numeric value after MINUS but found: %@", t] withErrors:errors];
        }
    }
    
    return [self errorMessage:[NSString stringWithFormat:@"unexpected token as term: %@ (near '%@')", t, self.lexer.buffer] withErrors:errors];
}

- (id) errorMessage: (id) message withErrors:(NSMutableArray*) errors {
    [errors addObject:message];
    return nil;
}


@end
