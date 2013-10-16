#import "GTWSPARQLParser.h"
#import "GTWSPARQLToken.h"
#import "GTWTree.h"
#import <GTWSWBase/GTWVariable.h>

#define ASSERT_EMPTY(e) if ([e count] > 0) return nil;

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
    id<GTWTree> algebra;
    self.seenAggregate  = NO;
    NSMutableArray* errors  = [NSMutableArray array];
    
    [self parsePrologueWithErrors: errors];
    if ([errors count])
        goto cleanup;
    
    t   = [self peekNextNonCommentToken];
    if (t.type != KEYWORD) {
        [self errorMessage:[NSString stringWithFormat:@"expected query method not found: %@", t] withErrors:errors];
        goto cleanup;
    }
    
    if ([t.value isEqual: @"SELECT"]) {
        algebra = [self parseSelectQueryWithError:errors];
        if ([errors count])
            goto cleanup;
    } else if ([t.value isEqual: @"CONSTRUCT"]) {
        algebra = [self parseConstructQueryWithErrors:errors];
        if ([errors count])
            goto cleanup;
    } else if ([t.value isEqual: @"DESCRIBE"]) {
        NSLog(@"*** DESCRIBE not implemented");
        return nil;
    } else if ([t.value isEqual: @"ASK"]) {
        algebra = [self parseAskQueryWithError:errors];
        if ([errors count])
            goto cleanup;
    } else {
        [self errorMessage:[NSString stringWithFormat:@"expected query method not found: %@", t] withErrors:errors];
        goto cleanup;
    }
    
    algebra = [self parseValuesClauseForAlgebra:algebra withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if ([errors count]) {
        goto cleanup;
    }
    
    t   = [self peekNextNonCommentToken];
    if (t) {
        [self errorMessage:[NSString stringWithFormat: @"Found extra content after parsed query: %@", t] withErrors:errors];
        goto cleanup;
    }
    
    return algebra;
    
cleanup:
    NSLog(@"*** Parse error: %@", errors);
    ASSERT_EMPTY(errors);
    return nil;
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
            if (name && iri) {
                [self.namespaces setValue:iri.value forKey:name.value];
            } else {
                [self errorMessage:@"Failed to parse PREFIX declaration" withErrors:errors];
                return;
            }
//            NSLog(@"PREFIX %@: %@\n", name.value, iri.value);
        } else if ([t.value isEqual:@"BASE"]) {
            [self nextNonCommentToken];
            GTWSPARQLToken* iri     = [self nextNonCommentToken];
            if (iri) {
                self.baseIRI   = (id<GTWIRI>) [self tokenAsTerm:iri];
            } else {
                [self errorMessage:@"Failed to parse BASE declaration" withErrors:errors];
                return;
            }
//            NSLog(@"BASE %@\n", iri.value);
        } else {
            return;
        }
        
        t   = [self peekNextNonCommentToken];
    }
    return;
}

- (id<GTWTree>) parseSelectQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT" withErrors:errors];
    ASSERT_EMPTY(errors);
    NSUInteger distinct = 0;

    GTWSPARQLToken* t;
    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        // (DISTINCT | REDUCED)
        if ([t.value isEqual: @"DISTINCT"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        } else if ([t.value isEqual: @"REDUCED"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        }
    }
    
    //@@ ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*'
    NSMutableArray* project;
    t   = [self peekNextNonCommentToken];
    if (t.type == STAR) {
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        project = [NSMutableArray array];
        while (t.type == VAR || t.type == LPAREN) {
            if (t.type == VAR) {
                [self nextNonCommentToken];
                id<GTWTerm> term    = [self tokenAsTerm:t];
                [project addObject:[[GTWTree alloc] initWithType:kTreeNode value:term arguments:nil]];
            } else if (t.type == LPAREN) {
                [self nextNonCommentToken];
                id<GTWTree> expr    = [self parseExpressionWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> var     = [self parseVarWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> pvar    = [[GTWTree alloc] initWithType:kAlgebraExtend arguments:@[expr, var]];
                [project addObject:pvar];
            }
            t   = [self peekNextNonCommentToken];
        }
        if ([project count] == 0) {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting project list but found %@", t] withErrors:errors];
        }
    }
    
    //@@ XXX DatasetClause*
    
    
    
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp)
        return nil;
    
    // SolutionModifier
    id<GTWTree> algebra = [self parseSolutionModifierForAlgebra:ggp withErrors:errors];
    if (project) {
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:project];
        algebra = [[GTWTree alloc] initWithType:kAlgebraProject value:vlist arguments:@[algebra]];
        algebra = [self algebraVerifyingGroupingInAlgebra: algebra withErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    if (distinct) {
        algebra = [[GTWTree alloc] initWithType:kAlgebraDistinct arguments:@[algebra]];
    }
    
    return algebra;
}

//        [10]  	ConstructQuery	  ::=  	'CONSTRUCT' ( ConstructTemplate DatasetClause* WhereClause SolutionModifier | DatasetClause* 'WHERE' '{' TriplesTemplate? '}' SolutionModifier )
- (id<GTWTree>) parseConstructQueryWithErrors: (NSMutableArray*) errors {
    // XXX
    [self parseExpectedTokenOfType:KEYWORD withValue:@"CONSTRUCT" withErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> algebra = [self parseSolutionModifierForAlgebra:ggp withErrors:errors];
    ASSERT_EMPTY(errors);
    return [[GTWTree alloc] initWithType:kAlgebraConstruct arguments:@[algebra, algebra]];
}

- (id<GTWTree>) algebraVerifyingGroupingInAlgebra: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    if (self.seenAggregate) {
        id<GTWTree> projectList = algebra.value;
        NSArray* plist          = projectList.arguments;
        
        __block id<GTWTree> grouping;
        [algebra applyPrefixBlock:nil postfixBlock:^id(id<GTWTree> node, id<GTWTree> parent, NSUInteger level, BOOL *stop) {
            if (node.type == kAlgebraGroup) {
                grouping    = node;
            }
            return nil;
        }];
        id<GTWTree> list    = grouping.value;
        NSArray* groups     = list.arguments;
        NSMutableSet* groupVars = [NSMutableSet set];
        for (id<GTWTree> g in groups) {
            if (g.type == kAlgebraExtend) {
                id<GTWTree> var = g.arguments[1];
                [groupVars addObject:var.value];
            } else if (g.type == kTreeNode) {
                [groupVars addObject:g.value];
            }
        }
    //    NSLog(@"grouping vars: %@", groupVars);
        
        for (id<GTWTree> v in plist) {
    //        NSLog(@"project -> %@", v);
            if (v.type == kTreeNode) {
                id<GTWTerm> t   = v.value;
                if (![groupVars containsObject:t]) {
                    return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed", t] withErrors:errors];
                }
            } else {
                NSSet* vars = [v nonAggregatedVariables];
                for (id<GTWTerm> t in vars) {
                    if (![groupVars containsObject:t]) {
                        return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed", t] withErrors:errors];
                    }
                }
            }
        }
    }
    
    return algebra;
}

- (id<GTWTree>) parseAskQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"ASK" withErrors:errors];
    ASSERT_EMPTY(errors);
    //@@ DatasetClause*
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp) {
        return nil;
    }
    //@@ SolutionModifier
    return [[GTWTree alloc] initWithType:kAlgebraAsk arguments:@[ggp]];
}

//[53]  	GroupGraphPattern	  ::=  	'{' ( SubSelect | GroupGraphPatternSub ) '}'
- (id<GTWTree>) parseGroupGraphPatternWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    
    id<GTWTree> algebra;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqual: @"SELECT"]) {
        algebra = [self parseSubSelectWithError:errors];
    } else {
        algebra = [self parseGroupGraphPatternSubWithError:errors];
    }

    ASSERT_EMPTY(errors);
    if (!algebra)
        return nil;

    [self parseExpectedTokenOfType:RBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    
    return algebra;
}

- (id<GTWTree>) reduceTriplePaths: (id<GTWTree>) paths {
    NSMutableArray* triples = [NSMutableArray array];
    for (id<GTWTree> t in paths.arguments) {
        if (t.type == kTreeList) {
            id<GTWTree> path    = t.arguments[1];
            if (path.type == kTreeNode) {
                id<GTWTree> subj    = t.arguments[0];
                id<GTWTree> obj    = t.arguments[2];
                id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:subj.value predicate:path.value object:obj.value];
                id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreeTriple value:st arguments:nil];
                [triples addObject:triple];
            } else {
                id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreePath arguments:t.arguments];
                [triples addObject:triple];
            }
        } else {
            [triples addObject:t];
        }
    }
    return [[GTWTree alloc] initWithType:kTreeList arguments:triples];
}

//[8]  	SubSelect	  ::=  	SelectClause WhereClause SolutionModifier ValuesClause
- (id<GTWTree>) parseSubSelectWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT" withErrors:errors];
    ASSERT_EMPTY(errors);
    NSUInteger distinct = 0;
    
    GTWSPARQLToken* t;
    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        // (DISTINCT | REDUCED)
        if ([t.value isEqual: @"DISTINCT"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        } else if ([t.value isEqual: @"REDUCED"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        }
    }
    
    //@@ ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*'
    NSMutableArray* project;
    t   = [self peekNextNonCommentToken];
    if (t.type == STAR) {
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        project = [NSMutableArray array];
        while (t.type == VAR || t.type == LPAREN) {
            if (t.type == VAR) {
                [self nextNonCommentToken];
                id<GTWTerm> term    = [self tokenAsTerm:t];
                [project addObject:[[GTWTree alloc] initWithType:kTreeNode value:term arguments:nil]];
            } else if (t.type == LPAREN) {
                [self nextNonCommentToken];
                id<GTWTree> expr    = [self parseExpressionWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> var     = [self parseVarWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> pvar    = [[GTWTree alloc] initWithType:kAlgebraExtend arguments:@[expr, var]];
                [project addObject:pvar];
            }
            t   = [self peekNextNonCommentToken];
        }
    }
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp)
        return nil;
    
    // SolutionModifier
    id<GTWTree> algebra = [self parseSolutionModifierForAlgebra:ggp withErrors:errors];
    if (project) {
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:project];
        algebra = [[GTWTree alloc] initWithType:kAlgebraProject value:vlist arguments:@[algebra]];
        algebra = [self algebraVerifyingGroupingInAlgebra: algebra withErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    // XXX ValuesClause
    
    
    
    if (distinct) {
        algebra = [[GTWTree alloc] initWithType:kAlgebraDistinct arguments:@[algebra]];
    }
    
    return algebra;
}


//[20]  	GroupCondition	  ::=  	BuiltInCall | FunctionCall | '(' Expression ( 'AS' Var )? ')' | Var
- (id<GTWTree>) parseGroupConditionWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        
        id<GTWTree> cond;
        t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
            ASSERT_EMPTY(errors);
            id<GTWTree> var = [self parseVarOrTermWithErrors:errors];
            ASSERT_EMPTY(errors);
            cond    = [[GTWTree alloc] initWithType:kAlgebraExtend arguments:@[expr, var]];
        } else {
            cond    = expr;
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return cond;
    } else if (t.type == VAR) {
        return [self parseVarOrTermWithErrors:errors];
    } else {
        // XXX need to handle FunctionCall
        return [self parseBuiltInCallWithErrors:errors];
    }
    // XXX return nil if can't parse a GroupCondition so that calling code can repeatedly call this method to parse all conditions
}



// [24]  	OrderCondition	  ::=  	 ( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( Constraint | Var )
- (id<GTWTree>) parseOrderConditionWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    GTWSPARQLToken* asc = [self parseOptionalTokenOfType:KEYWORD withValue:@"ASC"]; // XXX
    GTWSPARQLToken* desc = [self parseOptionalTokenOfType:KEYWORD withValue:@"DESC"]; // XXX
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parseBrackettedExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else if (t.type == VAR) {
        return [self parseVarOrTermWithErrors:errors];
    } else {
        return [self parseConstraintWithErrors: errors];
    }
}

// [69]  	Constraint	  ::=  	BrackettedExpression | BuiltInCall | FunctionCall
- (id<GTWTree>) parseConstraintWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self parseBrackettedExpressionWithErrors:errors];
    } else {
        return [self parseBuiltInCallWithErrors:errors];
    }
    // XXX return nil if can't parse a GroupCondition so that calling code can repeatedly call this method to parse all conditions
}

//[18]  	SolutionModifier	  ::=  	GroupClause? HavingClause? OrderClause? LimitOffsetClauses?
//[19]  	GroupClause	  ::=  	'GROUP' 'BY' GroupCondition+
//[21]  	HavingClause	  ::=  	'HAVING' HavingCondition+
//[22]  	HavingCondition	  ::=  	Constraint
//[23]  	OrderClause	  ::=  	'ORDER' 'BY' OrderCondition+
//[25]  	LimitOffsetClauses	  ::=  	LimitClause OffsetClause? | OffsetClause LimitClause?
//[26]  	LimitClause	  ::=  	'LIMIT' INTEGER
//[27]  	OffsetClause	  ::=  	'OFFSET' INTEGER
- (id<GTWTree>) parseSolutionModifierForAlgebra: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"GROUP"];
    if (t) {
        self.seenAggregate  = YES;
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* conds   = [NSMutableArray array];
        id<GTWTree> cond;
        while ((cond = [self parseGroupConditionWithErrors:errors])) {
            ASSERT_EMPTY(errors);
            [conds addObject:cond];
        }
        ASSERT_EMPTY(errors);
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:conds];
        algebra = [[GTWTree alloc] initWithType:kAlgebraGroup value: vlist arguments:@[algebra]];
    } else if (self.seenAggregate) {
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
        algebra = [[GTWTree alloc] initWithType:kAlgebraGroup value: vlist arguments:@[algebra]];
    }
    
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"HAVING"];
    if (t) {
        // XXX
    }
    
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"ORDER"];
    if (t) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* conds   = [NSMutableArray array];
        id<GTWTree> cond;
        while ((cond = [self parseOrderConditionWithErrors:errors])) {
            ASSERT_EMPTY(errors);
            [conds addObject:cond];
        }
        ASSERT_EMPTY(errors);
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:conds];
        algebra = [[GTWTree alloc] initWithType:kAlgebraOrderBy value: vlist arguments:@[algebra]];
    }
    
    t   = [self peekNextNonCommentToken];
    if (t && t.type == KEYWORD) {
        id<GTWTerm> limit, offset;
        if ([t.value isEqual: @"LIMIT"]) {
            [self nextNonCommentToken];
            t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
            ASSERT_EMPTY(errors);
            limit    = (GTWLiteral*) [self tokenAsTerm:t];
            
            t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"LIMIT"];
            if (t) {
                t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
                ASSERT_EMPTY(errors);
                offset    = (GTWLiteral*) [self tokenAsTerm:t];
            }
        } else if ([t.value isEqual: @"OFFSET"]) {
            [self nextNonCommentToken];
            t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
            ASSERT_EMPTY(errors);
            offset    = (GTWLiteral*) [self tokenAsTerm:t];
            
            t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"LIMIT"];
            if (t) {
                t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
                ASSERT_EMPTY(errors);
                limit    = (GTWLiteral*) [self tokenAsTerm:t];
            }
        }
        if (limit || offset) {
            if (!limit)
                limit   = [[GTWLiteral alloc] initWithString:@"-1" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            if (!offset)
                offset   = [[GTWLiteral alloc] initWithString:@"0" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            algebra   = [[GTWTree alloc] initWithType:kAlgebraSlice arguments:@[
                          algebra,
                          [[GTWTree alloc] initLeafWithType:kTreeNode value: offset pointer:NULL],
                          [[GTWTree alloc] initLeafWithType:kTreeNode value: limit pointer:NULL],
                      ]];
        }
    }
    
    return algebra;
}

//[22]  	HavingCondition	  ::=  	Constraint
//[24]  	OrderCondition	  ::=  	 ( ( 'ASC' | 'DESC' ) BrackettedExpression )
//| ( Constraint | Var )



//[28]  	ValuesClause	  ::=  	( 'VALUES' DataBlock )?
- (id<GTWTree>) parseValuesClauseForAlgebra: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"VALUES"];
    if (t) {
        id<GTWTree> data    = [self parseDataBlockWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kAlgebraJoin arguments:@[algebra, data]];
    } else {
        return algebra;
    }
}



// [54]  	GroupGraphPatternSub	  ::=  	TriplesBlock? ( GraphPatternNotTriples '.'? TriplesBlock? )*
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
        
        if ([self tokenIsVarOrTerm:t]) {
            algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
            ASSERT_EMPTY(errors);
            if (algebra) {
                [args addObject:[self reduceTriplePaths: algebra]];
            }
        } else {
            switch (type) {
                case LPAREN:
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
                    algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
                    ASSERT_EMPTY(errors);
                    if (algebra) {
                        [args addObject:[self reduceTriplePaths: algebra]];
                    }
                    break;
                case LBRACE:
                    algebra = [self treeByParsingGraphPatternNotTriplesWithError:errors];
                    ASSERT_EMPTY(errors);
                    if (!algebra)
                        return nil;
                    [args addObject:algebra];
                    [self parseOptionalTokenOfType:DOT];
                    break;
                case KEYWORD:
                    if ([t.value isEqual:@"A"]) {
                        algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
                        ASSERT_EMPTY(errors);
                        if (!algebra)
                            return nil;
                        [args addObject:[self reduceTriplePaths: algebra]];
                    } else {
                        algebra = [self treeByParsingGraphPatternNotTriplesWithError:errors];
                        ASSERT_EMPTY(errors);
                        if (!algebra)
                            return nil;
                        [args addObject:algebra];
                    }
                    break;
                default:
                    ok  = NO;
            }
        }
    }
    
    NSMutableArray* filterargs  = [NSMutableArray arrayWithCapacity:[args count]];
    BOOL filterSeen = NO;
    for (id<GTWTree> t in args) {
        if (t.type == kAlgebraFilter) {
            filterSeen  = YES;
            id<GTWTree> prev;
            if ([filterargs count]) {
                prev    = [filterargs lastObject];
                [filterargs removeLastObject];
            } else {
                prev    = [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
            }
            t.arguments = @[prev];
            [filterargs addObject:t];
        } else {
            [filterargs addObject:t];
        }
    }
    
    if (filterSeen) {
        args    = filterargs;
    }
    return [[GTWTree alloc] initWithType:kTreeList arguments:args];
}


//[60]  	Bind	  ::=  	'BIND' '(' Expression 'AS' Var ')'
- (id<GTWTree>) parseBindWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"BIND" withErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> var     = [self parseVarWithErrors: errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> bind    = [[GTWTree alloc] initWithType:kAlgebraExtend arguments:@[expr, var]];
    return bind;
}


//[61]  	InlineData	  ::=  	'VALUES' DataBlock
- (id<GTWTree>) parseInlineDataWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"VALUES" withErrors:errors];
    ASSERT_EMPTY(errors);
    return [self parseDataBlockWithErrors:errors];
}

//[62]  	DataBlock	  ::=  	InlineDataOneVar | InlineDataFull
//[63]  	InlineDataOneVar	  ::=  	Var '{' DataBlockValue* '}'
//[64]  	InlineDataFull	  ::=  	( NIL | '(' Var* ')' ) '{' ( '(' DataBlockValue* ')' | NIL )* '}'
- (id<GTWTree>) parseDataBlockWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == VAR) {
        // InlineDataOneVar
        id<GTWTree> var     = [self parseVarWithErrors: errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:LBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        NSArray* values = [self parseDataBlockValuesWithErrors: errors];
        ASSERT_EMPTY(errors);
        // XXX DataBlockValue*
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        NSDictionary* results   = @{};  // XXX
        return [[GTWTree alloc] initWithType:kTreeResult arguments:results];
    } else {
        NSArray* vars;
        if (t.type == NIL) {
            // InlineDataFull
            [self parseExpectedTokenOfType:NIL withErrors:errors];
            ASSERT_EMPTY(errors);
            vars    = @[];
        } else {
            // InlineDataFull
            [self parseExpectedTokenOfType:LPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            GTWSPARQLToken* t   = [self peekNextNonCommentToken];
            NSMutableArray* v   = [NSMutableArray array];
            while (t.type == VAR) {
                id<GTWTree> var     = [self parseVarWithErrors: errors];
                [v addObject:var];
                t   = [self peekNextNonCommentToken];
            }
            [self parseExpectedTokenOfType:RPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            vars    = v;
        }
        
        [self parseExpectedTokenOfType:LBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        
        NSMutableArray* results = [NSMutableArray array];
        t   = [self peekNextNonCommentToken];
        while (t.type == NIL || t.type == LPAREN) {
            NSArray* values;
            if (t.type == NIL) {
                [self parseExpectedTokenOfType:NIL withErrors:errors];
                ASSERT_EMPTY(errors);
                values  = @[];
            } else {
                [self parseExpectedTokenOfType:LPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                values = [self parseDataBlockValuesWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
            }
            t   = [self peekNextNonCommentToken];
            
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            NSUInteger i;
            for (i = 0; i < [vars count]; i++) {
                id<GTWTree> key     = [vars objectAtIndex:i];
                id<GTWTree> value   = [values objectAtIndex:i];
                dict[key.value]   = value;
            }
            id<GTWTree> result  = [[GTWTree alloc] initWithType:kTreeResult value:dict arguments:nil];
            [results addObject:result];
        }
        
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        
        return [[GTWTree alloc] initWithType:kTreeResultSet arguments:results];
    }
    return nil;
}


//[65]  	DataBlockValue	  ::=  	iri |	RDFLiteral |	NumericLiteral |	BooleanLiteral |	'UNDEF'
- (NSArray*) parseDataBlockValuesWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    NSMutableArray* values  = [NSMutableArray array];
    while ([self tokenIsTerm:t]) {
        [self nextNonCommentToken];
        id<GTWTerm> term   = [self tokenAsTerm:t];
        id<GTWTree> data    = [[GTWTree alloc] initWithType:kTreeNode value:term arguments:nil];
        ASSERT_EMPTY(errors);
        [values addObject:data];
        t   = [self peekNextNonCommentToken];
    }
    return values;
}






// Returns an NSArray of triples. Each item in the array is a kTreeList with three items, a subject term, an path (with a path tree type), and an object term.
// TriplesSameSubjectPath	  ::=  	VarOrTerm PropertyListPathNotEmpty |	TriplesNodePath PropertyListPath
- (NSArray*) triplesArrayByParsingTriplesSameSubjectPathWithErrors: (NSMutableArray*) errors {
    NSMutableArray* triples = [NSMutableArray array];
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    id<GTWTree> node    = nil;
    if ([self tokenIsVarOrTerm:t]) {
//        NSLog(@"parsing triples on VarOrTerm code path");
        id<GTWTree> subject = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> propertyObjectTriples = [self parsePropertyListPathNotEmptyForSubject:subject withErrors:errors];
        if (!propertyObjectTriples)
            return nil;
        [triples addObjectsFromArray:propertyObjectTriples.arguments];
        return triples;
    } else {
//        NSLog(@"parsing triples on TriplesNodePath code path");
        id<GTWTree> nodetriples = [self parseTriplesNodePathAsNode: &node withErrors:errors];
        for (id<GTWTree> t in nodetriples.arguments) {
            [triples addObject:t];
        }
        id<GTWTree> propertyObjectTriples = [self parsePropertyListPathForSubject:node withErrors:errors];
        if (propertyObjectTriples) {
            [triples addObjectsFromArray:propertyObjectTriples.arguments];
        }
        return triples;
    }
}

// [72]  	ExpressionList	  ::=  	NIL | '(' Expression ( ',' Expression )* ')'
- (id<GTWTree>) parseExpressionListWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == NIL) {
        [self nextNonCommentToken];
        return [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* list    = [NSMutableArray arrayWithObject:expr];
        t   = [self peekNextNonCommentToken];
        while (t.type == COMMA) {
            [self nextNonCommentToken];
            id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            [list addObject:expr];
            t   = [self peekNextNonCommentToken];
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kTreeList arguments:list];
    }
}


// [77]  	PropertyListNotEmpty	  ::=  	Verb ObjectList ( ';' ( Verb ObjectList )? )*
- (NSArray*) propertyObjectPairsByParsingPropertyListNotEmptyWithErrors: (NSMutableArray*) errors {
    NSMutableArray* plist   = [NSMutableArray array];
    id<GTWTree> verb    = [self parseVerbWithErrors: errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> objectList  = [self parseObjectListWithErrors:errors];
    ASSERT_EMPTY(errors);
    for (id<GTWTree> o in objectList.arguments) {
        id<GTWTree> pair  = [[GTWTree alloc] initWithType:kTreeList arguments:@[ verb, o ]];
        [plist addObject:pair];
    }
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == SEMICOLON) {
        [self nextNonCommentToken];
        t   = [self peekNextNonCommentToken];
        if (t.type == VAR || t.type == IRI || (t.type == KEYWORD && [t.value isEqual: @"A"])) {
            id<GTWTree> verb    = [self parseVerbWithErrors: errors];
            ASSERT_EMPTY(errors);
            id<GTWTree> objectList  = [self parseObjectListWithErrors:errors];
            ASSERT_EMPTY(errors);
            for (id<GTWTree> o in objectList.arguments) {
                id<GTWTree> pair  = [[GTWTree alloc] initWithType:kTreeList arguments:@[ verb, o ]];
                [plist addObject:pair];
            }
            t   = [self peekNextNonCommentToken];
        }
    }
    
    return plist;
}

// [78]  	Verb	  ::=  	VarOrIri | 'a'
- (id<GTWTree>) parseVerbWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        [self nextNonCommentToken];
        id<GTWTerm> term   = [self tokenAsTerm:t];
        // TODO: ensure term is of correct type
        return [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else {
        return [self parseVarOrIRIWithErrors:errors];
    }
}

// [79]  	ObjectList	  ::=  	Object ( ',' Object )*
- (id<GTWTree>) parseObjectListWithErrors: (NSMutableArray*) errors {
    id<GTWTree> object  = [self parseObjectWithErrors: errors];
    ASSERT_EMPTY(errors);
    NSMutableArray* objects = [NSMutableArray arrayWithObject:object];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == COMMA) {
        [self nextNonCommentToken];
        id<GTWTree> object  = [self parseObjectWithErrors: errors];
        ASSERT_EMPTY(errors);
        [objects addObject:object];
    }
    return [[GTWTree alloc] initWithType:kTreeList arguments:objects];
}

// [80]  	Object	  ::=  	GraphNode
- (id<GTWTree>) parseObjectWithErrors: (NSMutableArray*) errors {
    return [self parseGraphNodeWithErrors:errors];
}

// [82]  	PropertyListPath	  ::=  	PropertyListPathNotEmpty?
- (id<GTWTree>) parsePropertyListPathForSubject: (id<GTWTree>) subject withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVerb:t]) {
        return [self parsePropertyListPathNotEmptyForSubject: subject withErrors:errors];
    } else {
        return nil;
    }
}

// [83]  	PropertyListPathNotEmpty	  ::=  	( VerbPath | VerbSimple ) ObjectListPath ( ';' ( ( VerbPath | VerbSimple ) ObjectList )? )*
- (id<GTWTree>) parsePropertyListPathNotEmptyForSubject: (id<GTWTree>) subject withErrors: (NSMutableArray*) errors {
    id<GTWTree> verb    = nil;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == VAR) {    // VerbSimple
        verb    = [self parseVerbSimpleWithErrors:errors];
        ASSERT_EMPTY(errors);
        if (!verb)
            return nil;
    } else {
        verb    = [self parseVerbPathWithErrors:errors];
        ASSERT_EMPTY(errors);
        if (!verb)
            return nil;
    }
    
    NSArray* objectList;
    id<GTWTree> triples = [self parseObjectListPathAsNodes:&objectList withErrors:errors];
    NSMutableArray* propertyObjects = [NSMutableArray arrayWithArray:triples.arguments];
    for (id o in objectList) {
        id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreeList arguments:@[ subject, verb, o ]];
        [propertyObjects addObject:triple];
    }
    
    t   = [self peekNextNonCommentToken];
    while (t && t.type == SEMICOLON) {
        [self nextNonCommentToken];
        t   = [self peekNextNonCommentToken];
        id<GTWTree> verb    = nil;
        if (t.type == VAR) {    // VerbSimple
            verb    = [self parseVerbSimpleWithErrors:errors];
            ASSERT_EMPTY(errors);
        } else {
            verb    = [self parseVerbPathWithErrors:errors];
            ASSERT_EMPTY(errors);
        }
        
        NSArray* objectList;
        id<GTWTree> triples = [self parseObjectListPathAsNodes:&objectList withErrors:errors];
        [propertyObjects addObjectsFromArray:triples.arguments];
        for (id o in objectList) {
            id<GTWTree> triple  = [[GTWTree alloc] initWithType:kTreeList arguments:@[ subject, verb, o ]];
            [propertyObjects addObject:triple];
        }
        t   = [self peekNextNonCommentToken];
    }
    
    return [[GTWTree alloc] initWithType:kTreeList arguments:propertyObjects];
}

// [84]  	VerbPath	  ::=  	Path
- (id<GTWTree>) parseVerbPathWithErrors: (NSMutableArray*) errors {
    return [self parsePathWithErrors:errors];
}

// [85]  	VerbSimple	  ::=  	Var
- (id<GTWTree>) parseVerbSimpleWithErrors: (NSMutableArray*) errors {
    return [self parseVarWithErrors:errors];
}

// [86]  	ObjectListPath	  ::=  	ObjectPath ( ',' ObjectPath )*
- (id<GTWTree>) parseObjectListPathAsNodes: (NSArray**) nodes withErrors: (NSMutableArray*) errors {
    id<GTWTree> node    = nil;
    id<GTWTree> triplesTree     = [self parseObjectPathAsNode:&node withErrors:errors];
    NSMutableArray* triples     = [NSMutableArray arrayWithArray:triplesTree.arguments];
    NSMutableArray* objects = [NSMutableArray arrayWithObject:node];
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == COMMA) {
        [self nextNonCommentToken];

        id<GTWTree> triplesTree     = [self parseObjectPathAsNode:&node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:triplesTree.arguments];
        [objects addObject:node];
    }
   
    *nodes  = objects;
    return [[GTWTree alloc] initWithType:kTreeList arguments:triples];
}

// [88]  	Path	  ::=  	PathAlternative
- (id<GTWTree>) parsePathWithErrors: (NSMutableArray*) errors {
    return [self parsePathAlternativeWithErrors:errors];
}

// [87]  	ObjectPath	  ::=  	GraphNodePath
- (id<GTWTree>) parseObjectPathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    return [self parseGraphNodePathAsNode:node withErrors:errors];
}

// [89]  	PathAlternative	  ::=  	PathSequence ( '|' PathSequence )*
- (id<GTWTree>) parsePathAlternativeWithErrors: (NSMutableArray*) errors {
    id<GTWTree> path    = [self parsePathSequenceWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!path)
        return nil;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == OR) {
        [self nextNonCommentToken];
        id<GTWTree> pathAlt    = [self parsePathSequenceWithErrors:errors];
        ASSERT_EMPTY(errors);
        path    = [[GTWTree alloc] initWithType:kPathOr arguments:@[path, pathAlt]];
        t   = [self peekNextNonCommentToken];
    }
    return path;
}

// [90]  	PathSequence	  ::=  	PathEltOrInverse ( '/' PathEltOrInverse )*
- (id<GTWTree>) parsePathSequenceWithErrors: (NSMutableArray*) errors {
    id<GTWTree> path    = [self parsePathEltOrInverseWithErrors: errors];
    ASSERT_EMPTY(errors);
    if (!path)
        return nil;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == SLASH) {
        [self nextNonCommentToken];
        id<GTWTree> pathSeq    = [self parsePathEltOrInverseWithErrors:errors];
        ASSERT_EMPTY(errors);
        path    = [[GTWTree alloc] initWithType:kPathSequence arguments:@[path, pathSeq]];
        t   = [self peekNextNonCommentToken];
    }
    return path;
}

// [91]  	PathElt	  ::=  	PathPrimary PathMod?
// [93]  	PathMod	  ::=  	'?' | '*' | '+'
- (id<GTWTree>) parsePathEltWithErrors: (NSMutableArray*) errors {
    id<GTWTree> elt = [self parsePathPrimaryWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!elt)
        return nil;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == QUESTION) {
        [self nextNonCommentToken];
        return [[GTWTree alloc] initWithType:kPathZeroOrOne arguments:@[elt]];
    } else if (t.type == STAR) {
        [self nextNonCommentToken];
        return [[GTWTree alloc] initWithType:kPathZeroOrMore arguments:@[elt]];
    } else if (t.type == PLUS) {
        [self nextNonCommentToken];
        return [[GTWTree alloc] initWithType:kPathOneOrMore arguments:@[elt]];
    } else {
        return elt;
    }
}

// [92]  	PathEltOrInverse	  ::=  	PathElt | '^' PathElt
- (id<GTWTree>) parsePathEltOrInverseWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == HAT) {
        [self nextNonCommentToken];
        id<GTWTree> path    = [self parsePathEltWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kPathInverse arguments:@[path]];
    } else {
        id<GTWTree> path    = [self parsePathEltWithErrors:errors];
        ASSERT_EMPTY(errors);
        if (!path)
            return nil;
        t   = [self peekNextNonCommentToken];
        while (t && t.type == HAT) {
            [self nextNonCommentToken];
            id<GTWTree> pathInv    = [self parsePathEltWithErrors:errors];
            ASSERT_EMPTY(errors);
            path    = [[GTWTree alloc] initWithType:kPathInverse arguments:@[path, pathInv]];
            t   = [self peekNextNonCommentToken];
        }
        return path;
    }
}

// [94]  	PathPrimary	  ::=  	iri | 'a' | '!' PathNegatedPropertySet | '(' Path ')'
- (id<GTWTree>) parsePathPrimaryWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> path    = [self parsePathWithErrors:errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    } else if (t.type == KEYWORD && [t.value isEqual: @"A"]) {
        id<GTWTerm> term    = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else if (t.type == BANG) {
        id<GTWTree> path    = [self parsePathNegatedPropertySetWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kPathNegate arguments:@[path]];
    } else {
        id<GTWTree> path    = [self parseIRIWithErrors:errors];
//        NSLog(@"primary path element: %@", path);
        ASSERT_EMPTY(errors);
        return path;
    }
}

// [95]  	PathNegatedPropertySet	  ::=  	PathOneInPropertySet | '(' ( PathOneInPropertySet ( '|' PathOneInPropertySet )* )? ')'
- (id<GTWTree>) parsePathNegatedPropertySetWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> path    = [self parsePathOneInPropertySetWithErrors:errors];
        t   = [self peekNextNonCommentToken];
        
        // XXX is this really optional? what sort of a path is '(' ')' ?
        while (t && t.type == OR) {
            [self nextNonCommentToken];
            id<GTWTree> rhs = [self parsePathOneInPropertySetWithErrors:errors];
            ASSERT_EMPTY(errors);
            path            = [[GTWTree alloc] initWithType:kPathOr arguments:@[path, rhs]];
            t   = [self peekNextNonCommentToken];
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    } else {
        id<GTWTree> set = [self parsePathOneInPropertySetWithErrors:errors];
        ASSERT_EMPTY(errors);
        return set;
    }
}

// [96]  	PathOneInPropertySet	  ::=  	iri | 'a' | '^' ( iri | 'a' )
- (id<GTWTree>) parsePathOneInPropertySetWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == HAT) {
        [self nextNonCommentToken];
        t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD && [t.value isEqual: @"A"]) {
            [self nextNonCommentToken];
            id<GTWTerm> term    = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            id<GTWTree> path    = [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
            return [[GTWTree alloc] initWithType:kPathInverse arguments:@[path]];
        } else {
            id<GTWTree> path    = [self parseIRIWithErrors: errors];
            return [[GTWTree alloc] initWithType:kPathInverse arguments:@[path]];
        }
    } else if (t.type == KEYWORD && [t.value isEqual: @"A"]) {
        [self nextNonCommentToken];
        id<GTWTerm> term    = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else {
        return [self parseIRIWithErrors: errors];
    }
}

// [99]  	BlankNodePropertyList	  ::=  	'[' PropertyListNotEmpty ']'
- (NSArray*) propertyObjectPairsByParsingBlankNodePropertyListAsNode: (id<GTWTree>*) node WithErrors: (NSMutableArray*) errors {
    // need to handle bnode generation
    GTWBlank* subj  = self.bnodeIDGenerator(nil);
    *node   = [[GTWTree alloc] initWithType:kTreeNode value: subj arguments:nil];
    [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    NSArray* plist    = [self propertyObjectPairsByParsingPropertyListNotEmptyWithErrors: errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    return plist;
}

// [100]  	TriplesNodePath	  ::=  	CollectionPath |	BlankNodePropertyListPath
- (id<GTWTree>) parseTriplesNodePathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self triplesByParsingCollectionPathAsNode: (id<GTWTree>*) node withErrors: errors];
    } else {
        return [self parseBlankNodePropertyListPathAsNode:node withErrors:errors];
    }
}

// [101]  	BlankNodePropertyListPath	  ::=  	'[' PropertyListPathNotEmpty ']'
- (id<GTWTree>) parseBlankNodePropertyListPathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWBlank* subj  = self.bnodeIDGenerator(nil);
    *node   = [[GTWTree alloc] initWithType:kTreeNode value: subj arguments:nil];
    id<GTWTree> path    = [self parsePropertyListPathNotEmptyForSubject:*node withErrors:errors];
    [self parseExpectedTokenOfType:RBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    return path;
}

// [102]  	Collection	  ::=  	'(' GraphNode+ ')'
- (id<GTWTree>) parseCollectionAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    // XXX need to handle bnode generation and setting *node and parsing of multiple terms
    id<GTWTree> n    = [self parseGraphNodeWithErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    return n;
}

// [103]  	CollectionPath	  ::=  	'(' GraphNodePath+ ')'
- (id<GTWTree>) triplesByParsingCollectionPathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> graphNodePath    = [self parseGraphNodePathAsNode: node withErrors:errors];
    NSMutableArray* triples = [NSMutableArray arrayWithArray:graphNodePath.arguments];
    NSMutableArray* nodes   = [NSMutableArray arrayWithObject:*node];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type != RPAREN) {
        id<GTWTree> graphNodePath    = [self parseGraphNodePathAsNode: node withErrors:errors];
        [triples addObjectsFromArray:graphNodePath.arguments];
        [nodes addObject:*node];
        t   = [self peekNextNonCommentToken];
    }
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    
    
    GTWBlank* bnode  = self.bnodeIDGenerator(nil);
    id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeNode value: bnode arguments:nil];
    *node   = list;
    
    
    GTWIRI* rdffirst    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rdfrest    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
    GTWIRI* rdfnil    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"];
    
    if ([nodes count]) {
        for (NSUInteger i = 0; i < [nodes count]; i++) {
            id<GTWTree> o   = [nodes objectAtIndex:i];
            GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:o.value];
            [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil]];
            if (i == [nodes count]-1) {
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:rdfnil];
                [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil]];
            } else {
                GTWBlank* newbnode  = self.bnodeIDGenerator(nil);
                id<GTWTree> newlist = [[GTWTree alloc] initWithType:kTreeNode value: newbnode arguments:nil];
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:newlist.value];
                [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil]];
                list    = newlist;
            }
        }
    } else {
        GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:rdfnil];
        [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil]];
    }
    
    return [[GTWTree alloc] initWithType:kTreeList arguments:triples];
}

// [104]  	GraphNode	  ::=  	VarOrTerm |	TriplesNode
- (id<GTWTree>) parseGraphNodeWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVarOrTerm:t]) {
        return [self parseVarOrTermWithErrors:errors];
    } else {
        return nil; // XXX
    }
}

// [105]  	GraphNodePath	  ::=  	VarOrTerm |	TriplesNodePath
- (id<GTWTree>) parseGraphNodePathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVarOrTerm:t]) {
        *node   = [self parseVarOrTermWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        return [self parseTriplesNodePathAsNode:node withErrors:errors];
    }
}



// [106]  	VarOrTerm	  ::=  	Var | GraphTerm
- (BOOL) tokenIsTerm: (GTWSPARQLToken*) t {
    switch (t.type) {
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
    if (t.type == VAR)
        return YES;
    
    return NO;
}

- (BOOL) tokenIsVarOrTerm: (GTWSPARQLToken*) t {
    switch (t.type) {
        case VAR:
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
    if (t.type == VAR)
        return YES;
    
    return NO;
}

- (BOOL) tokenIsVerb: (GTWSPARQLToken*) t {
    if ([self tokenIsVarOrTerm:t])
        return YES;
    switch (t.type) {
        case LPAREN:
        case HAT:
        case BANG:
            return YES;
        default:
            return NO;
    }
}

- (id<GTWTree>) parseVarOrTermWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token];
    // TODO: ensure term is of correct type
    return [[GTWTree alloc] initWithType:kTreeNode value:t arguments:nil];
}

// [107]  	VarOrIri	  ::=  	Var | iri
- (id<GTWTree>) parseVarOrIRIWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token];
    // TODO: ensure term is of correct type
    return [[GTWTree alloc] initWithType:kTreeNode value: t arguments:nil];
}

// [108]  	Var	  ::=  	VAR1 | VAR2
- (id<GTWTree>) parseVarWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token];
    // TODO: ensure term is of correct type
    return [[GTWTree alloc] initWithType:kTreeNode value: t arguments:nil];
}

// [110]  	Expression	  ::=  	ConditionalOrExpression
- (id<GTWTree>) parseExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseConditionalOrExpressionWithErrors:errors];
//    NSLog(@"expression: %@", expr);
    return expr;
}

//[111]  	ConditionalOrExpression	  ::=  	ConditionalAndExpression ( '||' ConditionalAndExpression )*
- (id<GTWTree>) parseConditionalOrExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseConditionalAndExpressionWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == OROR) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseConditionalAndExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[GTWTree alloc] initWithType:kExprOr arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
//    NSLog(@"conditional or expression: %@", expr);
    return expr;
}

//[112]  	ConditionalAndExpression	  ::=  	ValueLogical ( '&&' ValueLogical )*
- (id<GTWTree>) parseConditionalAndExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseValueLogicalWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == ANDAND) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseValueLogicalWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[GTWTree alloc] initWithType:kExprAnd arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
//    NSLog(@"conditional and expression: %@", expr);
    return expr;
}

//[113]  	ValueLogical	  ::=  	RelationalExpression
- (id<GTWTree>) parseValueLogicalWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseRelationalExpressionWithErrors:errors];
//    NSLog(@"value logical expression: %@", expr);
    return expr;
}

//[114]  	RelationalExpression	  ::=  	NumericExpression ( '=' NumericExpression | '!=' NumericExpression | '<' NumericExpression | '>' NumericExpression | '<=' NumericExpression | '>=' NumericExpression | 'IN' ExpressionList | 'NOT' 'IN' ExpressionList )?
- (id<GTWTree>) parseRelationalExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseNumericExpressionWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t && (t.type == EQUALS || t.type == NOTEQUALS || t.type == LT || t.type == GT || t.type == LE || t.type == GE)) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseNumericExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        GTWTreeType type;
        switch (t.type) {
            case EQUALS:
                type    = kExprEq;
                break;
            case NOTEQUALS:
                type    = kExprNeq;
                break;
            case LT:
                type    = kExprLt;
                break;
            case GT:
                type    = kExprGt;
                break;
            case LE:
                type    = kExprLe;
                break;
            case GE:
                type    = kExprGe;
                break;
            default:
                return nil;
        }
        expr    = [[GTWTree alloc] initWithType:type arguments:@[expr, rhs]];
    } else if (t && t.type == KEYWORD && [t.value isEqual: @"IN"]) {
        [self nextNonCommentToken];
        id<GTWTree> list    = [self parseExpressionListWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kExprIn arguments:@[expr, list]];
    } else if (t && t.type == KEYWORD && [t.value isEqual: @"NOT"]) {
        [self nextNonCommentToken];
        [self parseExpectedTokenOfType:KEYWORD withValue:@"IN" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> list    = [self parseExpressionListWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kExprNotIn arguments:@[expr, list]];
    }
//    NSLog(@"relational expression: %@", expr);
    return expr;
}

//[115]  	NumericExpression	  ::=  	AdditiveExpression
- (id<GTWTree>) parseNumericExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseAdditiveExpressionWithErrors:errors];
//    NSLog(@"numeric expression: %@", expr);
    return expr;
}

//[116]  	AdditiveExpression	  ::=  	MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )* )*
- (id<GTWTree>) parseAdditiveExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseMultiplicativeExpressionWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    
    // XXX handle ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )*
    while (t && (t.type == PLUS || t.type == MINUS)) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseMultiplicativeExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[GTWTree alloc] initWithType:(t.type == PLUS ? kExprPlus : kExprMinus) arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
//    NSLog(@"additive expression: %@", expr);
    return expr;
}

//[117]  	MultiplicativeExpression	  ::=  	UnaryExpression ( '*' UnaryExpression | '/' UnaryExpression )*
- (id<GTWTree>) parseMultiplicativeExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseUnaryExpressionWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && (t.type == STAR || t.type == SLASH)) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseUnaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[GTWTree alloc] initWithType:(t.type == STAR ? kExprMul : kExprDiv) arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
//    NSLog(@"multiplicative expression: %@", expr);
    return expr;
}

//[118]  	UnaryExpression	  ::=  	  '!' PrimaryExpression
//|	'+' PrimaryExpression
//|	'-' PrimaryExpression
//|	PrimaryExpression
- (id<GTWTree>) parseUnaryExpressionWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == BANG) {
        [self parseExpectedTokenOfType:BANG withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kExprBang arguments:@[expr]];
    } else if (t.type == PLUS) {
        [self parseExpectedTokenOfType:PLUS withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else if (t.type == MINUS) {
        [self parseExpectedTokenOfType:MINUS withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kExprUMinus arguments:@[expr]];
    } else {
        id<GTWTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    }
}


//[119]  	PrimaryExpression	  ::=  	BrackettedExpression | BuiltInCall | iriOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | Var
- (id<GTWTree>) parsePrimaryExpressionWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self parseBrackettedExpressionWithErrors: errors];
    } else if (t.type == IRI || t.type == PREFIXNAME) {
        return [self parseIRIOrFunctionWithErrors: errors];
    } else if ([self tokenIsVarOrTerm:t]) {
        id<GTWTree> expr    = [self parseVarOrTermWithErrors:errors];
//        NSLog(@"primary expression var/term: %@", expr);
        ASSERT_EMPTY(errors);
//        NSLog(@"primary expression: %@", expr);
        return expr;
    } else {
        return [self parseBuiltInCallWithErrors:errors];
//        return [self errorMessage:[NSString stringWithFormat:@"primary expression not implemented: %@", t] withErrors:errors];
    }
}

// [128]  	iriOrFunction	  ::=  	iri ArgList?
//[71]  	ArgList	  ::=  	NIL | '(' 'DISTINCT'? Expression ( ',' Expression )* ')'
- (id<GTWTree>) parseIRIOrFunctionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> iri    = [self parseVarOrTermWithErrors:errors];
    ASSERT_EMPTY(errors);
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == NIL) {
        [self parseExpectedTokenOfType:NIL withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> func    = [[GTWTree alloc] initWithType:kExprFunction value:iri.value arguments:@[]];
        return func;
    } else if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];    // XXX
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* list    = [NSMutableArray arrayWithObject: expr];

        t   = [self peekNextNonCommentToken];
        while (t.type == COMMA) {
            [self nextNonCommentToken];
            id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            [list addObject:expr];
            t   = [self peekNextNonCommentToken];
        }

        id<GTWTree> func    = [[GTWTree alloc] initWithType:kExprFunction value:iri.value arguments:list];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return func;
    } else {
        return iri;
    }
}


// [120]  	BrackettedExpression	  ::=  	'(' Expression ')'
- (id<GTWTree>) parseBrackettedExpressionWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    return expr;
}

//[121]  	BuiltInCall	  ::=  	  Aggregate
//|	'STR' '(' Expression ')'
//|	'LANG' '(' Expression ')'
//|	'LANGMATCHES' '(' Expression ',' Expression ')'
//|	'DATATYPE' '(' Expression ')'
//|	'BOUND' '(' Var ')'
//|	'IRI' '(' Expression ')'
//|	'URI' '(' Expression ')'
//|	'BNODE' ( '(' Expression ')' | NIL )
//|	'RAND' NIL
//|	'ABS' '(' Expression ')'
//|	'CEIL' '(' Expression ')'
//|	'FLOOR' '(' Expression ')'
//|	'ROUND' '(' Expression ')'
//|	'CONCAT' ExpressionList
//|	SubstringExpression
//|	'STRLEN' '(' Expression ')'
//|	StrReplaceExpression
//|	'UCASE' '(' Expression ')'
//|	'LCASE' '(' Expression ')'
//|	'ENCODE_FOR_URI' '(' Expression ')'
//|	'CONTAINS' '(' Expression ',' Expression ')'
//|	'STRSTARTS' '(' Expression ',' Expression ')'
//|	'STRENDS' '(' Expression ',' Expression ')'
//|	'STRBEFORE' '(' Expression ',' Expression ')'
//|	'STRAFTER' '(' Expression ',' Expression ')'
//|	'YEAR' '(' Expression ')'
//|	'MONTH' '(' Expression ')'
//|	'DAY' '(' Expression ')'
//|	'HOURS' '(' Expression ')'
//|	'MINUTES' '(' Expression ')'
//|	'SECONDS' '(' Expression ')'
//|	'TIMEZONE' '(' Expression ')'
//|	'TZ' '(' Expression ')'
//|	'NOW' NIL
//|	'UUID' NIL
//|	'STRUUID' NIL
//|	'MD5' '(' Expression ')'
//|	'SHA1' '(' Expression ')'
//|	'SHA256' '(' Expression ')'
//|	'SHA384' '(' Expression ')'
//|	'SHA512' '(' Expression ')'
//|	'COALESCE' ExpressionList
//|	'IF' '(' Expression ',' Expression ',' Expression ')'
//|	'STRLANG' '(' Expression ',' Expression ')'
//|	'STRDT' '(' Expression ',' Expression ')'
//|	'sameTerm' '(' Expression ',' Expression ')'
//|	'isIRI' '(' Expression ')'
//|	'isURI' '(' Expression ')'
//|	'isBLANK' '(' Expression ')'
//|	'isLITERAL' '(' Expression ')'
//|	'isNUMERIC' '(' Expression ')'
//|	RegexExpression
//|	ExistsFunc
//|	NotExistsFunc

- (id<GTWTree>) parseBuiltInCallWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
	NSRange agg_range	= [t.value rangeOfString:@"(COUNT|SUM|MIN|MAX|AVG|SAMPLE|GROUP_CONCAT)" options:NSRegularExpressionSearch];
    NSRange func_range  = [t.value rangeOfString:@"(STR|LANG|LANGMATCHES|DATATYPE|BOUND|IRI|URI|BNODE|RAND|ABS|CEIL|FLOOR|ROUND|CONCAT|STRLEN|UCASE|LCASE|ENCODE_FOR_URI|CONTAINS|STRSTARTS|STRENDS|STRBEFORE|STRAFTER|YEAR|MONTH|DAY|HOURS|MINUTES|SECONDS|TIMEZONE|TZ|NOW|UUID|STRUUID|MD5|SHA1|SHA256|SHA384|SHA512|COALESCE|IF|STRLANG|STRDT|SAMETERM|SUBSTR|REPLACE|ISIRI|ISURI|ISBLANK|ISLITERAL|ISNUMERIC|REGEX)" options:NSRegularExpressionSearch];
    if (t.type == KEYWORD && agg_range.location == 0) {
        return [self parseAggregateWithErrors: errors];
    } else if (t.type == KEYWORD && [t.value isEqualToString:@"NOT"]) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"NOT" withErrors:errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:KEYWORD withValue:@"EXISTS" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
        return [[GTWTree alloc] initWithType:kExprNotExists arguments:@[ggp]];
    } else if (t.type == KEYWORD && [t.value isEqualToString:@"EXISTS"]) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"EXISTS" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
        return [[GTWTree alloc] initWithType:kExprExists arguments:@[ggp]];
    } else if (t.type == KEYWORD && func_range.location == 0) {
        [self nextNonCommentToken];
        NSString* funcname  = t.value;
        // XXX this doesn't conform to the grammar. needs to be fixed
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        NSDictionary* funcdict  = @{
                                    @"STR": kExprStr,
                                    @"LANG": kExprLang,
                                    @"LANGMATCHES": kExprLangMatches,
                                    @"DATATYPE": kExprDatatype,
                                    @"BOUND": kExprBound,
                                    @"IRI": kExprIRI,
                                    @"URI": kExprIRI,
                                    @"BNODE": kExprBNode,
                                    @"RAND": kExprRand,
                                    @"ABS": kExprAbs,
                                    @"CEIL": kExprCeil,
                                    @"FLOOR": kExprFloor,
                                    @"ROUND": kExprRound,
                                    @"CONCAT": kExprConcat,
                                    @"STRLEN": kExprStrLen,
                                    @"UCASE": kExprUCase,
                                    @"LCASE": kExprLCase,
                                    @"ENCODE_FOR_URI": kExprEncodeForURI,
                                    @"CONTAINS": kExprContains,
                                    @"STRSTARTS": kExprStrStarts,
                                    @"STRENDS": kExprStrEnds,
                                    @"STRBEFORE": kExprStrBefore,
                                    @"STRAFTER": kExprStrAfter,
                                    @"YEAR": kExprYear,
                                    @"MONTH": kExprMonth,
                                    @"DAY": kExprDay,
                                    @"HOURS": kExprHours,
                                    @"MINUTES": kExprMinutes,
                                    @"SECONDS": kExprSeconds,
                                    @"TIMEZONE": kExprTimeZone,
                                    @"TZ": kExprTZ,
                                    @"NOW": kExprNow,
                                    @"UUID": kExprUUID,
                                    @"STRUUID": kExprStrUUID,
                                    @"MD5": kExprMD5,
                                    @"SHA1": kExprSHA1,
                                    @"SHA256": kExprSHA256,
                                    @"SHA384": kExprSHA384,
                                    @"SHA512": kExprSHA512,
                                    @"COALESCE": kExprCoalesce,
                                    @"IF": kExprIf,
                                    @"STRLANG": kExprStrLang,
                                    @"STRDT": kExprStrDT,
                                    @"SAMETERM": kExprSameTerm,
                                    @"ISIRI": kExprIsURI,
                                    @"ISURI": kExprIsURI,
                                    @"ISBLANK": kExprIsBlank,
                                    @"ISLITERAL": kExprIsLiteral,
                                    @"ISNUMERIC": kExprIsNumeric,
                                    @"SUBSTR": kExprSubStr,
                                    @"REPLACE": kExprReplace,
                                    @"REGEX": kExprRegex,
                                    };
        GTWTreeType functype    = [funcdict objectForKey:funcname];
        id<GTWTree> func    = [[GTWTree alloc] initWithType:functype arguments:@[expr]];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return func;
    }
    // XXX
    return nil;
}

//[127]  	Aggregate	  ::=  	  'COUNT' '(' 'DISTINCT'? ( '*' | Expression ) ')'
//| 'SUM' '(' 'DISTINCT'? Expression ')'
//| 'MIN' '(' 'DISTINCT'? Expression ')'
//| 'MAX' '(' 'DISTINCT'? Expression ')'
//| 'AVG' '(' 'DISTINCT'? Expression ')'
//| 'SAMPLE' '(' 'DISTINCT'? Expression ')'
//| 'GROUP_CONCAT' '(' 'DISTINCT'? Expression ( ';' 'SEPARATOR' '=' String )? ')'
- (id<GTWTree>) parseAggregateWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
    ASSERT_EMPTY(errors);
    if ([t.value isEqual: @"COUNT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];    // XXX
        GTWSPARQLToken* t   = [self peekNextNonCommentToken];
        id<GTWTree> agg;
        if (t.type == STAR) {
            [self nextNonCommentToken];
            agg     = [[GTWTree alloc] initWithType:kExprCount value: @(d ? YES : NO) arguments:@[]];
        } else {
            id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            agg     = [[GTWTree alloc] initWithType:kExprCount value: @(d ? YES : NO) arguments:@[expr]];
        }
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"SUM"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprSum value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"MIN"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprMin value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"MAX"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprMax value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"AVG"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprAvg value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"SAMPLE"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprSample value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    } else if ([t.value isEqual: @"GROUP_CONCAT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprGroupConcat value: @(d ? YES : NO) arguments:@[expr]];
        
        GTWSPARQLToken* sc  = [self parseOptionalTokenOfType:SEMICOLON];
        if (sc) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"SEPARATOR" withErrors:errors];
            ASSERT_EMPTY(errors);
            [self parseExpectedTokenOfType:EQUALS withErrors:errors];
            ASSERT_EMPTY(errors);
            GTWSPARQLToken* t   = [self nextNonCommentToken];
            id<GTWTerm> str     = [self tokenAsTerm:t];
            id<GTWTree> s       = [[GTWTree alloc] initWithType:kTreeNode value:str arguments:nil];
            // XXX
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        self.seenAggregate  = YES;
        return agg;
    }
    return nil;
}





- (id<GTWTree>) parseIRIWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    // TODO: ensure token is of type IRI or PREFIXNAME
    id<GTWTerm> t   = [self tokenAsTerm:token];
    if (!t)
        return nil;
    // TODO: make sure token is an IRI
    return [[GTWTree alloc] initWithType:kTreeNode value: t arguments:nil];
}



// [55]  	TriplesBlock	  ::=  	TriplesSameSubjectPath ( '.' TriplesBlock? )?
- (id<GTWTree>) triplesByParsingTriplesBlockWithErrors: (NSMutableArray*) errors {
    NSArray* sameSubj    = [self triplesArrayByParsingTriplesSameSubjectPathWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!sameSubj)
        return nil;
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (!t || t.type != DOT) {
        return [[GTWTree alloc] initWithType:kTreeList arguments:sameSubj];
    } else {
        [self nextNonCommentToken];
        
        t   = [self peekNextNonCommentToken];
        // XXX: Check if TriplesBlock can be parsed (it's more than just tokenIsVarOrTerm:)
        if ([self tokenIsVarOrTerm:t] || NO) {
            id<GTWTree> more    = [self triplesByParsingTriplesBlockWithErrors:errors];
            ASSERT_EMPTY(errors);
            NSMutableArray* triples = [NSMutableArray array];
            [triples addObjectsFromArray:sameSubj];
            [triples addObjectsFromArray:more.arguments];
            return [[GTWTree alloc] initWithType:kTreeList arguments:triples];
        } else {
            return [[GTWTree alloc] initWithType:kTreeList arguments:sameSubj];
        }
    }
    
    
    
    
//    NSMutableArray* triples = [NSMutableArray array];
//    while (YES) {
//        GTWSPARQLToken* t   = [self peekNextNonCommentToken];
//        if (t == nil) {
//            // error
//            NSLog(@"*** Unexpected EOF");
//            return nil;
//        }
//        
////        NSLog(@"SPARQL parser lexer token: %@", t);
//        
//        // TODO: handle lists LPAREN/RPAREN
//        // ****  need more state machine stuff to handle this (especially nested list/bnode structures)
//        if (t.type == LBRACKET) {
//            [self nextNonCommentToken];
//            GTWBlank* subj  = self.bnodeIDGenerator(nil);
//            //            NSUInteger ident    = ++self.bnodeID;
//            //            GTWBlank* subj  = [[GTWBlank alloc] initWithID:[NSString stringWithFormat:@"b%lu", ident]];
//            [self pushNewSubject:subj];
//        } else if (t.type == RBRACKET) {
//            [self nextNonCommentToken];
//            // TODO: need to test for balanced brackets
//            id<GTWTerm> b    = [self currentSubject];
//            [self popSubject];
//
//            if ([self haveSubjectPredicatePair]) {
//                id<GTWTerm> subj    = self.currentSubject;
//                id<GTWTerm> pred    = self.currentPredicate;
//                if (subj && pred && b) {
//                    // this BNODE is being used as the object in a triple
//                    id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:subj predicate:pred object:b];
//                    [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:st arguments:nil]];
//                }
//            } else {
//                [self pushNewSubject:b];
//            }
//        } else if (t.type == COMMA) {
//            [self nextNonCommentToken];
//            // no-op
//        } else if (t.type == SEMICOLON) {
//            [self nextNonCommentToken];
//            [self popPredicate];
//        } else if (t.type == DOT) {
//            [self nextNonCommentToken];
//            [self popSubject];
//        } else if ([t isTermOrVar]) {
//            [self nextNonCommentToken];
//            id<GTWTerm> term   = [self tokenAsTerm:t];
////            NSLog(@"got term: %@", term);
//            if ([self haveSubjectPredicatePair]) {
//                //                NSLog(@"--> got object");
//                
//                
//                if ([term isMemberOfClass:[GTWLiteral class]]) {
//                    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
//                    //                    NSLog(@"check for LANG or DT: %@", t);
//                    if (t.type == LANG) {
//                        [self nextNonCommentToken];
//                        //                        NSLog(@"got language: %@", t.value);
//                        GTWLiteral* l   = [[GTWLiteral alloc] initWithString:[term value] language:t.value];
//                        term            = l;
//                    } else if (t.type == HATHAT) {
//                        [self nextNonCommentToken];
//                        GTWSPARQLToken* t   = [self nextNonCommentToken];
//                        id<GTWTerm> dt   = [self tokenAsTerm:t];
//                        GTWLiteral* l   = [[GTWLiteral alloc] initWithString:[term value] datatype:dt.value];
//                        term            = l;
//                    }
//                }
//                
//                
//                id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:[self currentSubject] predicate:[self currentPredicate] object:term];
//                [triples addObject:[[GTWTree alloc] initWithType:kTreeTriple value:st arguments:nil]];
//            } else if ([self haveSubject]) {
////                NSLog(@"--> got predicate");
//                [self pushNewPredicate:term];
//            } else {
////                NSLog(@"--> got subject");
//                [self pushNewSubject:term];
//            }
////        } else if (t.type == KEYWORD) {
////            [self nextNonCommentToken];
////            NSLog(@"unexpected keyword: %@", t);
//        } else {
////            NSLog(@"unexpected token: %@", t);
////            NSLog(@"... with stack: %@", self.stack);
//            break;
//        }
//    }
//    return [[GTWTree alloc] initWithType:kAlgebraBGP arguments:triples];
}

// [56]  	GraphPatternNotTriples	  ::=  	GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
- (id<GTWTree>) treeByParsingGraphPatternNotTriplesWithError: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        NSString* kw    = t.value;
        if ([kw isEqual:@"OPTIONAL"]) {
            // 'OPTIONAL' GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraLeftJoin arguments:@[ggp]];
        } else if ([kw isEqual:@"MINUS"]) {
            // 'MINUS' GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraMinus arguments:@[ggp]];
        } else if ([kw isEqual:@"GRAPH"]) {
            // 'GRAPH' VarOrIri GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> varOrIRI    = [self parseVarOrIRIWithErrors: errors];
            ASSERT_EMPTY(errors);
            if (!varOrIRI)
                return nil;
            id<GTWTerm> g           = varOrIRI.value;
            if (!g)
                return nil;
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraGraph value: g arguments:@[ggp]];
        } else if ([kw isEqual:@"SERVICE"]) {
            // 'SERVICE' 'SILENT'? VarOrIri GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
            id<GTWTree> varOrIRI    = [self parseVarOrIRIWithErrors: errors];
            ASSERT_EMPTY(errors);
            if (!varOrIRI)
                return nil;
            id<GTWTerm> g           = varOrIRI.value;
            if (!g)
                return nil;
            id<GTWTree> ggp = [self parseGroupGraphPatternSubWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraGraph value: g arguments:@[ggp]];
        } else if ([kw isEqual:@"FILTER"]) {
            [self nextNonCommentToken];
            id<GTWTree> f   = [self parseConstraintWithErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWTree alloc] initWithType:kAlgebraFilter value: f arguments:nil];
        } else if ([kw isEqual:@"VALUES"]) {
            return [self parseInlineDataWithErrors: errors];
        } else if ([kw isEqual:@"BIND"]) {
            return [self parseBindWithErrors: errors];
        } else {
            NSLog(@"Unexpected KEYWORD %@ while expecting GraphPatternNotTriples", t.value);
            return nil;
        }
    } else if (t.type == LBRACE) {
        id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
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
    } else if (t.type == STRING1D || t.type == STRING1S) {
        return [[GTWLiteral alloc] initWithString:t.value];
    } else if (t.type == STRING3D || t.type == STRING3S) {
        return [[GTWLiteral alloc] initWithString:t.value];
    } else if ((t.type == KEYWORD) && [t.value isEqual:@"A"]) {
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
    NSLog(@"unexpected token as term: %@ (near '%@')", t, self.lexer.buffer);
    return nil;
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

- (id) errorMessage: (id) message withErrors:(NSMutableArray*) errors {
    [errors addObject:message];
    return nil;
}


@end
