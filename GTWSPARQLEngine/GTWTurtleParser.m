#import "GTWTurtleParser.h"

typedef NS_ENUM(NSInteger, GTWTurtleParserState) {
    GTWTurtleParserInSubject,
};


@implementation GTWTurtleParser

- (GTWTurtleParser*) initWithLexer: (GTWTurtleLexer*) lex base: (GTWIRI*) base {
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
                GTWBlank* subj  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
                return subj;
            } else {
                return [[GTWBlank alloc] initWithID:name];
            }
        };
    }
    return self;
}

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    id<GTWTriple> t;
    while ((t = [self nextObject])) {
        block(t);
    }
    return YES;
}

- (GTWSPARQLToken*) nextNonCommentToken {
    GTWSPARQLToken* t   = [self.lexer getToken];
    while (t.type == COMMENT) {
        t   = [self.lexer getToken];
    }
    return t;
}

- (id<GTWTriple>) nextObject {
    while (YES) {
        GTWSPARQLToken* t   = [self nextNonCommentToken];
        if (t == nil) {
//            NSLog(@"no remaining tokens. finished.");
            return nil;
        }
//        NSLog(@"lexer token: %@", t);
        
        if (t.type == LBRACKET) {
            GTWBlank* subj  = self.bnodeIDGenerator(nil);
//            NSUInteger ident    = ++self.bnodeID;
//            GTWBlank* subj  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
            [self pushNewSubject:subj];
        } else if (t.type == RBRACKET) {
            // TODO: need to test for balanced brackets
            id<GTWTerm> b    = [self currentSubject];
            [self popSubject];
            if ([self haveSubjectPredicatePair]) {
                id<GTWTerm> subj    = self.currentSubject;
                id<GTWTerm> pred    = self.currentPredicate;
                if (subj && pred && b) {
                    id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:b];
                    return st;
                }
            }
        } else if (t.type == COMMA) {
            // no-op
        } else if (t.type == SEMICOLON) {
            [self popPredicate];
        } else if (t.type == DOT) {
            [self popSubject];
        } else if ([t isTerm]) {
            id<GTWTerm> term   = [self tokenAsTerm:t];
            //            NSLog(@"got term: %@", term);
            if ([self haveSubjectPredicatePair]) {
                //                NSLog(@"--> got object");
                
                
                if ([term isMemberOfClass:[GTWLiteral class]]) {
                    GTWSPARQLToken* t   = [self.lexer peekToken];
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
                return st;
            } else if ([self haveSubject]) {
                //                NSLog(@"--> got predicate");
                [self pushNewPredicate:term];
            } else {
                //                NSLog(@"--> got subject");
                [self pushNewSubject:term];
            }
        } else if (t.type == KEYWORD) {
            if ([t.value isEqualToString:@"prefix"]) {
                GTWSPARQLToken* name    = [self nextNonCommentToken];
                GTWSPARQLToken* iri     = [self nextNonCommentToken];
                GTWSPARQLToken* dot     = [self nextNonCommentToken];
                [self.namespaces setValue:iri.value forKey:name.value];
//                NSLog(@"PREFIX %@: %@\n", name.value, iri.value);
            } else if ([t.value isEqualToString:@"base"]) {
                GTWSPARQLToken* iri     = [self nextNonCommentToken];
                self.baseIRI   = [self tokenAsTerm:iri];
                GTWSPARQLToken* dot     = [self nextNonCommentToken];
//                NSLog(@"BASE %@\n", iri.value);
            } else {
                NSLog(@"unexpected keyword: %@", t);
            }
        } else {
            NSLog(@"unexpected token: %@", t);
            NSLog(@"... with stack: %@", self.stack);
        }
    }
}

- (id<GTWTerm>) tokenAsTerm: (GTWSPARQLToken*) t {
    if (t.type == IRI) {
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
