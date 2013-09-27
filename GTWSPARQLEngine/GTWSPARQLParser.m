#import "GTWSPARQLParser.h"
#import "GTWSPARQLToken.h"
#import "GTWTree.h"
#import <GTWSWBase/GTWVariable.h>

typedef NS_ENUM(NSInteger, GTWSPARQLParserState) {
    GTWSPARQLParserInSubject,
};


@implementation GTWSPARQLParser

- (GTWSPARQLParser*) initWithLexer: (GTWSPARQLLexer*) lex base: (GTWIRI*) base {
    if (self = [self init]) {
        self.lexer  = lex;
        self.baseIRI   = base;
    }
    return self;
}

- (GTWSPARQLParser*) init {
    if (self = [super init]) {
        self.stack  = [[NSMutableArray alloc] init];
        self.namespaces = [[NSMutableDictionary alloc] init];
        //        self.bnodeID    = 0;
        __block NSUInteger bnodeID  = 0;
        self.bnodeIDGenerator   = ^(NSString* name) {
            if (name == nil) {
                NSUInteger ident    = ++bnodeID;
                GTWBlank* subj  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
                return subj;
            } else {
                return [[GTWBlank alloc] initWithID:name];
            }
        };
    }
    return self;
}

- (id<GTWTree>) parseSPARQL: (NSString*) queryString withBaseURI: (NSString*) base {
    self.lexer      = [[GTWSPARQLLexer alloc] initWithString:queryString];
    self.baseIRI    = [[GTWIRI alloc] initWithValue:base];
    return [self parse];
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

- (id<GTWTree>) parse {
    GTWSPARQLToken* t;
    NSMutableArray* errors  = [NSMutableArray array];
    
    [self parsePrologueWithErrors: errors];
    
    t   = [self peekNextNonCommentToken];
    if (t.type != KEYWORD) {
        NSLog(@"expected query method not found: %@", t);
        return nil;
    }
    
    id<GTWTree> algebra;
    if ([t.value isEqual: @"SELECT"]) {
        algebra = [self parseSelectQueryWithError:errors];
    } else if ([t.value isEqual: @"CONSTRUCT"]) {
    } else if ([t.value isEqual: @"DESCRIBE"]) {
    } else if ([t.value isEqual: @"ASK"]) {
        algebra = [self parseAskQueryWithError:errors];
    } else {
        NSLog(@"expected query method not found: %@", t);
        return nil;
    }
    
    // TODO ValuesClause
    
    if ([errors count]) {
        return nil;
    }
    return algebra;
}

#pragma mark -

- (void) parsePrologueWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (YES) {
        if (t.type != KEYWORD)
            break;
        
        if ([t.value isEqual:@"PREFIX"]) {
            [self nextNonCommentToken];
            GTWSPARQLToken* name    = [self nextNonCommentToken];
            GTWSPARQLToken* iri     = [self nextNonCommentToken];
            [self.namespaces setValue:iri.value forKey:name.value];
                NSLog(@"PREFIX %@: %@\n", name.value, iri.value);
        } else if ([t.value isEqual:@"BASE"]) {
            [self nextNonCommentToken];
            GTWSPARQLToken* iri     = [self nextNonCommentToken];
            self.baseIRI   = (id<GTWIRI>) [self tokenAsTerm:iri];
            NSLog(@"BASE %@\n", iri.value);
        } else {
            return;
        }
        
        t   = [self peekNextNonCommentToken];
    }
    return;
}

- (id) errorMessage: (id) message withErrors:(NSMutableArray*) errors {
    return nil;
}

- (id<GTWTree>) parseSelectQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT"];
    //@@ (DISTINCT | REDUCED)
    
    //@@ ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*'
    [self parseExpectedTokenOfType:STAR];   //@@
    
    //@@ DatasetClause*
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    if (!ggp) {
        return nil;
    }
    // SolutionModifier
    return ggp;
}

- (id<GTWTree>) parseAskQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"ASK"];
    //@@ DatasetClause*
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    if (!ggp) {
        return nil;
    }
    //@@ SolutionModifier
    return [[GTWTree alloc] initWithType:kAlgebraAsk arguments:@[ggp]];
}

- (id<GTWTree>) parseGroupGraphPatternWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE];
    //@@ SubSelect | GroupGraphPatternSub
    
    id<GTWTree> algebra = [self parseGroupGraphPatternSubWithError:errors];
    if (!algebra)
        return nil;
    
    [self parseExpectedTokenOfType:RBRACE];
    return algebra;
}

- (id<GTWTree>) parseGroupGraphPatternSubWithError: (NSMutableArray*) errors {
    // TriplesBlock? ( GraphPatternNotTriples '.'? TriplesBlock? )*
    // VarOrTerm        |
    //                  '> GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
    //                     '{'                        'OPTIONAL'             'MINUS'             'GRAPH'             'SERVICE'             'FILTER' 'BIND' 'VALUES'
    NSMutableArray* args    = [NSMutableArray array];
    BOOL ok = YES;
    while (ok) {
        GTWSPARQLToken* t   = [self peekNextNonCommentToken];
        if (!t) {
            // TODO: set error
            NSLog(@"unexpected EOF");
            return nil;
        }
        id<GTWTree> algebra;
        GTWSPARQLTokenType type = t.type;
        
//        NSLog(@"--> GGP sub pattern token: %@", t);
        
        switch (type) {
            case LBRACKET:
            case VAR:
            case IRI:
            case ANON:
            case PREFIXNAME:
            case BNODE:
            case STRING1D:
            case STRING3D:
            case BOOLEAN:
            case DECIMAL:
            case DOUBLE:
            case INTEGER:
                algebra = [self parseTriplesBlockWithError:errors];
                if (algebra) {
                    [args addObject:algebra];
                }
                break;
            case LBRACE:
                algebra = [self parseGraphPatternNotTriplesWithError:errors];
                if (!algebra)
                    return nil;
                [args addObject:algebra];
                [self parseOptionalTokenOfType:DOT];
                break;
            case KEYWORD:
                if ([t.value isEqual:@"A"]) {
                    algebra = [self parseTriplesBlockWithError:errors];
                    if (!algebra)
                        return nil;
                    [args addObject:algebra];
                } else {
                    algebra = [self parseGraphPatternNotTriplesWithError:errors];
                    if (!algebra)
                        return nil;
                    [args addObject:algebra];
                }
                break;
            default:
                ok  = NO;
        }
    }
    return [[GTWTree alloc] initWithType:kTreeList arguments:args];
}

- (id<GTWTree>) parseTriplesBlockWithError: (NSMutableArray*) errors {
    NSMutableArray* triples = [NSMutableArray array];
    while (YES) {
        GTWSPARQLToken* t   = [self peekNextNonCommentToken];
        if (t == nil) {
            // error
            NSLog(@"*** Unexpected EOF");
            return nil;
        }
        
//        NSLog(@"SPARQL parser lexer token: %@", t);
        if (t.type == LBRACKET) {
            [self nextNonCommentToken];
            GTWBlank* subj  = self.bnodeIDGenerator(nil);
            //            NSUInteger ident    = ++self.bnodeID;
            //            GTWBlank* subj  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
            [self pushNewSubject:subj];
        } else if (t.type == RBRACKET) {
            [self nextNonCommentToken];
            // TODO: need to test for balanced brackets
            id<GTWTerm> b    = [self currentSubject];
            [self popSubject];

            if ([self haveSubjectPredicatePair]) {
                id<GTWTerm> subj    = self.currentSubject;
                id<GTWTerm> pred    = self.currentPredicate;
                if (subj && pred && b) {
                    // this BNODE is being used as the object in a triple
                    id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:b];
                    [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:st arguments:nil]];
                }
            } else {
                [self pushNewSubject:b];
            }
        } else if (t.type == COMMA) {
            [self nextNonCommentToken];
            // no-op
        } else if (t.type == SEMICOLON) {
            [self nextNonCommentToken];
            [self popPredicate];
        } else if (t.type == DOT) {
            [self nextNonCommentToken];
            [self popSubject];
        } else if ([t isTermOrVar]) {
            [self nextNonCommentToken];
            id<GTWTerm> term   = [self tokenAsTerm:t];
//            NSLog(@"got term: %@", term);
            if ([self haveSubjectPredicatePair]) {
                //                NSLog(@"--> got object");
                
                
                if ([term isMemberOfClass:[GTWLiteral class]]) {
                    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
                    //                    NSLog(@"check for LANG or DT: %@", t);
                    if (t.type == LANG) {
                        [self nextNonCommentToken];
                        //                        NSLog(@"got language: %@", t.value);
                        GTWLiteral* l   = [[GTWLiteral alloc] initWithString:[term value] language:t.value];
                        term            = l;
                    } else if (t.type == HATHAT) {
                        [self nextNonCommentToken];
                        GTWSPARQLToken* t   = [self nextNonCommentToken];
                        id<GTWTerm> dt   = [self tokenAsTerm:t];
                        GTWLiteral* l   = [[GTWLiteral alloc] initWithString:[term value] datatype:dt.value];
                        term            = l;
                    }
                }
                
                
                id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:[self currentSubject] predicate:[self currentPredicate] object:term];
                [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:st arguments:nil]];
            } else if ([self haveSubject]) {
//                NSLog(@"--> got predicate");
                [self pushNewPredicate:term];
            } else {
//                NSLog(@"--> got subject");
                [self pushNewSubject:term];
            }
//        } else if (t.type == KEYWORD) {
//            [self nextNonCommentToken];
//            NSLog(@"unexpected keyword: %@", t);
        } else {
//            NSLog(@"unexpected token: %@", t);
//            NSLog(@"... with stack: %@", self.stack);
            break;
        }
    }
    return [[GTWTree alloc] initWithType:kAlgebraBGP arguments:triples];
}

- (id<GTWTerm>) parseVarOrIRIWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token];
    return t;
}

- (id<GTWTree>) parseGraphPatternNotTriplesWithError: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (t.type == KEYWORD) {
        NSString* kw    = t.value;
        if ([kw isEqual:@"OPTIONAL"]) {
            // 'OPTIONAL' GroupGraphPattern
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraLeftJoin arguments:@[ggp]];
        } else if ([kw isEqual:@"MINUS"]) {
            // 'MINUS' GroupGraphPattern
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraMinus arguments:@[ggp]];
        } else if ([kw isEqual:@"GRAPH"]) {
            // 'GRAPH' VarOrIri GroupGraphPattern
            id<GTWTerm> g   = [self parseVarOrIRIWithErrors: errors];
            if (!g)
                return nil;
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraGraph value: g arguments:@[ggp]];
//        } else if ([kw isEqual:@"SERVICE"]) {
//        } else if ([kw isEqual:@"FILTER"]) {
//        } else if ([kw isEqual:@"BIND"]) {
//        } else if ([kw isEqual:@"VALUES"]) {
        } else {
            NSLog(@"Unexpected KEYWORD %@ while expecting GraphPatternNotTriples", t.value);
            return nil;
        }
    } else if (t.type == LBRACE) {
        id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
        if (!ggp) {
            return nil;
        }
        //@@ GroupGraphPattern ( 'UNION' GroupGraphPattern )*
        return ggp;
    } else {
        NSLog(@"Expecting KEYWORD but got %@", t);
        return nil;
    }
    //@@ GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
    NSLog(@"parseGraphPatternNotTriplesWithError: not implemented yet");
    return nil;
}





#pragma mark -


- (GTWSPARQLToken*) parseExpectedTokenOfType: (GTWSPARQLTokenType) type {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        NSLog(@"Expecting %@ but found %@", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], t);
        return nil;
    } else {
        return t;
    }
}

- (GTWSPARQLToken*) parseOptionalTokenOfType: (GTWSPARQLTokenType) type {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        return nil;
    } else {
        return t;
    }
}

- (GTWSPARQLToken*) parseExpectedTokenOfType: (GTWSPARQLTokenType) type withValue: (NSString*) string {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        NSLog(@"Expecting %@['%@'] but found %@", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], string, t);
        return nil;
    } else {
        if ([t.value isEqual: string]) {
            return t;
        } else {
            NSLog(@"Expecting %@ value '%@' but found '%@'", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], string, t.value);
            return nil;
        }
    }
}

- (GTWSPARQLToken*) parseOptionalTokenOfType: (GTWSPARQLTokenType) type withValue: (NSString*) string {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (t.type != type) {
        return nil;
    } else {
        if ([t.value isEqual: string]) {
            return t;
        } else {
            return nil;
        }
    }
}









#pragma mark -

- (id<GTWTerm>) tokenAsTerm: (GTWSPARQLToken*) t {
    if (t.type == VAR) {
        id<GTWTerm> var = [[GTWVariable alloc] initWithValue:t.value];
        return var;
    } else if (t.type == IRI) {
        id<GTWTerm> iri     = [[GTWIRI alloc] initWithIRI:t.value base:self.baseIRI];
        if (!iri) {
            iri = (id<GTWTerm>) [NSNull null];
        }
        return iri;
    } else if (t.type == ANON) {
        return self.bnodeIDGenerator(nil);
        //        NSUInteger ident    = ++self.bnodeID;
        //        return [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
    } else if (t.type == PREFIXNAME) {
        if ([t.args count] > 1) {
            NSString* ns    = t.args[0];
            NSString* local = t.args[1];
            NSString* base  = (self.namespaces)[ns];
            //            NSLog(@"constructing IRI from prefixname <%@> <%@> with base: %@", base, local, self.base);
            NSString* iri   = [NSString stringWithFormat:@"%@%@", base, local];
            return [[GTWIRI alloc] initWithIRI:iri base:self.baseIRI];
        } else {
            NSString* ns    = t.args[0];
            NSString* base  = (self.namespaces)[ns];
            return [[GTWIRI alloc] initWithIRI:base base:self.baseIRI];
        }
    } else if (t.type == BNODE) {
        return self.bnodeIDGenerator(t.value);
        //        return [[GTWBlank alloc] initWithID:t.value];
    } else if (t.type == STRING1D) {
        return [[GTWLiteral alloc] initWithString:t.value];
    } else if (t.type == STRING3D) {
        return [[GTWLiteral alloc] initWithString:t.value];
    } else if ((t.type == KEYWORD) && [t.value isEqualToString:@"A"]) {
        return [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    } else if (t.type == BOOLEAN) {
        return [[GTWLiteral alloc] initWithString:t.value datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    } else if (t.type == DECIMAL) {
        return [[GTWLiteral alloc] initWithString:t.value datatype:@"http://www.w3.org/2001/XMLSchema#decimal"];
    } else if (t.type == DOUBLE) {
        return [[GTWLiteral alloc] initWithString:t.value datatype:@"http://www.w3.org/2001/XMLSchema#double"];
    } else if (t.type == INTEGER) {
        return [[GTWLiteral alloc] initWithString:t.value datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
    }
    NSLog(@"unexpected token as term: %@", t);
    return [[GTWIRI alloc] initWithIRI:@"XXXXXXXXX"];
}


- (id<GTWTerm>) currentSubject {
    NSArray* pair   = [self.stack lastObject];
    return pair[0];
}

- (id<GTWTerm>) currentPredicate {
    NSArray* pair   = [self.stack lastObject];
    return [pair[1] lastObject];
}

- (BOOL) haveSubjectPredicatePair {
    if ([self.stack count] == 0)
        return NO;
    if ([[self.stack lastObject] count] < 2)
        return NO;
    if ([[self.stack lastObject][1] count] == 0)
        return NO;
    return YES;
    //    return ([self.stack count] > 0 && ([[self.stack lastObject][1] count] > 0));
}

- (BOOL) haveSubject {
    return ([self.stack count] > 0);
}

- (void) pushNewSubject: (id<GTWTerm>) subj {
    NSMutableArray* preds   = [[NSMutableArray alloc] init];
    NSArray* pair   = @[subj, preds];// [NSArray arrayWithObjects:subj, preds, nil];
    [self.stack addObject:pair];
}

- (void) popSubject {
    [self.stack removeLastObject];
}

- (void) pushNewPredicate: (id<GTWTerm>) pred {
    NSArray* pair   = [self.stack lastObject];
    [pair[1] addObject:pred];
}

- (void) popPredicate {
    NSArray* pair   = [self.stack lastObject];
    [pair[1] removeLastObject];
}


@end
