#import "SPKSPARQLParser.h"
#import "SPKSPARQLToken.h"
#import "SPKTree.h"
#import "NSObject+SPKTree.h"
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWQuad.h>

#define ASSERT_EMPTY(e) if ([e count] > 0) return nil;

typedef NS_ENUM(NSInteger, SPKSPARQLParserState) {
    SPKSPARQLParserInSubject,
};


@implementation SPKSPARQLParser

- (SPKSPARQLParser*) initWithLexer: (SPKSPARQLLexer*) lex base: (GTWIRI*) base {
    if (self = [self init]) {
        self.lexer  = lex;
        self.baseIRI   = base;
    }
    return self;
}

- (BOOL) currentQuerySeenAggregates {
    if ([self.seenAggregates count]) {
        NSNumber* s = [self.seenAggregates lastObject];
        return [s boolValue];
    } else {
        return NO;
    }
}

- (SPKSPARQLParser*) init {
    if (self = [super init]) {
        self.seenAggregates = [NSMutableArray array];
        self.aggregateSets  = [NSMutableArray array];
        self.stack  = [NSMutableArray array];
        self.namespaces = [NSMutableDictionary dictionary];
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

- (id<SPKTree>) parseSPARQLQuery: (NSString*) queryString withBaseURI: (NSString*) base error: (NSError**) error {
    NSString *unescaped = [queryString mutableCopy];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)unescaped, NULL, transform, YES);
    
    self.lexer      = [[SPKSPARQLLexer alloc] initWithString:unescaped];
    self.baseIRI    = [[GTWIRI alloc] initWithValue:base];
    return [self parseWithError:error];
}

- (id<SPKTree>) parseSPARQLUpdate: (NSString*) queryString withBaseURI: (NSString*) base error: (NSError**) error {
    NSString *unescaped = [queryString mutableCopy];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)unescaped, NULL, transform, YES);
    
    self.lexer      = [[SPKSPARQLLexer alloc] initWithString:unescaped];
    self.baseIRI    = [[GTWIRI alloc] initWithValue:base];
    return [self parseWithError:error];
}

- (SPKSPARQLToken*) peekNextNonCommentToken {
    while (YES) {
        SPKSPARQLToken* t   = [self.lexer peekToken];
        if (!t)
            return nil;
        if (t.type == COMMENT) {
            [self.lexer getToken];
        } else {
            return t;
        }
    }
}

- (SPKSPARQLToken*) nextNonCommentToken {
    SPKSPARQLToken* t   = [self.lexer getToken];
    while (t.type == COMMENT) {
        t   = [self.lexer getToken];
    }
    return t;
}

//[1]  	QueryUnit	  ::=  	Query
//[2]  	Query	  ::=  	Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery ) ValuesClause
//[3]  	UpdateUnit	  ::=  	Update
//[4]  	Prologue	  ::=  	( BaseDecl | PrefixDecl )*
//[29]  	Update	  ::=  	Prologue ( Update1 ( ';' Update )? )?
//[30]  	Update1	  ::=  	Load | Clear | Drop | Add | Move | Copy | Create | InsertData | DeleteData | DeleteWhere | Modify

- (id<SPKTree>) parseWithError: (NSError**) error {
    SPKSPARQLToken* t;
    id<SPKTree> algebra;
    [self beginQueryScope];
    NSMutableArray* errors  = [NSMutableArray array];
    
    BOOL updateOK   = YES;
    
    @autoreleasepool {
        NSMutableArray* updateOperations    = [NSMutableArray array];
        [self parsePrologueWithErrors: errors];
        if ([errors count])
            goto cleanup;
    UPDATE_LOOP:
        t   = [self peekNextNonCommentToken];
        if (!t) {
            goto UPDATE_BREAK;
        }
        if (t.type != KEYWORD) {
            [self errorMessage:[NSString stringWithFormat:@"expected query method not found: %@", t] withErrors:errors];
            goto cleanup;
        }
        
        if ([t.value isEqualToString: @"SELECT"]) {
            algebra = [self parseSelectQueryWithError:errors];
            if ([errors count])
                goto cleanup;
        } else if ([t.value isEqualToString: @"CONSTRUCT"]) {
            algebra = [self parseConstructQueryWithErrors:errors];
            if ([errors count])
                goto cleanup;
        } else if ([t.value isEqualToString: @"DESCRIBE"]) {
            algebra = [self parseDescribeQueryWithErrors: errors];
            if ([errors count])
                goto cleanup;
        } else if ([t.value isEqualToString: @"ASK"]) {
            algebra = [self parseAskQueryWithError:errors];
            if ([errors count])
                goto cleanup;
        } else if ([t.value rangeOfString:@"^(LOAD|CLEAR|DROP|ADD|MOVE|COPY|CREATE|INSERT|DELETE|WITH)$" options:NSRegularExpressionSearch].location != NSNotFound) {
            if ([t.value isEqualToString: @"LOAD"]) {
                algebra     = [self parseLoadWithErrors: errors];
            } else if ([t.value isEqualToString: @"CLEAR"] || [t.value isEqualToString: @"DROP"]) {
                algebra = [self parseClearOrDropWithErrors: errors];
            } else if ([t.value isEqualToString: @"CREATE"]) {
                algebra = [self parseCreateWithErrors:errors];
            } else if ([t.value isEqualToString:@"ADD"]) {
                algebra = [self parseAddWithErrors:errors];
            } else if ([t.value isEqualToString:@"COPY"]) {
                algebra = [self parseCopyWithErrors:errors];
            } else if ([t.value isEqualToString:@"WITH"]) {
                algebra = [self parseModifyWithParsedVerb:nil withErrors:errors];
            } else if ([t.value isEqualToString: @"INSERT"]) {
                [self parseExpectedTokenOfType:KEYWORD withValue:@"INSERT" withErrors:errors];
                if ([errors count])
                    goto cleanup;
                SPKSPARQLToken* data    = [self parseOptionalTokenOfType:KEYWORD withValue:@"DATA"];
                if (data) {
                    id<SPKTree> quads   = [self parseQuadDataWithErrors: errors];
                    if ([errors count])
                        goto cleanup;
                    algebra = [[SPKTree alloc] initWithType:kAlgebraInsertData arguments:quads.arguments];
                } else {
                    algebra = [self parseModifyWithParsedVerb:@"INSERT" withErrors:errors];
                }
            } else if ([t.value isEqualToString: @"DELETE"]) {
                [self parseExpectedTokenOfType:KEYWORD withValue:@"DELETE" withErrors:errors];
                if ([errors count])
                    goto cleanup;
                SPKSPARQLToken* data    = [self parseOptionalTokenOfType:KEYWORD];
                if (data && [data.value isEqualToString:@"DATA"]) {
                    id<SPKTree> quads   = [self parseQuadDataWithErrors: errors];
                    for (id<SPKTree> t in quads.arguments) {
                        id<GTWStatement> st = t.value;
                        for (id<GTWTerm> term in [st allValues]) {
                            if ([term isKindOfClass:[GTWBlank class]]) {
                                [self errorMessage:@"DELETE DATA cannot contain blank nodes" withErrors:errors];
                                goto cleanup;
                            }
                        }
                    }
                    if ([errors count])
                        goto cleanup;
                    algebra = [[SPKTree alloc] initWithType:kAlgebraDeleteData arguments:quads.arguments];
                } else if (data && [data.value isEqualToString:@"WHERE"]) {
                    algebra = [self parseDelteWhereWithErrors:errors];
                } else {
                    algebra = [self parseModifyWithParsedVerb:@"DELETE" withErrors:errors];
                    id<SPKTree> template    = algebra.arguments[0];
                    for (id<SPKTree> t in template.arguments) {
                        id<GTWStatement> st = t.value;
                        for (id<GTWTerm> term in [st allValues]) {
                            if ([term isKindOfClass:[GTWBlank class]]) {
                                [self errorMessage:@"DELETE pattern cannot contain blank nodes" withErrors:errors];
                                goto cleanup;
                            }
                        }
                    }
                }
            } else {
                // TODO: implement ADD, MOVE, COPY, WITH...
                [self errorMessage:[NSString stringWithFormat:@"%@ not implemented yet", t.value] withErrors:errors];
                goto cleanup;
            }
            if ([errors count])
                goto cleanup;
        } else {
            [self errorMessage:[NSString stringWithFormat:@"expected query method not found: %@", t] withErrors:errors];
            goto cleanup;
        }
        
        algebra = [self parseValuesClauseForAlgebra:algebra withErrors:errors];
        if ([errors count])
            goto cleanup;
        
        t   = [self peekNextNonCommentToken];
        if (t) {
            if (updateOK && t.type == SEMICOLON) {
                [updateOperations addObject:algebra];
                [self parseExpectedTokenOfType:SEMICOLON withErrors:errors];
                ASSERT_EMPTY(errors);
                goto UPDATE_LOOP;
            }
            [self errorMessage:[NSString stringWithFormat: @"Found extra content after parsed query: %@", t] withErrors:errors];
            goto cleanup;
        }
    UPDATE_BREAK:
        if ([updateOperations count]) {
            [updateOperations addObject:algebra];
            [self checkForSharedBlanksInPatterns:updateOperations error:errors];
            ASSERT_EMPTY(errors);
            algebra = [[SPKTree alloc] initWithType:kAlgebraSequence arguments:updateOperations];
        } else if (!algebra) {
            if (updateOK) {
                // Empty update sequence
                algebra = [[SPKTree alloc] initWithType:kAlgebraSequence arguments:@[]];
            } else {
                [self errorMessage:[NSString stringWithFormat:@"expected query method but found EOF"] withErrors:errors];
                goto cleanup;
            }
        }
        [self endQueryScope];
    }
    return algebra;
    
cleanup:
    if (error) {
        *error  = [NSError errorWithDomain:@"us.kasei.sparql.query-parser" code:1 userInfo:@{@"description": [NSString stringWithFormat: @"Parse error: %@", errors]}];
    }
    return nil;
}

#pragma mark -

- (void) parsePrologueWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (YES) {
        if (t.type != KEYWORD)
            break;
        
        if ([t.value isEqualToString:@"PREFIX"]) {
            [self nextNonCommentToken];
            SPKSPARQLToken* name    = [self nextNonCommentToken];
            if ([name.args count] > 2 || ([name.args count] == 2 && ![[name.args objectAtIndex:1] isEqualToString: @""])) {
                [self errorMessage:[NSString stringWithFormat: @"Expecting PNAME_NS in PREFIX declaration, but found PNAME_LN %@", [name.args componentsJoinedByString:@":"]] withErrors:errors];
                return;
            }
            SPKSPARQLToken* iri     = [self nextNonCommentToken];
            if (name && iri) {
                [self.namespaces setValue:iri.value forKey:name.value];
            } else {
                [self errorMessage:[NSString stringWithFormat:@"Failed to parse PREFIX declaration (name: %@; iri: %@)", name, iri] withErrors:errors];
                return;
            }
        } else if ([t.value isEqualToString:@"BASE"]) {
            [self nextNonCommentToken];
            SPKSPARQLToken* iri     = [self nextNonCommentToken];
            if (iri) {
                self.baseIRI   = (id<GTWIRI>) [self tokenAsTerm:iri withErrors:errors];
            } else {
                [self errorMessage:@"Failed to parse BASE declaration" withErrors:errors];
                return;
            }
        } else {
            return;
        }
        
        t   = [self peekNextNonCommentToken];
    }
    return;
}

//[7]  	SelectQuery	  ::=  	SelectClause DatasetClause* WhereClause SolutionModifier
- (id<SPKTree>) parseSelectQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT" withErrors:errors];
    ASSERT_EMPTY(errors);
    NSUInteger distinct = 0;

    SPKSPARQLToken* t;
    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        // (DISTINCT | REDUCED)
        if ([t.value isEqualToString: @"DISTINCT"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        } else if ([t.value isEqualToString: @"REDUCED"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        }
    }
    
    //@@ ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*'
    NSMutableArray* project;
    t   = [self peekNextNonCommentToken];
    BOOL star   = NO;
    if (t.type == STAR) {
        star    = YES;
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        NSMutableSet* seenProjectionVars    = [NSMutableSet set];
        project = [NSMutableArray array];
        while (t.type == VAR || t.type == LPAREN) {
            if (t.type == VAR) {
                [self nextNonCommentToken];
                id<GTWTerm> term    = [self tokenAsTerm:t withErrors:errors];
                if ([seenProjectionVars containsObject:term]) {
                    return [self errorMessage:[NSString stringWithFormat:@"Attempt to project %@ multiple times", term] withErrors:errors];
                } else {
                    [seenProjectionVars addObject:term];
                }
                [project addObject:[[SPKTree alloc] initWithType:kTreeNode value:term arguments:nil]];
            } else if (t.type == LPAREN) {
                [self nextNonCommentToken];
                id<SPKTree> expr    = [self parseExpressionWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
                ASSERT_EMPTY(errors);
                id<SPKTree> var     = [self parseVarWithErrors: errors];
                id<GTWTerm> term    = var.value;
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:@[expr, var]];
                id<SPKTree> pvar    = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
                if ([seenProjectionVars containsObject:term]) {
                    return [self errorMessage:[NSString stringWithFormat:@"Attempt to project %@ multiple times", term] withErrors:errors];
                } else {
                    [seenProjectionVars addObject:term];
                }
                [project addObject:pvar];
            }
            t   = [self peekNextNonCommentToken];
        }
        if ([project count] == 0) {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting project list but found %@", t] withErrors:errors];
        }
    }
    
    
    // DatasetClause*
    id<SPKTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp)
        return nil;
    
    id<SPKTree> algebra = ggp;

    // SolutionModifier
    algebra = [self parseSolutionModifierForAlgebra:algebra withProjectionArray: project distinct:distinct withErrors:errors];
    ASSERT_EMPTY(errors);

    if (dataset) {
        algebra = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
    }
    
    if (star && [self currentQuerySeenAggregates]) {
        return [self errorMessage:@"SELECT * not legal with GROUP BY" withErrors:errors];
    }
    
    return algebra;
}

- (id<SPKTree>) rewriteTree: (id<SPKTree>) tree withAggregateMapping: (NSDictionary*) mapping withErrors: (NSMutableArray*) errors {
    if (!tree)
        return nil;
    if ([tree.type isEqual:kAlgebraExtend]) {
        id<SPKTree> tv          = tree.treeValue;
        id<SPKTree> expr        = [self rewriteTree:tv.arguments[0] withAggregateMapping:mapping withErrors:errors];
        GTWVariable* v          = [mapping objectForKey:expr];
        if (v) {
            id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
            id<SPKTree> pair    = [[SPKTree alloc] initWithType:kTreeList arguments:@[tn, tv.arguments[1]]];
            id<SPKTree> ext = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue:pair arguments:nil];
            return ext;
        }
    } else if ([mapping objectForKey:tree]) {
        GTWVariable* v          = [mapping objectForKey:tree];
        id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
        return tn;
    }
    
    NSMutableArray* args    = [NSMutableArray array];
    id<SPKTree> tv          = [self rewriteTree:tree.treeValue withAggregateMapping:mapping withErrors:errors];
    for (id t in tree.arguments) {
        id<SPKTree> newTree = [self rewriteTree:t withAggregateMapping:mapping withErrors:errors];
        [args addObject:newTree];
    }
    id<SPKTree> newt    = [[SPKTree alloc] initWithType:tree.type value:tree.value treeValue:tv arguments:args];
    return newt;
}

- (id<SPKTree>) rewriteAlgebra: (id<SPKTree>) algebra forProjection: (NSArray*) project withAggregateMapping: (NSDictionary*) mapping withErrors: (NSMutableArray*) errors {
    SPKTree* vlist;
    if ([mapping count]) {
        NSMutableArray* mappedProject  = [NSMutableArray array];
        for (id<SPKTree> tree in project) {
            id<SPKTree> t   = [self rewriteTree:tree withAggregateMapping:mapping withErrors:errors];
            ASSERT_EMPTY(errors);
            [mappedProject addObject:t];
        }
        vlist = [[SPKTree alloc] initWithType:kTreeList arguments:mappedProject];
    } else {
        vlist   = [[SPKTree alloc] initWithType:kTreeList arguments:project];
    }
    
    algebra = [[SPKTree alloc] initWithType:kAlgebraProject treeValue:vlist arguments:@[algebra]];
    algebra = [self algebraVerifyingProjectionAndGroupingInAlgebra: algebra withErrors:errors];
    ASSERT_EMPTY(errors);
    return algebra;
}

//        [10]  	ConstructQuery	  ::=  	'CONSTRUCT' ( ConstructTemplate DatasetClause* WhereClause SolutionModifier | DatasetClause* 'WHERE' '{' TriplesTemplate? '}' SolutionModifier )
- (id<SPKTree>) parseConstructQueryWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"CONSTRUCT" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LBRACE) {
        id<SPKTree> template    = [self parseConstructTemplateWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        id<SPKTree> dataset     = [self parseDatasetClausesWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp) {
            NSLog(@"-------------------");
        }
        id<SPKTree> algebra = [self parseSolutionModifierForAlgebra:ggp withProjectionArray: nil distinct:NO withErrors:errors];
        ASSERT_EMPTY(errors);
        
        if (dataset) {
            algebra = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
        }

        algebra     = [[SPKTree alloc] initWithType:kAlgebraConstruct arguments:@[template, algebra]];
        return algebra;
    } else {
        id<SPKTree> dataset = [self parseDatasetClausesWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> ggp         = [self parseConstructTemplateWithErrors: errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> template = [self parseSolutionModifierForAlgebra:ggp withProjectionArray: nil distinct:NO withErrors:errors];
        ASSERT_EMPTY(errors);
     
        id<SPKTree> algebra;
        if (dataset) {
            algebra = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[template]];
        } else {
            algebra = template;
        }

        algebra     = [[SPKTree alloc] initWithType:kAlgebraConstruct arguments:@[template, algebra]];
        return algebra;
    }
}

//[11]  	DescribeQuery	  ::=  	'DESCRIBE' ( VarOrIri+ | '*' ) DatasetClause* WhereClause? SolutionModifier
- (id<SPKTree>) parseDescribeQueryWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"DESCRIBE" withErrors:errors];
    ASSERT_EMPTY(errors);
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    BOOL star;
    NSMutableArray* vars    = [NSMutableArray array];
    if (t.type == STAR) {
        star    = YES;
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        star    = NO;
        while ([self tokenIsVarOrTerm:t]) {
            id<SPKTree> var = [self parseVarOrIRIWithErrors:errors];
            ASSERT_EMPTY(errors);
            [vars addObject:var];
            t   = [self peekNextNonCommentToken];
        }
    }

    // DatasetClause*
    id<SPKTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    SPKSPARQLToken* where   = [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<SPKTree> ggp;
    if (where) {
        ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
    } else {
        ggp = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    }
    
    id<SPKTree> algebra = ggp;
    // SolutionModifier
    algebra = [self parseSolutionModifierForAlgebra:algebra withProjectionArray: nil distinct:NO withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if (dataset) {
        algebra = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
    }
    
    if (star) {
        NSSet* set  = [algebra inScopeVariables];
        for (id<GTWTerm> t in set) {
            id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:t arguments:nil];
            [vars addObject:tn];
        }
    }
    id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:vars];
    return [[SPKTree alloc] initWithType:kAlgebraDescribe treeValue:list arguments:@[algebra]];
}

//[73]  	ConstructTemplate	  ::=  	'{' ConstructTriples? '}'
//[74]  	ConstructTriples	  ::=  	TriplesSameSubject ( '.' ConstructTriples? )?
- (id<SPKTree>) parseConstructTemplateWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);

    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == RBRACE) {
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        id<SPKTree> tmpl    = [self triplesByParsingTriplesBlockWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);

        id<SPKTree> triples = [self reduceTriplePaths:tmpl];
        return triples;
    }
}

- (id<SPKTree>) algebraVerifyingExtend: (id<SPKTree>) algebra withErrors: (NSMutableArray*) errors {
    if ([algebra.type isEqual:kAlgebraExtend]) {
        id<SPKTree> list    = algebra.treeValue;
        id<SPKTree> n       = list.arguments[1];
        id<GTWTerm> t       = n.value;
        id<SPKTree> suba    = list.arguments[0];
        NSSet* expScopeVars = [suba inScopeVariables];
        NSSet* patScopeVars = [algebra.arguments[0] inScopeVariables];
        NSMutableSet* scopeVars = [[expScopeVars setByAddingObjectsFromSet: patScopeVars] mutableCopy];
        if ([t conformsToProtocol:@protocol(GTWVariable)]) {
            if ([scopeVars containsObject:t]) {
                return [self errorMessage:[NSString stringWithFormat:@"Projecting already-in-scope variable %@ not allowed", t] withErrors:errors];
            }
        }
    }
    return algebra;
}

- (id<SPKTree>) algebraVerifyingProjection: (id<SPKTree>) algebra withErrors: (NSMutableArray*) errors {
    id<SPKTree> projectList = algebra.treeValue;
    NSArray* plist          = projectList.arguments;
    
    id<SPKTree> pattern     = algebra.arguments[0];
    NSSet* scopeVars        = [pattern inScopeVariables];
    for (id<SPKTree> v in plist) {
        if ([v.type isEqual:kAlgebraExtend]) {
            id<SPKTree> list    = v.treeValue;
            id<SPKTree> n   = list.arguments[1];
            id<GTWTerm> t   = n.value;
            if ([t conformsToProtocol:@protocol(GTWVariable)]) {
                if ([scopeVars containsObject:t]) {
                    return [self errorMessage:[NSString stringWithFormat:@"Projecting already-in-scope variable %@ not allowed", t] withErrors:errors];
                }
            }
        }
    }
    return algebra;
}

- (id<SPKTree>) algebraVerifyingProjectionAndGroupingInAlgebra: (id<SPKTree>) algebra withErrors: (NSMutableArray*) errors {
    id<SPKTree> projectList = algebra.treeValue;
    NSArray* plist          = projectList.arguments;
    
    algebra = [self algebraVerifyingProjection:algebra withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if ([self currentQuerySeenAggregates]) {
        NSSet* groupVars    = [(id)algebra projectableAggregateVariables];
        
        NSMutableSet* newProjection = [NSMutableSet set];
        for (id<SPKTree> v in plist) {
            if ([v.type isEqual:kTreeNode]) {
                id<GTWTerm> t   = v.value;
                if (![groupVars containsObject:t]) {
                    if (!([t isKindOfClass:[GTWVariable class]] && [t.value hasPrefix:@".agg"])) { // XXX this is a hack to recognize the fake variables (like ?.1) introduced by aggregation
                        if (![newProjection containsObject:t]) {
                            return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed (1)", t] withErrors:errors];
                        }
                    }
                }
            } else {
                NSSet* vars = [v nonAggregatedVariables];
                for (id<GTWTerm> t in vars) {
                    if (![groupVars containsObject:t]) {
                        if (!([t isKindOfClass:[GTWVariable class]] && [t.value hasPrefix:@".agg"])) { // XXX this is a hack to recognize the fake variables (like ?.1) introduced by aggregation
                            if (![newProjection containsObject:t]) {
                                return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed (2)", t] withErrors:errors];
                            }
                        }
                    }
                }
                if ([v.type isEqual:kAlgebraExtend]) {
                    id<SPKTree> list    = v.treeValue;
                    id<SPKTree> nt      = list.arguments[1];
                    id<GTWTerm> var     = nt.value;
                    [newProjection addObject:var];
                }
            }
        }
    }
    
    return algebra;
}

- (id<SPKTree>) parseAskQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"ASK" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    // DatasetClause*
    id<SPKTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp) {
        return nil;
    }
    
    if (dataset) {
        ggp = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[ggp]];
    }
    
    //@@ SolutionModifier
    return [[SPKTree alloc] initWithType:kAlgebraAsk arguments:@[ggp]];
}

//[13]  	DatasetClause	  ::=  	'FROM' ( DefaultGraphClause | NamedGraphClause )
//[14]  	DefaultGraphClause	  ::=  	SourceSelector
//[15]  	NamedGraphClause	  ::=  	'NAMED' SourceSelector
//[16]  	SourceSelector	  ::=  	iri
- (id<SPKTree>) parseDatasetClausesWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t       = [self parseOptionalTokenOfType:KEYWORD withValue:@"FROM"];
    NSMutableSet* namedSet  = [NSMutableSet set];
    NSMutableSet* defSet    = [NSMutableSet set];
    while (t) {
        SPKSPARQLToken* named   = [self parseOptionalTokenOfType:KEYWORD withValue:@"NAMED"];
        t   = [self nextNonCommentToken];
        id<GTWTerm> iri   = [self tokenAsTerm:t withErrors:errors];
        if (named) {
            [namedSet addObject:iri];
        } else {
            [defSet addObject:iri];
        }
        t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"FROM"];
    }
    
    NSUInteger count    = [namedSet count] + [defSet count];
    if (count == 0)
        return nil;
    
    id<SPKTree> namedTree   = [[SPKTree alloc] initWithType:kTreeSet value:namedSet arguments:nil];
    id<SPKTree> defTree     = [[SPKTree alloc] initWithType:kTreeSet value:defSet arguments:nil];
    id<SPKTree> pair        = [[SPKTree alloc] initWithType:kTreeList arguments:@[defTree, namedTree]];
    return pair;
}

//[53]  	GroupGraphPattern	  ::=  	'{' ( SubSelect | GroupGraphPatternSub ) '}'
- (id<SPKTree>) parseGroupGraphPatternWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    
    id<SPKTree> algebra;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString: @"SELECT"]) {
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

- (id<SPKTree>) reduceTriplePaths: (id<SPKTree>) paths {
    NSMutableArray* triples = [NSMutableArray array];
    for (id<SPKTree> t in paths.arguments) {
        if ([t.type isEqual:kTreeList]) {
            id<SPKTree> path    = t.arguments[1];
            if ([path.type isEqual:kTreeNode]) {
                id<SPKTree> subj    = t.arguments[0];
                id<SPKTree> obj    = t.arguments[2];
                id<GTWTriple> st    = [[GTWTriple alloc] initWithSubject:subj.value predicate:path.value object:obj.value];
                id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeTriple value:st arguments:nil];
                [triples addObject:triple];
            } else {
                id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreePath arguments:t.arguments];
                [triples addObject:triple];
            }
        } else {
            [triples addObject:t];
        }
    }
    return [[SPKTree alloc] initWithType:kAlgebraBGP arguments:triples];
}

//[8]  	SubSelect	  ::=  	SelectClause WhereClause SolutionModifier ValuesClause
- (id<SPKTree>) parseSubSelectWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT" withErrors:errors];
    ASSERT_EMPTY(errors);
    NSUInteger distinct = 0;
    [self beginQueryScope];
    
    SPKSPARQLToken* t;
    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        // (DISTINCT | REDUCED)
        if ([t.value isEqualToString: @"DISTINCT"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        } else if ([t.value isEqualToString: @"REDUCED"]) {
            [self nextNonCommentToken];
            distinct    = 1;
        }
    }
    
    //@@ ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*'
    NSMutableArray* project;
    t   = [self peekNextNonCommentToken];
    BOOL star   = NO;
    if (t.type == STAR) {
        star    = YES;
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        project = [NSMutableArray array];
        while (t.type == VAR || t.type == LPAREN) {
            if (t.type == VAR) {
                [self nextNonCommentToken];
                id<GTWTerm> term    = [self tokenAsTerm:t withErrors:errors];
                [project addObject:[[SPKTree alloc] initWithType:kTreeNode value:term arguments:nil]];
            } else if (t.type == LPAREN) {
                [self nextNonCommentToken];
                id<SPKTree> expr    = [self parseExpressionWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
                ASSERT_EMPTY(errors);
                id<SPKTree> var     = [self parseVarWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:@[expr, var]];
                id<SPKTree> pvar    = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
                [project addObject:pvar];
            }
            t   = [self peekNextNonCommentToken];
        }
    }
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp) {
        [self endQueryScope];
        return nil;
    }
    
    id<SPKTree> algebra = ggp;
    
    // SolutionModifier
    algebra = [self parseSolutionModifierForAlgebra:algebra withProjectionArray: project distinct:distinct withErrors:errors];
    
    // ValuesClause
    algebra = [self parseValuesClauseForAlgebra:algebra withErrors:errors];
    ASSERT_EMPTY(errors);

    
    
    
    if (star && [self currentQuerySeenAggregates]) {
        return [self errorMessage:@"SELECT * not legal with GROUP BY" withErrors:errors];
    }
    
    [self endQueryScope];
    return algebra;
}

//[20]  	GroupCondition	  ::=  	BuiltInCall | FunctionCall | '(' Expression ( 'AS' Var )? ')' | Var
- (id<SPKTree>) parseGroupConditionWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        
        id<SPKTree> cond;
        t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
            ASSERT_EMPTY(errors);
            id<SPKTree> var = [self parseVarOrTermWithErrors:errors];
            ASSERT_EMPTY(errors);
            id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:@[expr, var]];
            cond    = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
        } else {
            cond    = expr;
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return cond;
    } else if (t.type == VAR) {
        return [self parseVarOrTermWithErrors:errors];
    } else {
        return [self parseBuiltInCallWithErrors:errors];
    }
}

// [24]  	OrderCondition	  ::=  	 ( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( Constraint | Var )
- (id<SPKTree>) parseOrderConditionAscending: (BOOL*) ascending withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* asc = [self parseOptionalTokenOfType:KEYWORD withValue:@"ASC"];
    *ascending  = YES;
    BOOL forceBrackettedExpression = asc ? YES : NO;
    if (!asc) {
        SPKSPARQLToken* desc = [self parseOptionalTokenOfType:KEYWORD withValue:@"DESC"];
        if (desc) {
            forceBrackettedExpression   = YES;
            *ascending  = NO;
        }
    }
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (forceBrackettedExpression || t.type == LPAREN) {
        id<SPKTree> expr    = [self parseBrackettedExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else if (t.type == VAR) {
        return [self parseVarOrTermWithErrors:errors];
    } else {
        return [self parseConstraintWithErrors: errors];
    }
}

// [69]  	Constraint	  ::=  	BrackettedExpression | BuiltInCall | FunctionCall
- (id<SPKTree>) parseConstraintWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self parseBrackettedExpressionWithErrors:errors];
    } else if (t.type == IRI || t.type == PREFIXNAME) {
        return [self parseFunctionCallWithErrors:errors];
    } else {
        return [self parseBuiltInCallWithErrors:errors];
    }
}

//[70]  	FunctionCall	  ::=  	iri ArgList
- (id<SPKTree>) parseFunctionCallWithErrors: (NSMutableArray*) errors {
    id<SPKTree> func    = [self parseIRIOrFunctionWithErrors: errors];
    if (func.type != kExprFunction) {
        return [self errorMessage:[NSString stringWithFormat:@"Expected FunctionCall but found %@", func] withErrors:errors];
    }
    return func;
}

//[18]  	SolutionModifier	  ::=  	GroupClause? HavingClause? OrderClause? LimitOffsetClauses?
//[19]  	GroupClause	  ::=  	'GROUP' 'BY' GroupCondition+
//[21]  	HavingClause	  ::=  	'HAVING' HavingCondition+
//[22]  	HavingCondition	  ::=  	Constraint
//[23]  	OrderClause	  ::=  	'ORDER' 'BY' OrderCondition+
//[25]  	LimitOffsetClauses	  ::=  	LimitClause OffsetClause? | OffsetClause LimitClause?
//[26]  	LimitClause	  ::=  	'LIMIT' INTEGER
//[27]  	OffsetClause	  ::=  	'OFFSET' INTEGER
- (id<SPKTree>) parseSolutionModifierForAlgebra: (id<SPKTree>) algebra withProjectionArray: (NSArray*) project distinct: (BOOL) distinct withErrors: (NSMutableArray*) errors {
    NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
    SPKSPARQLToken* t;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"GROUP"];
    
    BOOL needGrouping   = NO;
    NSMutableArray* groupConditions   = [NSMutableArray array];
    if (t) {
        needGrouping    = YES;
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> cond;
        while ((cond = [self parseGroupConditionWithErrors:errors])) {
            ASSERT_EMPTY(errors);
            [groupConditions addObject:cond];
            [self.seenAggregates removeLastObject];
            [self.seenAggregates addObject:@(YES)];
        }
        ASSERT_EMPTY(errors);
    } else if ([self currentQuerySeenAggregates]) {
        needGrouping    = YES;
    }
    
    id<SPKTree> havingConstraint    = nil;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"HAVING"];
    if (t) {
        havingConstraint    = [self parseConstraintWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    id<SPKTree> orderList   = nil;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"ORDER"];
    if (t) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* conds   = [NSMutableArray array];
        id<SPKTree> cond;
        BOOL asc    = YES;
        while ((cond = [self parseOrderConditionAscending:&asc withErrors:errors])) {
            ASSERT_EMPTY(errors);
            [conds addObject:cond];
            [conds addObject:[[SPKTree alloc] initLeafWithType:kTreeNode value: [GTWLiteral integerLiteralWithValue:(asc ? 1 : -1)]]];
        }
        ASSERT_EMPTY(errors);
        orderList  = [[SPKTree alloc] initWithType:kTreeList arguments:conds];
    }

    
    id<SPKTree> groupingTree;
    if (needGrouping || [groupConditions count]) {
        NSSet* aggregates  = [self aggregatesForCurrentQuery];
        NSUInteger i    = 0;
        NSMutableArray* aggregateList   = [NSMutableArray array];
        for (id<SPKTree, NSCopying> agg in aggregates) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".agg%lu", i++]];
            mapping[agg]   = v;
            id<SPKTree> aggPair   = [[SPKTree alloc] initWithType:kTreeList value:v arguments:@[agg]];
            [aggregateList addObject:aggPair];
        }
        id<SPKTree> groupList   = [[SPKTree alloc] initWithType:kTreeList arguments:groupConditions];
        id<SPKTree> aggregateTree   = [[SPKTree alloc] initWithType:kTreeList arguments:aggregateList];
        groupingTree    = [[SPKTree alloc] initWithType:kTreeList arguments:@[groupList, aggregateTree]];
    }

    if (groupingTree) {
        algebra = [[SPKTree alloc] initWithType:kAlgebraGroup treeValue: groupingTree arguments:@[algebra]];
    }

    if (project) {
        NSSet* scopeVars    = [algebra inScopeVariables];
        NSMutableArray* nonExtends  = [NSMutableArray array];
        for (id<SPKTree> proj in project) {
            if ([proj.type isEqual:kAlgebraExtend]) {
                if ([self currentQuerySeenAggregates]) {
                    NSSet* nonAggVars   = [proj nonAggregatedVariables];
                    NSSet* groupVars    = [(id)algebra projectableAggregateVariables];
                    for (id<GTWTerm> var in nonAggVars) {
                        if (![groupVars containsObject:var]) {
                            return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed (3)", var] withErrors:errors];
                        }
                    }
                }
                proj.arguments  = @[algebra];
                algebra         = proj;
                id<SPKTree> var = proj.treeValue.arguments[1];
                if ([scopeVars containsObject:var.value]) {
                    return [self errorMessage:[NSString stringWithFormat:@"Projecting in-scope variable %@ not allowed", var.value] withErrors:errors];
                }
                proj.treeValue.arguments    = @[[self rewriteTree:proj.treeValue.arguments[0] withAggregateMapping:mapping withErrors:errors], var];
                ASSERT_EMPTY(errors);
                [nonExtends addObject:var];
            } else {
                [nonExtends addObject:proj];
            }
            project = nonExtends;
        }
    }
 
    if (havingConstraint) {
        NSMutableDictionary* treeMap    = [NSMutableDictionary dictionary];
        for (id<SPKTree,NSCopying> k in mapping) {
            id<GTWTerm> v   = mapping[k];
            id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
            treeMap[k]      = tn;
        }
        id<SPKTree> constraint  = [self rewriteTree:[havingConstraint copyReplacingValues:treeMap] withAggregateMapping:mapping withErrors:errors];
        ASSERT_EMPTY(errors);
        algebra = [[SPKTree alloc] initWithType:kAlgebraFilter treeValue: constraint arguments:@[algebra]];
    }
    
    if (orderList) {
        NSArray* list    = orderList.arguments;
        NSMutableArray* mappedList  = [NSMutableArray array];
        for (id<SPKTree> t in list) {
            GTWVariable* v  = [mapping objectForKey:t];
            if (v) {
                id<SPKTree> tn  = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
                [mappedList addObject:tn];
            } else {
                [mappedList addObject:t];
            }
        }
        id<SPKTree> mappedOrderList = [[SPKTree alloc] initWithType:kTreeList arguments:mappedList];
        algebra = [[SPKTree alloc] initWithType:kAlgebraOrderBy treeValue: mappedOrderList arguments:@[algebra]];
    }
    
    if (project) {
        algebra = [self rewriteAlgebra: algebra forProjection: project withAggregateMapping: mapping withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        NSSet* vars = [algebra inScopeVariables];
        NSMutableArray* project   = [NSMutableArray array];
        for (id<GTWTerm> v in vars) {
            [project addObject:[[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil]];
        }
        SPKTree* vlist  = [[SPKTree alloc] initWithType:kTreeList arguments:project];
        algebra = [[SPKTree alloc] initWithType:kAlgebraProject treeValue:vlist arguments:@[algebra]];
    }
    
    t   = [self peekNextNonCommentToken];
    if (t && t.type == KEYWORD) {
        id<GTWTerm> limit, offset;
        if ([t.value isEqualToString: @"LIMIT"]) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"LIMIT" withErrors:errors];
            ASSERT_EMPTY(errors);
            
            t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
            ASSERT_EMPTY(errors);
            limit    = (GTWLiteral*) [self tokenAsTerm:t withErrors:errors];
            
            t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"OFFSET"];
            if (t) {
                t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
                ASSERT_EMPTY(errors);
                offset    = (GTWLiteral*) [self tokenAsTerm:t withErrors:errors];
            }
        } else if ([t.value isEqualToString: @"OFFSET"]) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"OFFSET" withErrors:errors];
            ASSERT_EMPTY(errors);

            t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
            ASSERT_EMPTY(errors);
            offset    = (GTWLiteral*) [self tokenAsTerm:t withErrors:errors];
            
            t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"LIMIT"];
            if (t) {
                t   = [self parseExpectedTokenOfType:INTEGER withErrors:errors];
                ASSERT_EMPTY(errors);
                limit    = (GTWLiteral*) [self tokenAsTerm:t withErrors:errors];
            }
        }

        if (distinct) {
            algebra = [[SPKTree alloc] initWithType:kAlgebraDistinct arguments:@[algebra]];
        }
        
        if (limit || offset) {
            if (!limit)
                limit   = [[GTWLiteral alloc] initWithValue:@"-1" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            if (!offset)
                offset   = [[GTWLiteral alloc] initWithValue:@"0" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            algebra   = [[SPKTree alloc] initWithType:kAlgebraSlice arguments:@[
                          algebra,
                          [[SPKTree alloc] initLeafWithType:kTreeNode value: offset],
                          [[SPKTree alloc] initLeafWithType:kTreeNode value: limit],
                      ]];
        }
    } else {
        if (distinct) {
            algebra = [[SPKTree alloc] initWithType:kAlgebraDistinct arguments:@[algebra]];
        }
    }
    
    return algebra;
}

//[22]  	HavingCondition	  ::=  	Constraint
//[24]  	OrderCondition	  ::=  	 ( ( 'ASC' | 'DESC' ) BrackettedExpression )
//| ( Constraint | Var )


//[28]  	ValuesClause	  ::=  	( 'VALUES' DataBlock )?
- (id<SPKTree>) parseValuesClauseForAlgebra: (id<SPKTree>) algebra withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"VALUES"];
    if (t) {
        id<SPKTree> data    = [self parseDataBlockWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kAlgebraJoin arguments:@[algebra, data]];
    } else {
        return algebra;
    }
}

//[31]  	Load	  ::=  	'LOAD' 'SILENT'? iri ( 'INTO' GraphRef )?
- (SPKTree*) parseLoadWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"LOAD" withErrors:errors];
    ASSERT_EMPTY(errors);
    SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
    id<SPKTree> iri         = [self parseVarOrTermWithErrors:errors];
    ASSERT_EMPTY(errors);
    
    NSMutableArray* list    = [NSMutableArray array];
    id<GTWTerm> silentTerm  = silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral];
    id<SPKTree> silentTree  = [[SPKTree alloc] initWithType:kTreeNode value:silentTerm arguments:nil];
    [list addObject:silentTree];
    [list addObject:iri];
    
    SPKSPARQLToken* into   = [self parseOptionalTokenOfType:KEYWORD withValue:@"INTO"];
    if (into) {
//        NSLog(@"INTO named graph");
        [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> graph    = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        [list addObject:graph];
//    } else {
//        NSLog(@"INTO default graph");
    }
    id<SPKTree> data   = [[SPKTree alloc] initWithType:kTreeList arguments:list];
    return [[SPKTree alloc] initLeafWithType:kAlgebraLoad treeValue:data];
}

//[32]  	Clear	  ::=  	'CLEAR' 'SILENT'? GraphRefAll
//[33]  	Drop	  ::=  	'DROP' 'SILENT'? GraphRefAll
- (SPKTree*) parseClearOrDropWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self nextNonCommentToken];
    ASSERT_EMPTY(errors);
    SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
    
    NSMutableArray* list    = [NSMutableArray array];
    id<GTWTerm> silentTerm  = silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral];
    id<SPKTree> silentTree  = [[SPKTree alloc] initWithType:kTreeNode value:silentTerm arguments:nil];
    [list addObject:silentTree];
    
    // treeValue -> List(SilentFlagBooleanTerm, String(DEFAULT|NAMED|ALL|GRAPH), [iri])
    SPKSPARQLToken* token   = [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
    ASSERT_EMPTY(errors);
    
    id<SPKTree> opType  = [[SPKTree alloc] initWithType: kTreeString value:token.value arguments:nil];
    [list addObject:opType];
    
    if ([token.value isEqualToString: @"GRAPH"]) {
        id<SPKTree> graph    = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        [list addObject:graph];
    }
    
    SPKTreeType type;
    if ([t.value isEqualToString: @"CLEAR"]) {
        type    = kAlgebraClear;
    } else {
        type    = kAlgebraDrop;
    }
    id<SPKTree> data   = [[SPKTree alloc] initWithType:kTreeList arguments:list];
    return [[SPKTree alloc] initWithType:type treeValue:data arguments:nil];
}

//[34]  	Create	  ::=  	'CREATE' 'SILENT'? GraphRef
- (SPKTree*) parseCreateWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"CREATE" withErrors:errors];
    ASSERT_EMPTY(errors);

    SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
    
    [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> graph    = [self parseVarOrTermWithErrors:errors];
    ASSERT_EMPTY(errors);
    
    NSMutableArray* list    = [NSMutableArray array];
    id<GTWTerm> silentTerm  = silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral];
    id<SPKTree> silentTree  = [[SPKTree alloc] initWithType:kTreeNode value:silentTerm arguments:nil];
    [list addObject:silentTree];
    [list addObject:graph];
    id<SPKTree> data   = [[SPKTree alloc] initWithType:kTreeList arguments:list];
    return [[SPKTree alloc] initWithType:kAlgebraCreate treeValue:data arguments:nil];
}

//[35]  	Add	  ::=  	'ADD' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
- (SPKTree*) parseAddWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"ADD" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
    
    SPKSPARQLToken* t;
    id<SPKTree> src, dst;

    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString:@"DEFAULT"]) {
        // source is the default graph
        [self parseExpectedTokenOfType:KEYWORD withValue:@"DEFAULT" withErrors:errors];
        ASSERT_EMPTY(errors);
        src = [[SPKTree alloc] initWithType:kTreeString value:@"DEFAULT" arguments:nil];
    } else {
        // source is a named graph
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
            ASSERT_EMPTY(errors);
        }
        src = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"TO"];

    t    = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString:@"DEFAULT"]) {
        // source is the default graph
        [self parseExpectedTokenOfType:KEYWORD withValue:@"DEFAULT" withErrors:errors];
        ASSERT_EMPTY(errors);
        dst = [[SPKTree alloc] initWithType:kTreeString value:@"DEFAULT" arguments:nil];
    } else {
        // source is a named graph
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
            ASSERT_EMPTY(errors);
        }
        dst = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    NSMutableArray* list    = [NSMutableArray array];
    id<GTWTerm> silentTerm  = silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral];
    id<SPKTree> silentTree  = [[SPKTree alloc] initWithType:kTreeNode value:silentTerm arguments:nil];
    [list addObject:silentTree];
    [list addObject:src];
    [list addObject:dst];
    
    id<SPKTree> data   = [[SPKTree alloc] initWithType:kTreeList arguments:list];
    return [[SPKTree alloc] initWithType:kAlgebraAdd treeValue:data arguments:nil];
}

//[37]  	Copy	  ::=  	'COPY' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
- (SPKTree*) parseCopyWithErrors: (NSMutableArray*) errors {    // TODO: this is an identical production to ADD; merge the code, changing just the verb token and the algebra type that is produced
    [self parseExpectedTokenOfType:KEYWORD withValue:@"COPY" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
    
    SPKSPARQLToken* t;
    id<SPKTree> src, dst;
    
    t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString:@"DEFAULT"]) {
        // source is the default graph
        [self parseExpectedTokenOfType:KEYWORD withValue:@"DEFAULT" withErrors:errors];
        ASSERT_EMPTY(errors);
        src = [[SPKTree alloc] initWithType:kTreeString value:@"DEFAULT" arguments:nil];
    } else {
        // source is a named graph
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
            ASSERT_EMPTY(errors);
        }
        src = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"TO"];
    
    t    = [self peekNextNonCommentToken];
    if (t.type == KEYWORD && [t.value isEqualToString:@"DEFAULT"]) {
        // source is the default graph
        [self parseExpectedTokenOfType:KEYWORD withValue:@"DEFAULT" withErrors:errors];
        ASSERT_EMPTY(errors);
        dst = [[SPKTree alloc] initWithType:kTreeString value:@"DEFAULT" arguments:nil];
    } else {
        // source is a named graph
        if (t.type == KEYWORD) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
            ASSERT_EMPTY(errors);
        }
        dst = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    NSMutableArray* list    = [NSMutableArray array];
    id<GTWTerm> silentTerm  = silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral];
    id<SPKTree> silentTree  = [[SPKTree alloc] initWithType:kTreeNode value:silentTerm arguments:nil];
    [list addObject:silentTree];
    [list addObject:src];
    [list addObject:dst];
    
    id<SPKTree> data   = [[SPKTree alloc] initWithType:kTreeList arguments:list];
    return [[SPKTree alloc] initWithType:kAlgebraCopy treeValue:data arguments:nil];
}

//[40]  	DeleteWhere	  ::=  	'DELETE WHERE' QuadPattern
- (id<SPKTree>) parseDelteWhereWithErrors: (NSMutableArray*) errors {
    id<SPKTree> dclause = [self parseQuadPatternWithErrors: errors];
    NSLog(@"DELETE WHERE: %@", dclause);
    
    for (id<SPKTree> t in dclause.arguments) {
        id<GTWStatement> st = t.value;
        for (id<GTWTerm> term in [st allValues]) {
            if ([term isKindOfClass:[GTWBlank class]]) {
                return [self errorMessage:@"DELETE WHERE cannot contain blank nodes" withErrors:errors];
            }
        }
    }
    
    id<SPKTree> iclause = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    return [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dclause, iclause, dclause]];
}

//[41]  	Modify	  ::=  	( 'WITH' iri )? ( DeleteClause InsertClause? | InsertClause ) UsingClause* 'WHERE' GroupGraphPattern
//[42]  	DeleteClause	  ::=  	'DELETE' QuadPattern
//[43]  	InsertClause	  ::=  	'INSERT' QuadPattern
- (id<SPKTree>) parseModifyWithParsedVerb: (NSString*) verb withErrors: (NSMutableArray*) errors {
    id<SPKTree> graph   = nil;
    id<SPKTree> dclause     = nil;
    id<SPKTree> iclause     = nil;
    SPKSPARQLToken* delete;
    
    if (!verb) {
        SPKSPARQLToken* with    = [self parseOptionalTokenOfType:KEYWORD withValue:@"WITH"];
        if (with) {
            graph = [self parseVarOrTermWithErrors:errors];
        }
        delete  = [self parseOptionalTokenOfType:KEYWORD withValue:@"DELETE"];
    }
    
    if (delete || (verb && [verb isEqualToString:@"DELETE"])) {
        dclause = [self parseQuadPatternWithErrors: errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* insert  = [self parseOptionalTokenOfType:KEYWORD withValue:@"INSERT"];
        if (insert) {
            iclause = [self parseQuadPatternWithErrors: errors];
            ASSERT_EMPTY(errors);
        }
    } else {
        if (!(verb && [verb isEqualToString:@"INSERT"])) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"INSERT" withErrors:errors];
            ASSERT_EMPTY(errors);
        }
        iclause = [self parseQuadPatternWithErrors: errors];
        ASSERT_EMPTY(errors);
    }
    
    id<SPKTree> dataset = [self parseUsingClausesWithErrors:errors];
    ASSERT_EMPTY(errors);
    
    [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
    id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    
    if (!dclause)
        dclause = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    if (!iclause)
        iclause = [[SPKTree alloc] initWithType:kTreeList arguments:@[]];

    if (dataset) {
        ggp = [[SPKTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[ggp]];
    }

    return [[SPKTree alloc] initWithType:kAlgebraModify treeValue:nil arguments:@[dclause, iclause, ggp]];
}

//[44]  	UsingClause	  ::=  	'USING' ( iri | 'NAMED' iri )
// TODO: this is very close to the rules for datasets (parseDatasetClausesWithErrors:) with s/FROM/USING/; can the code be shared?
- (id<SPKTree>) parseUsingClausesWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t       = [self parseOptionalTokenOfType:KEYWORD withValue:@"USING"];
    NSMutableSet* namedSet  = [NSMutableSet set];
    NSMutableSet* defSet    = [NSMutableSet set];
    while (t) {
        SPKSPARQLToken* named   = [self parseOptionalTokenOfType:KEYWORD withValue:@"NAMED"];
        t   = [self nextNonCommentToken];
        id<GTWTerm> iri   = [self tokenAsTerm:t withErrors:errors];
        if (named) {
            [namedSet addObject:iri];
        } else {
            [defSet addObject:iri];
        }
        t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"USING"];
    }
    
    NSUInteger count    = [namedSet count] + [defSet count];
    if (count == 0)
        return nil;
    
    id<SPKTree> namedTree   = [[SPKTree alloc] initWithType:kTreeSet value:namedSet arguments:nil];
    id<SPKTree> defTree     = [[SPKTree alloc] initWithType:kTreeSet value:defSet arguments:nil];
    id<SPKTree> pair        = [[SPKTree alloc] initWithType:kTreeList arguments:@[defTree, namedTree]];
    return pair;
}

//[48]  	QuadPattern	  ::=  	'{' Quads '}'
- (id<SPKTree>) parseQuadPatternWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    NSArray* quads = [self parseQuadsWithErrors: errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    return [[SPKTree alloc] initWithType:kTreeList arguments:quads];
}

//[49]  	QuadData	  ::=  	'{' Quads '}'
- (id<SPKTree>) parseQuadDataWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    NSArray* quads = [self parseQuadsWithErrors: errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RBRACE withErrors:errors];
    ASSERT_EMPTY(errors);
    
    for (id<SPKTree> t in quads) {
        id<GTWStatement> st = t.value;
        if (![st isGround]) {
            return [self errorMessage:@"QuadData contains variables" withErrors:errors];
        }
    }
    return [[SPKTree alloc] initWithType:kTreeList arguments:quads];
}

//[50]  	Quads	  ::=  	TriplesTemplate? ( QuadsNotTriples '.'? TriplesTemplate? )*
//[51]  	QuadsNotTriples	  ::=  	'GRAPH' VarOrIri '{' TriplesTemplate? '}'
- (NSArray*) parseQuadsWithErrors: (NSMutableArray*) errors {
    NSMutableArray* statements  = [NSMutableArray array];
    NSArray* triples    = [self triplesByParsingTriplesTemplateWithErrors:errors];
    ASSERT_EMPTY(errors);

    if (triples) {
        id<SPKTree> tree        = [[SPKTree alloc] initWithType:kTreeList arguments:triples];
        id<SPKTree> reduced     = [self reduceTriplePaths:tree];
        triples                 = reduced.arguments;
        [statements addObjectsFromArray:triples];
    }

    while (YES) {
        // TODO: what's the stopping condition here?
        SPKSPARQLToken* t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD && [t.value isEqualToString:@"GRAPH"]) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"GRAPH" withErrors:errors];
            ASSERT_EMPTY(errors);
            id<SPKTree> graph   = [self parseVarOrIRIWithErrors:errors];
            ASSERT_EMPTY(errors);
            
            [self parseExpectedTokenOfType:LBRACE withErrors:errors];
            ASSERT_EMPTY(errors);
            
            NSArray* graphTriples    = [self triplesByParsingTriplesTemplateWithErrors:errors];
            ASSERT_EMPTY(errors);
            
            for (id<SPKTree> tree in graphTriples) {
                id<GTWTriple> t = tree.value;
                id<GTWQuad> q   = [GTWQuad quadFromTriple:t withGraph:graph.value];
                id<SPKTree> qt  = [[SPKTree alloc] initWithType:kTreeQuad value:q arguments:nil];
                [statements addObject:qt];
            }
            [self parseExpectedTokenOfType:RBRACE withErrors:errors];
            ASSERT_EMPTY(errors);
            
            [self parseOptionalTokenOfType:DOT];
            
            NSArray* triples    = [self triplesByParsingTriplesTemplateWithErrors:errors];
            ASSERT_EMPTY(errors);
            if (triples) {
                [statements addObjectsFromArray:triples];
            }
        } else {
            break;
        }
    }
    
    return statements;
}

//[52]  	TriplesTemplate	  ::=  	TriplesSameSubject ( '.' TriplesTemplate? )?
- (NSArray*) triplesByParsingTriplesTemplateWithErrors: (NSMutableArray*) errors {
    NSArray* triples   = [self triplesArrayByParsingTriplesSameSubjectWithErrors:errors];
    ASSERT_EMPTY(errors);
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (!t || t.type != DOT) {
        return triples;
    } else {
        [self parseExpectedTokenOfType:DOT withErrors:errors];
        ASSERT_EMPTY(errors);
        
        t   = [self peekNextNonCommentToken];
        // TODO: Check if TriplesBlock can be parsed (it's more than just tokenIsVarOrTerm:)
        if ([self tokenIsVarOrTerm:t] || NO) {
            NSArray* more    = [self triplesByParsingTriplesTemplateWithErrors:errors];
            ASSERT_EMPTY(errors);
            NSMutableArray* moreTriples    = [NSMutableArray arrayWithArray:triples];
            [moreTriples addObjectsFromArray:more];
            return moreTriples;
        } else {
            return triples;
        }
    }
}



// [54]  	GroupGraphPatternSub	  ::=  	TriplesBlock? ( GraphPatternNotTriples '.'? TriplesBlock? )*
- (id<SPKTree>) parseGroupGraphPatternSubWithError: (NSMutableArray*) errors {
    // TriplesBlock? ( GraphPatternNotTriples '.'? TriplesBlock? )*
    // VarOrTerm        |
    //                  '> GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
    //                     '{'                        'OPTIONAL'             'MINUS'             'GRAPH'             'SERVICE'             'FILTER' 'BIND' 'VALUES'
    NSMutableArray* args    = [NSMutableArray array];
    BOOL ok = YES;
    SPKSPARQLToken* t;
    BOOL allowTriplesBlock  = YES;
    while (ok) {
        t   = [self peekNextNonCommentToken];
        if (!t) {
            return [self errorMessage:@"Unexpected EOF in GroupGraphPatternSub" withErrors:errors];
        }
        SPKSPARQLTokenType type = t.type;
        
        id<SPKTree> algebra;
        if ([self tokenIsVarOrTerm:t]) {
            if (!allowTriplesBlock)
                break;
            algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
            allowTriplesBlock   = NO;
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
                    if (!allowTriplesBlock)
                        break;
                    algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
                    allowTriplesBlock   = NO;
                    ASSERT_EMPTY(errors);
                    if (algebra) {
                        [args addObject:[self reduceTriplePaths: algebra]];
                    }
                    break;
                case LBRACE:
                    algebra = [self treeByParsingGraphPatternNotTriplesWithError:errors];
                    allowTriplesBlock   = YES;
                    ASSERT_EMPTY(errors);
                    if (!algebra)
                        return [self errorMessage:@"Could not parse GraphPatternNotTriples in GroupGraphPatternSub (1)" withErrors:errors];
                    [args addObject:algebra];
                    [self parseOptionalTokenOfType:DOT];
                    break;
                case KEYWORD:
                    algebra = [self treeByParsingGraphPatternNotTriplesWithError:errors];
                    allowTriplesBlock   = YES;
                    ASSERT_EMPTY(errors);
                    if (!algebra)
                        return [self errorMessage:@"Could not parse GraphPatternNotTriples in GroupGraphPatternSub (2)" withErrors:errors];
                    [args addObject:algebra];
                    [self parseOptionalTokenOfType:DOT];
                    break;
                default:
                    ok  = NO;
            }
        }
    }
    
    NSArray* reordered    = [self reorderTrees:args errors:errors];
    ASSERT_EMPTY(errors);
    
    [self checkForSharedBlanksInPatterns:reordered error:errors];
    ASSERT_EMPTY(errors);
    
    return [[SPKTree alloc] initWithType:kTreeList arguments:reordered];
}

- (NSArray*) reorderTrees: (NSArray*) args errors:(NSMutableArray*) errors {
    NSMutableSet* FS    = [NSMutableSet set];
    id<SPKTree> G       = [[SPKTree alloc] initWithType:kAlgebraBGP arguments:@[]];
    
    for (id<SPKTree> E in args) {
        if ([E.type isEqual:kAlgebraFilter]) {
            [FS addObject:E];
        } else {
            if ([E.type isEqual:kAlgebraLeftJoin]) {
                id<SPKTree> A   = E.arguments[0];
                while ([A.type isEqual:kTreeList] && [A.arguments count] == 1) {
                    A   = A.arguments[0];
                }
                [self checkForSharedBlanksInPatterns:@[G, A] error:errors];
                ASSERT_EMPTY(errors);
                
                if ([A.type isEqual:kAlgebraFilter]) {
                    G   = [[SPKTree alloc] initWithType:kAlgebraLeftJoin treeValue:A.treeValue arguments:@[G, A.arguments[0]]];
                } else {
                    G   = [[SPKTree alloc] initWithType:kAlgebraLeftJoin treeValue:E.treeValue arguments:@[G, A]];
                }
            } else if ([E.type isEqual:kAlgebraMinus]) {
                G   = [[SPKTree alloc] initWithType:kAlgebraMinus arguments:@[G, E.arguments[0]]];
            } else if ([E.type isEqual:kAlgebraExtend]) {
                id<SPKTree> pair    = E.treeValue;
                id<SPKTree> algebra = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue:pair arguments:@[G]];
                G   = [self algebraVerifyingExtend:algebra withErrors:errors];
                ASSERT_EMPTY(errors);
            } else {
                if ([G.type isEqual:kAlgebraBGP] && [G.arguments count] == 0) {
                    G   = E;
                } else {
                    if ([G.type isEqual:kAlgebraBGP] && [E.type isEqual:kAlgebraBGP]) {
                        NSMutableArray* triples = [NSMutableArray arrayWithArray:G.arguments];
                        [triples addObjectsFromArray:E.arguments];
                        G   = [[SPKTree alloc] initWithType:kAlgebraBGP arguments:triples];
                    } else {
                        [self checkForSharedBlanksInPatterns:@[G, E] error:errors];
                        ASSERT_EMPTY(errors);
                        G   = [[SPKTree alloc] initWithType:kAlgebraJoin arguments:@[G, E]];
                    }
                }
            }
        }
    }
    
    if ([FS count]) {
        NSMutableArray* exprs   = [NSMutableArray array];
        for (id<SPKTree> e in FS) {
            [exprs addObject:e.treeValue];
        }
        id<SPKTree> conj    = [[SPKTree alloc] initWithType:kExprAnd arguments:exprs];
        G   = [[SPKTree alloc] initWithType:kAlgebraFilter treeValue: conj arguments:@[G]];
        G   = [self algebraVerifyingExtend:G withErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    return @[G];
}

- (BOOL) checkForSharedBlanksInPatterns: (NSArray*) args error: (NSMutableArray*) errors {
    NSMutableSet* seen  = [NSMutableSet set];
    for (id<SPKTree> p in args) {
        NSSet* blanks   = [p referencedBlanks];
        NSMutableSet* intersection  = [seen mutableCopy];
        [intersection intersectSet:blanks];
        if ([intersection count]) {
            [self errorMessage:[NSString stringWithFormat:@"Forbidden sharing of blank node(s) acorss BGPs: %@", intersection] withErrors:errors];
            return NO;
        }
        [seen addObjectsFromArray:[blanks allObjects]];
    }
    return YES;
}

//[60]  	Bind	  ::=  	'BIND' '(' Expression 'AS' Var ')'
- (id<SPKTree>) parseBindWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"BIND" withErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> var     = [self parseVarWithErrors: errors];
    ASSERT_EMPTY(errors);
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);

    id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeList arguments:@[expr, var]];
    id<SPKTree> bind    = [[SPKTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
    return bind;
}


//[61]  	InlineData	  ::=  	'VALUES' DataBlock
- (id<SPKTree>) parseInlineDataWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"VALUES" withErrors:errors];
    ASSERT_EMPTY(errors);
    return [self parseDataBlockWithErrors:errors];
}

//[62]  	DataBlock	  ::=  	InlineDataOneVar | InlineDataFull
//[63]  	InlineDataOneVar	  ::=  	Var '{' DataBlockValue* '}'
//[64]  	InlineDataFull	  ::=  	( NIL | '(' Var* ')' ) '{' ( '(' DataBlockValue* ')' | NIL )* '}'
- (id<SPKTree>) parseDataBlockWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == VAR) {
        // InlineDataOneVar
        id<SPKTree> var     = [self parseVarWithErrors: errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:LBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        NSArray* values = [self parseDataBlockValuesWithErrors: errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        
        NSMutableArray* results = [NSMutableArray array];
        for (id<SPKTree> value in values) {
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            id<SPKTree> key     = var;
            dict[key.value]     = value;
            id<SPKTree> result  = [[SPKTree alloc] initWithType:kTreeResult value:dict arguments:nil];
            [results addObject:result];
        }
        
        return [[SPKTree alloc] initWithType:kTreeResultSet arguments:results];
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
            SPKSPARQLToken* t   = [self peekNextNonCommentToken];
            NSMutableArray* v   = [NSMutableArray array];
            while (t.type == VAR) {
                id<SPKTree> var     = [self parseVarWithErrors: errors];
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
                id<SPKTree> key     = [vars objectAtIndex:i];
                id<SPKTree> value   = [values objectAtIndex:i];
                if (![value isKindOfClass:[NSNull class]]) {
                    dict[key.value]   = value;
                }
            }
            id<SPKTree> result  = [[SPKTree alloc] initWithType:kTreeResult value:dict arguments:nil];
            [results addObject:result];
        }
        
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        
        return [[SPKTree alloc] initWithType:kTreeResultSet arguments:results];
    }
    return nil;
}

//[65]  	DataBlockValue	  ::=  	iri |	RDFLiteral |	NumericLiteral |	BooleanLiteral |	'UNDEF'
- (NSArray*) parseDataBlockValuesWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    NSMutableArray* values  = [NSMutableArray array];
    while ([self tokenIsTerm:t] || (t.type == KEYWORD && [t.value isEqualToString: @"UNDEF"])) {
        if (t.type == KEYWORD && [t.value isEqualToString: @"UNDEF"]) {
            [self nextNonCommentToken];
            [values addObject:[NSNull null]];
        } else {
            [self nextNonCommentToken];
            id<GTWTerm> term   = [self tokenAsTerm:t withErrors:errors];
            id<SPKTree> data    = [[SPKTree alloc] initWithType:kTreeNode value:term arguments:nil];
            ASSERT_EMPTY(errors);
            [values addObject:data];
        }
        t   = [self peekNextNonCommentToken];
    }
    return values;
}


//[75]  	TriplesSameSubject	  ::=  	VarOrTerm PropertyListNotEmpty |	TriplesNode PropertyList
- (NSArray*) triplesArrayByParsingTriplesSameSubjectWithErrors: (NSMutableArray*) errors {
    NSMutableArray* triples = [NSMutableArray array];
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    id<SPKTree> node    = nil;
    if ([self tokenIsVarOrTerm:t]) {
        id<SPKTree> subject = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> propertyObjectTriples = [self parsePropertyListNotEmptyForSubject:subject withErrors:errors];
        if (!propertyObjectTriples)
            return nil;
        [triples addObjectsFromArray:propertyObjectTriples.arguments];
        return triples;
    } else if (t.type == LPAREN || t.type == LBRACKET) {
        id<SPKTree> nodetriples = [self parseTriplesNodeAsNode: &node withErrors:errors];
        for (id<SPKTree> t in nodetriples.arguments) {
            [triples addObject:t];
        }
        id<SPKTree> propertyObjectTriples = [self parsePropertyListForSubject:node withErrors:errors];
        if (propertyObjectTriples) {
            [triples addObjectsFromArray:propertyObjectTriples.arguments];
        }
        return triples;
    }
    return @[];
}

//[76]  	PropertyList	  ::=  	PropertyListNotEmpty?
- (id<SPKTree>) parsePropertyListForSubject: (id<SPKTree>) subject withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVerb:t]) {
        return [self parsePropertyListNotEmptyForSubject: subject withErrors:errors];
    } else {
        return nil;
    }
}

//[77]  	PropertyListNotEmpty	  ::=  	Verb ObjectList ( ';' ( Verb ObjectList )? )*
- (id<SPKTree>)parsePropertyListNotEmptyForSubject: (id<SPKTree>) subject withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (![self tokenIsVarOrTerm:t]) {
        return [self errorMessage:[NSString stringWithFormat:@"Expecting Verb but found %@", t] withErrors:errors];
    }
    [self nextNonCommentToken];
    id<GTWTerm> v    = [self tokenAsTerm:t withErrors:errors];
    ASSERT_EMPTY(errors);
    if (t.type != VAR) {
        // make sure the token is an IRI
        if (![v isKindOfClass:[GTWIRI class]]) {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting IRI Verb but found %@", v] withErrors:errors];
        }
    }
    id<SPKTree> verb    = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
    
    NSArray* objectList;
    id<SPKTree> triples = [self parseObjectListAsNodes:&objectList withErrors:errors];
    NSMutableArray* propertyObjects = [NSMutableArray arrayWithArray:triples.arguments];
    for (id o in objectList) {
        id<GTWTriple> t    = [[GTWTriple alloc] initWithSubject:subject.value predicate:verb.value object:o];
        id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
        [propertyObjects addObject:triple];
    }
    
    t   = [self peekNextNonCommentToken];
    while (t && t.type == SEMICOLON) {
        [self parseExpectedTokenOfType:SEMICOLON withErrors:errors];
        ASSERT_EMPTY(errors);
        t   = [self peekNextNonCommentToken];
        if (!(t.type == IRI || t.type == PREFIXNAME || (t.type == KEYWORD && [t.value isEqual: @"A"]))) {
            break;
        }
        
        if (![self tokenIsVarOrTerm:t]) {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting Verb but found %@", t] withErrors:errors];
        }
        [self nextNonCommentToken];
        id<GTWTerm> v       = [self tokenAsTerm:t withErrors:errors];
        id<SPKTree> verb    = [[SPKTree alloc] initWithType:kTreeNode value:v arguments:nil];
        
        NSArray* objectList;
        id<SPKTree> triples = [self parseObjectListAsNodes:&objectList withErrors:errors];
        [propertyObjects addObjectsFromArray:triples.arguments];
        for (id o in objectList) {
            id<GTWTriple> t    = [[GTWTriple alloc] initWithSubject:subject.value predicate:verb.value object:o];
            id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeTriple value:t arguments:nil];
            [propertyObjects addObject:triple];
        }
        t   = [self peekNextNonCommentToken];
    }
    
    return [[SPKTree alloc] initWithType:kTreeList arguments:propertyObjects];
}


// Returns an NSArray of triples. Each item in the array is a kTreeList with three items, a subject term, an path (with a path tree type), and an object term.
// TriplesSameSubjectPath	  ::=  	VarOrTerm PropertyListPathNotEmpty |	TriplesNodePath PropertyListPath
- (NSArray*) triplesArrayByParsingTriplesSameSubjectPathWithErrors: (NSMutableArray*) errors {
    NSMutableArray* triples = [NSMutableArray array];
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    id<SPKTree> node    = nil;
    if ([self tokenIsVarOrTerm:t]) {
        id<SPKTree> subject = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> propertyObjectTriples = [self parsePropertyListPathNotEmptyForSubject:subject withErrors:errors];
        if (!propertyObjectTriples)
            return nil;
        [triples addObjectsFromArray:propertyObjectTriples.arguments];
        return triples;
    } else {
        id<SPKTree> nodetriples = [self parseTriplesNodePathAsNode: &node withErrors:errors];
        for (id<SPKTree> t in nodetriples.arguments) {
            [triples addObject:t];
        }
        id<SPKTree> propertyObjectTriples = [self parsePropertyListPathForSubject:node withErrors:errors];
        if (propertyObjectTriples) {
            [triples addObjectsFromArray:propertyObjectTriples.arguments];
        }
        return triples;
    }
}

// [72]  	ExpressionList	  ::=  	NIL | '(' Expression ( ',' Expression )* ')'
- (id<SPKTree>) parseExpressionListWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == NIL) {
        [self nextNonCommentToken];
        return [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* list    = [NSMutableArray arrayWithObject:expr];
        t   = [self peekNextNonCommentToken];
        while (t.type == COMMA) {
            [self nextNonCommentToken];
            id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            [list addObject:expr];
            t   = [self peekNextNonCommentToken];
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kTreeList arguments:list];
    }
}

// [78]  	Verb	  ::=  	VarOrIri | 'a'
- (id<SPKTree>) parseVerbWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        t   = [self parseExpectedTokenOfType:KEYWORD withValue:@"A" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTerm> term   = [self tokenAsTerm:t withErrors:errors];
        return [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else {
        return [self parseVarOrIRIWithErrors:errors];
    }
}

//[79]  	ObjectList	  ::=  	Object ( ',' Object )*
- (id<SPKTree>) parseObjectListAsNodes: (NSArray**) nodes withErrors: (NSMutableArray*) errors {
    id<SPKTree> node        = nil;
    id<SPKTree> triplesTree = [self parseObjectAsNode:&node withErrors:errors];
    ASSERT_EMPTY(errors);
    
    NSMutableArray* triples = [NSMutableArray arrayWithArray:triplesTree.arguments];
    NSMutableArray* objects = [NSMutableArray arrayWithObject:node.value];
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == COMMA) {
        [self nextNonCommentToken];
        
        id<SPKTree> triplesTree     = [self parseObjectAsNode:&node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:triplesTree.arguments];
        [objects addObject:node.value];
        t   = [self peekNextNonCommentToken];
    }
    
    *nodes  = objects;
    return [[SPKTree alloc] initWithType:kTreeList arguments:triples];
}

//[80]  	Object	  ::=  	GraphNode
- (id<SPKTree>) parseObjectAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    return [self parseGraphNodeAsNode:node withErrors:errors];
}

// [82]  	PropertyListPath	  ::=  	PropertyListPathNotEmpty?
- (id<SPKTree>) parsePropertyListPathForSubject: (id<SPKTree>) subject withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVerb:t]) {
        return [self parsePropertyListPathNotEmptyForSubject: subject withErrors:errors];
    } else {
        return nil;
    }
}

// [83]  	PropertyListPathNotEmpty	  ::=  	( VerbPath | VerbSimple ) ObjectListPath ( ';' ( ( VerbPath | VerbSimple ) ObjectList )? )*
- (id<SPKTree>) parsePropertyListPathNotEmptyForSubject: (id<SPKTree>) subject withErrors: (NSMutableArray*) errors {
    id<SPKTree> verb    = nil;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
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
    id<SPKTree> triples = [self parseObjectListPathAsNodes:&objectList withErrors:errors];
    NSMutableArray* propertyObjects = [NSMutableArray arrayWithArray:triples.arguments];
    for (id o in objectList) {
        id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeList arguments:@[ subject, verb, o ]];
        [propertyObjects addObject:triple];
    }
    
    t   = [self peekNextNonCommentToken];
    while (t && t.type == SEMICOLON) {
        [self parseExpectedTokenOfType:SEMICOLON withErrors:errors];
        ASSERT_EMPTY(errors);
        t   = [self peekNextNonCommentToken];
        id<SPKTree> verb    = nil;
        if (t.type == VAR) {    // VerbSimple
            verb    = [self parseVerbSimpleWithErrors:errors];
            ASSERT_EMPTY(errors);
        } else if ((t.type == KEYWORD && [t.value isEqualToString:@"A"]) || t.type == LPAREN || t.type == HAT || t.type == BANG || t.type == IRI || t.type == PREFIXNAME) {
            // iri | 'a' | '!' PathNegatedPropertySet | '(' Path ')'
            verb    = [self parseVerbPathWithErrors:errors];
            ASSERT_EMPTY(errors);
        } else {
            break;
        }
        
        NSArray* objectList;
        id<SPKTree> triples = [self parseObjectListPathAsNodes:&objectList withErrors:errors];
        [propertyObjects addObjectsFromArray:triples.arguments];
        for (id o in objectList) {
            id<SPKTree> triple  = [[SPKTree alloc] initWithType:kTreeList arguments:@[ subject, verb, o ]];
            [propertyObjects addObject:triple];
        }
        t   = [self peekNextNonCommentToken];
    }
    
    return [[SPKTree alloc] initWithType:kTreeList arguments:propertyObjects];
}

// [84]  	VerbPath	  ::=  	Path
- (id<SPKTree>) parseVerbPathWithErrors: (NSMutableArray*) errors {
    return [self parsePathWithErrors:errors];
}

// [85]  	VerbSimple	  ::=  	Var
- (id<SPKTree>) parseVerbSimpleWithErrors: (NSMutableArray*) errors {
    return [self parseVarWithErrors:errors];
}

// [86]  	ObjectListPath	  ::=  	ObjectPath ( ',' ObjectPath )*
- (id<SPKTree>) parseObjectListPathAsNodes: (NSArray**) nodes withErrors: (NSMutableArray*) errors {
    id<SPKTree> node    = nil;
    id<SPKTree> triplesTree     = [self parseObjectPathAsNode:&node withErrors:errors];
    ASSERT_EMPTY(errors);
    
    NSMutableArray* triples     = [NSMutableArray arrayWithArray:triplesTree.arguments];
    NSMutableArray* objects = [NSMutableArray arrayWithObject:node];
    
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == COMMA) {
        [self nextNonCommentToken];

        id<SPKTree> triplesTree     = [self parseObjectPathAsNode:&node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:triplesTree.arguments];
        [objects addObject:node];
        t   = [self peekNextNonCommentToken];
    }
   
    *nodes  = objects;
    return [[SPKTree alloc] initWithType:kTreeList arguments:triples];
}

// [88]  	Path	  ::=  	PathAlternative
- (id<SPKTree>) parsePathWithErrors: (NSMutableArray*) errors {
    return [self parsePathAlternativeWithErrors:errors];
}

// [87]  	ObjectPath	  ::=  	GraphNodePath
- (id<SPKTree>) parseObjectPathAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    return [self parseGraphNodePathAsNode:node withErrors:errors];
}

// [89]  	PathAlternative	  ::=  	PathSequence ( '|' PathSequence )*
- (id<SPKTree>) parsePathAlternativeWithErrors: (NSMutableArray*) errors {
    id<SPKTree> path    = [self parsePathSequenceWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!path)
        return nil;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == OR) {
        [self nextNonCommentToken];
        id<SPKTree> pathAlt    = [self parsePathSequenceWithErrors:errors];
        ASSERT_EMPTY(errors);
        path    = [[SPKTree alloc] initWithType:kPathOr arguments:@[path, pathAlt]];
        t   = [self peekNextNonCommentToken];
    }
    return path;
}

// [90]  	PathSequence	  ::=  	PathEltOrInverse ( '/' PathEltOrInverse )*
- (id<SPKTree>) parsePathSequenceWithErrors: (NSMutableArray*) errors {
    id<SPKTree> path    = [self parsePathEltOrInverseWithErrors: errors];
    ASSERT_EMPTY(errors);
    if (!path)
        return nil;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == SLASH) {
        [self nextNonCommentToken];
        id<SPKTree> pathSeq    = [self parsePathEltOrInverseWithErrors:errors];
        ASSERT_EMPTY(errors);
        path    = [[SPKTree alloc] initWithType:kPathSequence arguments:@[path, pathSeq]];
        t   = [self peekNextNonCommentToken];
    }
    return path;
}

// [91]  	PathElt	  ::=  	PathPrimary PathMod?
// [93]  	PathMod	  ::=  	'?' | '*' | '+'
- (id<SPKTree>) parsePathEltWithErrors: (NSMutableArray*) errors {
    id<SPKTree> elt = [self parsePathPrimaryWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!elt)
        return nil;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == QUESTION) {
        [self nextNonCommentToken];
        return [[SPKTree alloc] initWithType:kPathZeroOrOne arguments:@[elt]];
    } else if (t.type == STAR) {
        [self nextNonCommentToken];
        return [[SPKTree alloc] initWithType:kPathZeroOrMore arguments:@[elt]];
    } else if (t.type == PLUS) {
        [self nextNonCommentToken];
        return [[SPKTree alloc] initWithType:kPathOneOrMore arguments:@[elt]];
    } else {
        return elt;
    }
}

// [92]  	PathEltOrInverse	  ::=  	PathElt | '^' PathElt
- (id<SPKTree>) parsePathEltOrInverseWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == HAT) {
        [self nextNonCommentToken];
        id<SPKTree> path    = [self parsePathEltWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kPathInverse arguments:@[path]];
    } else {
        id<SPKTree> path    = [self parsePathEltWithErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    }
}

// [94]  	PathPrimary	  ::=  	iri | 'a' | '!' PathNegatedPropertySet | '(' Path ')'
- (id<SPKTree>) parsePathPrimaryWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> path    = [self parsePathWithErrors:errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    } else if (t.type == KEYWORD && [t.value isEqualToString: @"A"]) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"A" withErrors:errors];
        id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else if (t.type == BANG) {
        [self parseExpectedTokenOfType:BANG withErrors:errors];
        id<SPKTree> path    = [self parsePathNegatedPropertySetWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kPathNegate arguments:@[path]];
    } else {
        id<SPKTree> path    = [self parseIRIWithErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    }
}

// [95]  	PathNegatedPropertySet	  ::=  	PathOneInPropertySet | '(' ( PathOneInPropertySet ( '|' PathOneInPropertySet )* )? ')'
- (id<SPKTree>) parsePathNegatedPropertySetWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> path    = [self parsePathOneInPropertySetWithErrors:errors];
        t   = [self peekNextNonCommentToken];
        
        // TODO: is this really optional? what sort of a path is '(' ')' ?
        while (t && t.type == OR) {
            [self nextNonCommentToken];
            id<SPKTree> rhs = [self parsePathOneInPropertySetWithErrors:errors];
            ASSERT_EMPTY(errors);
            path            = [[SPKTree alloc] initWithType:kPathOr arguments:@[path, rhs]];
            t   = [self peekNextNonCommentToken];
        }
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        return path;
    } else {
        id<SPKTree> set = [self parsePathOneInPropertySetWithErrors:errors];
        ASSERT_EMPTY(errors);
        return set;
    }
}

// [96]  	PathOneInPropertySet	  ::=  	iri | 'a' | '^' ( iri | 'a' )
- (id<SPKTree>) parsePathOneInPropertySetWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == HAT) {
        [self nextNonCommentToken];
        t   = [self peekNextNonCommentToken];
        if (t.type == KEYWORD && [t.value isEqualToString: @"A"]) {
            [self nextNonCommentToken];
            id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            id<SPKTree> path    = [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
            return [[SPKTree alloc] initWithType:kPathInverse arguments:@[path]];
        } else {
            id<SPKTree> path    = [self parseIRIWithErrors: errors];
            return [[SPKTree alloc] initWithType:kPathInverse arguments:@[path]];
        }
    } else if (t.type == KEYWORD && [t.value isEqualToString: @"A"]) {
        [self nextNonCommentToken];
        id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else {
        return [self parseIRIWithErrors: errors];
    }
}

//[98]  	TriplesNode	  ::=  	Collection |	BlankNodePropertyList
- (id<SPKTree>) parseTriplesNodeAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self triplesByParsingCollectionAsNode: (id<SPKTree>*) node withErrors: errors];
    } else {
        return [self parseBlankNodePropertyListAsNode:node withErrors:errors];
    }
}

//[99]  	BlankNodePropertyList	  ::=  	'[' PropertyListNotEmpty ']'
- (id<SPKTree>) parseBlankNodePropertyListAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWBlank* subj  = self.bnodeIDGenerator(nil);
    *node   = [[SPKTree alloc] initWithType:kTreeNode value: subj arguments:nil];
    id<SPKTree> path    = [self parsePropertyListNotEmptyForSubject:*node withErrors:errors];
    [self parseExpectedTokenOfType:RBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    return path;
}

// [100]  	TriplesNodePath	  ::=  	CollectionPath |	BlankNodePropertyListPath
- (id<SPKTree>) parseTriplesNodePathAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self triplesByParsingCollectionPathAsNode: (id<SPKTree>*) node withErrors: errors];
    } else {
        return [self parseBlankNodePropertyListPathAsNode:node withErrors:errors];
    }
}

// [101]  	BlankNodePropertyListPath	  ::=  	'[' PropertyListPathNotEmpty ']'
- (id<SPKTree>) parseBlankNodePropertyListPathAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWBlank* subj  = self.bnodeIDGenerator(nil);
    *node   = [[SPKTree alloc] initWithType:kTreeNode value: subj arguments:nil];
    id<SPKTree> path    = [self parsePropertyListPathNotEmptyForSubject:*node withErrors:errors];
    [self parseExpectedTokenOfType:RBRACKET withErrors:errors];
    ASSERT_EMPTY(errors);
    return path;
}


//[102]  	Collection	  ::=  	'(' GraphNode+ ')'
- (id<SPKTree>) triplesByParsingCollectionAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> graphNodePath    = [self parseGraphNodeAsNode:node withErrors:errors];
    ASSERT_EMPTY(errors);
    NSMutableArray* triples = [NSMutableArray arrayWithArray:graphNodePath.arguments];
    if (!(*node)) {
        NSLog(@"no node in collection path");
    }
    NSMutableArray* nodes   = [NSMutableArray arrayWithObject:*node];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type != RPAREN) {
        id<SPKTree> graphNode    = [self parseGraphNodeAsNode:node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:graphNode.arguments];
        [nodes addObject:*node];
        t   = [self peekNextNonCommentToken];
    }
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    
    
    GTWBlank* bnode  = self.bnodeIDGenerator(nil);
    id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeNode value: bnode arguments:nil];
    *node   = list;
    
    
    GTWIRI* rdffirst    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rdfrest    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
    GTWIRI* rdfnil    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"];
    
    if ([nodes count]) {
        for (NSUInteger i = 0; i < [nodes count]; i++) {
            id<SPKTree> o   = [nodes objectAtIndex:i];
            GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:o.value];
            id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
            if (!ttree) {
                return [self errorMessage:@"(1) no triple tree" withErrors:errors];
            }
            [triples addObject:ttree];
            if (i == [nodes count]-1) {
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:rdfnil];
                id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(2) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
            } else {
                GTWBlank* newbnode  = self.bnodeIDGenerator(nil);
                id<SPKTree> newlist = [[SPKTree alloc] initWithType:kTreeNode value: newbnode arguments:nil];
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:newlist.value];
                id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(3) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
                list    = newlist;
            }
        }
    } else {
        GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:rdfnil];
        id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
        if (!ttree) {
            return [self errorMessage:@"(4) no triple tree" withErrors:errors];
        }
        [triples addObject:ttree];
    }
    
    return [[SPKTree alloc] initWithType:kTreeList arguments:triples];
}

// [103]  	CollectionPath	  ::=  	'(' GraphNodePath+ ')'
- (id<SPKTree>) triplesByParsingCollectionPathAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> graphNodePath    = [self parseGraphNodePathAsNode:node withErrors:errors];
    ASSERT_EMPTY(errors);
    NSMutableArray* triples = [NSMutableArray arrayWithArray:graphNodePath.arguments];
    if (!(*node)) {
        NSLog(@"no node in collection path");
    }
    NSMutableArray* nodes   = [NSMutableArray arrayWithObject:*node];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type != RPAREN) {
        id<SPKTree> graphNodePath    = [self parseGraphNodePathAsNode:node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:graphNodePath.arguments];
        [nodes addObject:*node];
        t   = [self peekNextNonCommentToken];
    }
    [self parseExpectedTokenOfType:RPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    
    
    GTWBlank* bnode  = self.bnodeIDGenerator(nil);
    id<SPKTree> list    = [[SPKTree alloc] initWithType:kTreeNode value: bnode arguments:nil];
    *node   = list;
    
    
    GTWIRI* rdffirst    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#first"];
    GTWIRI* rdfrest    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"];
    GTWIRI* rdfnil    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"];
    
    if ([nodes count]) {
        for (NSUInteger i = 0; i < [nodes count]; i++) {
            id<SPKTree> o   = [nodes objectAtIndex:i];
            GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:o.value];
            id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
            if (!ttree) {
                return [self errorMessage:@"(1) no triple tree" withErrors:errors];
            }
            [triples addObject:ttree];
            if (i == [nodes count]-1) {
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:rdfnil];
                id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(2) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
            } else {
                GTWBlank* newbnode  = self.bnodeIDGenerator(nil);
                id<SPKTree> newlist = [[SPKTree alloc] initWithType:kTreeNode value: newbnode arguments:nil];
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:newlist.value];
                id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(3) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
                list    = newlist;
            }
        }
    } else {
        GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:rdfnil];
        id<SPKTree> ttree   = [[SPKTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
        if (!ttree) {
            return [self errorMessage:@"(4) no triple tree" withErrors:errors];
        }
        [triples addObject:ttree];
    }
    
    return [[SPKTree alloc] initWithType:kTreeList arguments:triples];
}


//[104]  	GraphNode	  ::=  	VarOrTerm |	TriplesNode
- (id<SPKTree>) parseGraphNodeAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVarOrTerm:t]) {
        *node   = [self parseVarOrTermWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        return [self parseTriplesNodeAsNode:node withErrors:errors];
    }
}



// [105]  	GraphNodePath	  ::=  	VarOrTerm |	TriplesNodePath
- (id<SPKTree>) parseGraphNodePathAsNode: (id<SPKTree>*) node withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVarOrTerm:t]) {
        *node   = [self parseVarOrTermWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        return [self parseTriplesNodePathAsNode:node withErrors:errors];
    }
}

// [106]  	VarOrTerm	  ::=  	Var | GraphTerm
- (BOOL) tokenIsTerm: (SPKSPARQLToken*) t {
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
    if (t.type == VAR)
        return YES;
    
    return NO;
}

- (BOOL) tokenIsVarOrTerm: (SPKSPARQLToken*) t {
    if ([self tokenIsTerm:t])
        return YES;
    if (t.type == VAR)
        return YES;
    if (t.type == KEYWORD && [t.value isEqualToString:@"A"])
        return YES;
    return NO;
}

- (BOOL) tokenIsVerb: (SPKSPARQLToken*) t {
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

- (id<SPKTree>) parseVarOrTermWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    return [[SPKTree alloc] initWithType:kTreeNode value:t arguments:nil];
}

// [107]  	VarOrIri	  ::=  	Var | iri
- (id<SPKTree>) parseVarOrIRIWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWTermType type    = [t termType];
    if (type == GTWTermVariable || type == GTWTermIRI) {
        return [[SPKTree alloc] initWithType:kTreeNode value: t arguments:nil];
    } else {
        return [self errorMessage:[NSString stringWithFormat:@"Expected Var or IRI, but found %@", t] withErrors:errors];
    }
}

// [108]  	Var	  ::=  	VAR1 | VAR2
- (id<SPKTree>) parseVarWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    
    GTWTermType type    = [t termType];
    if (type == GTWTermVariable) {
        return [[SPKTree alloc] initWithType:kTreeNode value: t arguments:nil];
    } else {
        return [self errorMessage:[NSString stringWithFormat:@"Expected Var, but found %@", t] withErrors:errors];
    }
}

// [110]  	Expression	  ::=  	ConditionalOrExpression
- (id<SPKTree>) parseExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseConditionalOrExpressionWithErrors:errors];
    return expr;
}

//[111]  	ConditionalOrExpression	  ::=  	ConditionalAndExpression ( '||' ConditionalAndExpression )*
- (id<SPKTree>) parseConditionalOrExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseConditionalAndExpressionWithErrors:errors];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == OROR) {
        [self nextNonCommentToken];
        id<SPKTree> rhs  = [self parseConditionalAndExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[SPKTree alloc] initWithType:kExprOr arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
    return expr;
}

//[112]  	ConditionalAndExpression	  ::=  	ValueLogical ( '&&' ValueLogical )*
- (id<SPKTree>) parseConditionalAndExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseValueLogicalWithErrors:errors];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == ANDAND) {
        [self nextNonCommentToken];
        id<SPKTree> rhs  = [self parseValueLogicalWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[SPKTree alloc] initWithType:kExprAnd arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
    return expr;
}

//[113]  	ValueLogical	  ::=  	RelationalExpression
- (id<SPKTree>) parseValueLogicalWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseRelationalExpressionWithErrors:errors];
    return expr;
}

//[114]  	RelationalExpression	  ::=  	NumericExpression ( '=' NumericExpression | '!=' NumericExpression | '<' NumericExpression | '>' NumericExpression | '<=' NumericExpression | '>=' NumericExpression | 'IN' ExpressionList | 'NOT' 'IN' ExpressionList )?
- (id<SPKTree>) parseRelationalExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseNumericExpressionWithErrors:errors];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t && (t.type == EQUALS || t.type == NOTEQUALS || t.type == LT || t.type == GT || t.type == LE || t.type == GE)) {
        [self nextNonCommentToken];
        id<SPKTree> rhs  = [self parseNumericExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        SPKTreeType type;
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
        expr    = [[SPKTree alloc] initWithType:type arguments:@[expr, rhs]];
    } else if (t && t.type == KEYWORD && [t.value isEqualToString: @"IN"]) {
        [self nextNonCommentToken];
        id<SPKTree> list    = [self parseExpressionListWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kExprIn arguments:@[expr, list]];
    } else if (t && t.type == KEYWORD && [t.value isEqualToString: @"NOT"]) {
        [self nextNonCommentToken];
        [self parseExpectedTokenOfType:KEYWORD withValue:@"IN" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> list    = [self parseExpressionListWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kExprNotIn arguments:@[expr, list]];
    }
    return expr;
}

//[115]  	NumericExpression	  ::=  	AdditiveExpression
- (id<SPKTree>) parseNumericExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseAdditiveExpressionWithErrors:errors];
    return expr;
}

//[116]  	AdditiveExpression	  ::=  	MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )* )*
- (id<SPKTree>) parseAdditiveExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseMultiplicativeExpressionWithErrors:errors];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    
    // TODO: handle ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )*
    while (t && (t.type == PLUS || t.type == MINUS)) {
        [self nextNonCommentToken];
        id<SPKTree> rhs  = [self parseMultiplicativeExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[SPKTree alloc] initWithType:(t.type == PLUS ? kExprPlus : kExprMinus) arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
    return expr;
}

//[117]  	MultiplicativeExpression	  ::=  	UnaryExpression ( '*' UnaryExpression | '/' UnaryExpression )*
- (id<SPKTree>) parseMultiplicativeExpressionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> expr    = [self parseUnaryExpressionWithErrors:errors];
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && (t.type == STAR || t.type == SLASH)) {
        [self nextNonCommentToken];
        id<SPKTree> rhs  = [self parseUnaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[SPKTree alloc] initWithType:(t.type == STAR ? kExprMul : kExprDiv) arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
    return expr;
}

//[118]  	UnaryExpression	  ::=  	  '!' PrimaryExpression
//|	'+' PrimaryExpression
//|	'-' PrimaryExpression
//|	PrimaryExpression
- (id<SPKTree>) parseUnaryExpressionWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == BANG) {
        [self parseExpectedTokenOfType:BANG withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kExprBang arguments:@[expr]];
    } else if (t.type == PLUS) {
        [self parseExpectedTokenOfType:PLUS withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else if (t.type == MINUS) {
        [self parseExpectedTokenOfType:MINUS withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[SPKTree alloc] initWithType:kExprUMinus arguments:@[expr]];
    } else {
        id<SPKTree> expr    = [self parsePrimaryExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    }
}


//[119]  	PrimaryExpression	  ::=  	BrackettedExpression | BuiltInCall | iriOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | Var
- (id<SPKTree>) parsePrimaryExpressionWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self parseBrackettedExpressionWithErrors: errors];
    } else if (t.type == IRI || t.type == PREFIXNAME) {
        return [self parseIRIOrFunctionWithErrors: errors];
    } else if ([self tokenIsVarOrTerm:t]) {
        if (t.type == NIL || t.type == ANON || t.type == BNODE) {
            return [self errorMessage:[NSString stringWithFormat:@"Expected PrimaryExpression term (IRI, Literal, or Var) but found %@", t] withErrors:errors];
        }
        id<SPKTree> expr    = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else {
        return [self parseBuiltInCallWithErrors:errors];
    }
}

// [128]  	iriOrFunction	  ::=  	iri ArgList?
//[71]  	ArgList	  ::=  	NIL | '(' 'DISTINCT'? Expression ( ',' Expression )* ')'
- (id<SPKTree>) parseIRIOrFunctionWithErrors: (NSMutableArray*) errors {
    id<SPKTree> iri    = [self parseVarOrTermWithErrors:errors];
    ASSERT_EMPTY(errors);
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == NIL) {
        [self parseExpectedTokenOfType:NIL withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> func    = [[SPKTree alloc] initWithType:kExprFunction value:iri.value arguments:@[]];
        return func;
    } else if (t.type == LPAREN) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        
        t   = [self peekNextNonCommentToken];
        if (t.type == RPAREN) {
            [self parseExpectedTokenOfType:RPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            id<SPKTree> func    = [[SPKTree alloc] initWithType:kExprFunction value:iri.value arguments:@[]];
            return func;
        } else {
            // distinct flag isn't currently used in the algebra tree, because no functions actually make use of it.
            [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
            id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            if (!expr) {
                NSLog(@"no expression in parseIRIOrFunctionWithErrors:");
            }
            NSMutableArray* list    = [NSMutableArray arrayWithObject: expr];

            t   = [self peekNextNonCommentToken];
            while (t.type == COMMA) {
                [self nextNonCommentToken];
                id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
                ASSERT_EMPTY(errors);
                [list addObject:expr];
                t   = [self peekNextNonCommentToken];
            }

            id<SPKTree> func    = [[SPKTree alloc] initWithType:kExprFunction value:iri.value arguments:list];
            [self parseExpectedTokenOfType:RPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            return func;
        }
    } else {
        return iri;
    }
}


// [120]  	BrackettedExpression	  ::=  	'(' Expression ')'
- (id<SPKTree>) parseBrackettedExpressionWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
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
- (id<SPKTree>) parseBuiltInCallWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
	NSRange agg_range	= [t.value rangeOfString:@"(COUNT|SUM|MIN|MAX|AVG|SAMPLE|GROUP_CONCAT)" options:NSRegularExpressionSearch];
    NSRange func_range  = [t.value rangeOfString:@"(STR|LANG|LANGMATCHES|DATATYPE|BOUND|IRI|URI|BNODE|RAND|ABS|CEIL|FLOOR|ROUND|CONCAT|STRLEN|UCASE|LCASE|ENCODE_FOR_URI|CONTAINS|STRSTARTS|STRENDS|STRBEFORE|STRAFTER|YEAR|MONTH|DAY|HOURS|MINUTES|SECONDS|TIMEZONE|TZ|NOW|UUID|STRUUID|MD5|SHA1|SHA256|SHA384|SHA512|COALESCE|IF|STRLANG|STRDT|SAMETERM|SUBSTR|REPLACE|ISIRI|ISURI|ISBLANK|ISLITERAL|ISNUMERIC|REGEX)" options:NSRegularExpressionSearch];
    if (t.type == KEYWORD && agg_range.location == 0 && ((![t.value isEqualToString:@"MINUTES"]))) {    // the length check is in case we've mistaken a longer token (e.g. MINUTES) for MIN here
        return [self parseAggregateWithErrors: errors];
    } else if (t.type == KEYWORD && [t.value isEqualToString:@"NOT"]) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"NOT" withErrors:errors];
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:KEYWORD withValue:@"EXISTS" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
        return [[SPKTree alloc] initWithType:kExprNotExists arguments:@[ggp]];
    } else if (t.type == KEYWORD && [t.value isEqualToString:@"EXISTS"]) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"EXISTS" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
        return [[SPKTree alloc] initWithType:kExprExists arguments:@[ggp]];
    } else if (t.type == KEYWORD && func_range.location == 0) {
        [self nextNonCommentToken];
        NSString* funcname  = t.value;
        NSMutableArray* arguments   = [NSMutableArray array];
        t   = [self parseOptionalTokenOfType:NIL];
        if (!t) {
            [self parseExpectedTokenOfType:LPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            [arguments addObject:expr];
            
            t   = [self parseOptionalTokenOfType:COMMA];
            while (t) {
                id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
                ASSERT_EMPTY(errors);
                [arguments addObject:expr];
                t   = [self parseOptionalTokenOfType:COMMA];
            }
            [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        }
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
        SPKTreeType functype    = [funcdict objectForKey:funcname];
        if (functype == kExprIRI) {
            id<SPKTree> base    = [[SPKTree alloc] initWithType:kTreeNode value:self.baseIRI arguments:nil];
            [arguments addObject:base];
        }
        id<SPKTree> func    = [[SPKTree alloc] initWithType:functype arguments:arguments];
        return func;
    }
    return nil;
}

//[127]  	Aggregate	  ::=  	  'COUNT' '(' 'DISTINCT'? ( '*' | Expression ) ')'
//| 'SUM' '(' 'DISTINCT'? Expression ')'
//| 'MIN' '(' 'DISTINCT'? Expression ')'
//| 'MAX' '(' 'DISTINCT'? Expression ')'
//| 'AVG' '(' 'DISTINCT'? Expression ')'
//| 'SAMPLE' '(' 'DISTINCT'? Expression ')'
//| 'GROUP_CONCAT' '(' 'DISTINCT'? Expression ( ';' 'SEPARATOR' '=' String )? ')'
- (id<SPKTree>) parseAggregateWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
    ASSERT_EMPTY(errors);
    if ([t.value isEqualToString: @"COUNT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        SPKSPARQLToken* t   = [self peekNextNonCommentToken];
        id<SPKTree> agg;
        if (t.type == STAR) {
            [self nextNonCommentToken];
            agg     = [[SPKTree alloc] initWithType:kExprCount value: @(d ? YES : NO) arguments:@[]];
        } else {
            id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            agg     = [[SPKTree alloc] initWithType:kExprCount value: @(d ? YES : NO) arguments:@[expr]];
        }
        ASSERT_EMPTY(errors);
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"SUM"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprSum value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"MIN"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprMin value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"MAX"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprMax value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"AVG"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprAvg value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"SAMPLE"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprSample value: @(d ? YES : NO) arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqualToString: @"GROUP_CONCAT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        
        SPKSPARQLToken* sc  = [self parseOptionalTokenOfType:SEMICOLON];
        NSString* separator = @" ";
        if (sc) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"SEPARATOR" withErrors:errors];
            ASSERT_EMPTY(errors);
            [self parseExpectedTokenOfType:EQUALS withErrors:errors];
            ASSERT_EMPTY(errors);
            SPKSPARQLToken* t   = [self nextNonCommentToken];
            id<GTWTerm> str     = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            
            separator   = str.value;
        }
        id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprGroupConcat value: @[@(d ? YES : NO), separator] arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    }
    return nil;
}

- (id<SPKTree>) parseIRIWithErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if (![t isKindOfClass:[GTWIRI class]]) {
        return [self errorMessage:[NSString stringWithFormat:@"Expected IRI but found %@", t] withErrors:errors];
    }
    
    return [[SPKTree alloc] initWithType:kTreeNode value: t arguments:nil];
}

// [55]  	TriplesBlock	  ::=  	TriplesSameSubjectPath ( '.' TriplesBlock? )?
- (id<SPKTree>) triplesByParsingTriplesBlockWithErrors: (NSMutableArray*) errors {
    NSArray* sameSubj    = [self triplesArrayByParsingTriplesSameSubjectPathWithErrors:errors];
    ASSERT_EMPTY(errors);
    if (!sameSubj)
        return nil;
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (!t || t.type != DOT) {
        return [[SPKTree alloc] initWithType:kTreeList arguments:sameSubj];
    } else {
        [self parseExpectedTokenOfType:DOT withErrors:errors];
        ASSERT_EMPTY(errors);
        
        t   = [self peekNextNonCommentToken];
        // TODO: Check if TriplesBlock can be parsed (it's more than just tokenIsVarOrTerm:)
        if ([self tokenIsVarOrTerm:t] || NO) {
            id<SPKTree> more    = [self triplesByParsingTriplesBlockWithErrors:errors];
            ASSERT_EMPTY(errors);
            NSMutableArray* triples = [NSMutableArray array];
            [triples addObjectsFromArray:sameSubj];
            [triples addObjectsFromArray:more.arguments];
            return [[SPKTree alloc] initWithType:kTreeList arguments:triples];
        } else {
            return [[SPKTree alloc] initWithType:kTreeList arguments:sameSubj];
        }
    }
}

// [56]  	GraphPatternNotTriples	  ::=  	GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
- (id<SPKTree>) treeByParsingGraphPatternNotTriplesWithError: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        NSString* kw    = t.value;
        if ([kw isEqualToString:@"OPTIONAL"]) {
            // 'OPTIONAL' GroupGraphPattern
            [self nextNonCommentToken];
            id<SPKTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            if ([ggp.type isEqual:kAlgebraFilter]) {
                id<SPKTree> expr    = ggp.treeValue;
                return [[SPKTree alloc] initWithType:kAlgebraLeftJoin treeValue: expr arguments:[ggp.arguments copy]];
            } else {
                return [[SPKTree alloc] initWithType:kAlgebraLeftJoin arguments:@[ggp]];
            }
        } else if ([kw isEqualToString:@"MINUS"]) {
            // 'MINUS' GroupGraphPattern
            [self nextNonCommentToken];
            id<SPKTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[SPKTree alloc] initWithType:kAlgebraMinus arguments:@[ggp]];
        } else if ([kw isEqualToString:@"GRAPH"]) {
            // 'GRAPH' VarOrIri GroupGraphPattern
            [self nextNonCommentToken];
            id<SPKTree> varOrIRI    = [self parseVarOrIRIWithErrors: errors];
            ASSERT_EMPTY(errors);
            if (!varOrIRI)
                return nil;
            id<GTWTerm> g           = varOrIRI.value;
            if (!g)
                return nil;
            id<SPKTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            id<SPKTree> graph   = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            id<SPKTree> graphPattern    = [[SPKTree alloc] initWithType:kAlgebraGraph treeValue: graph arguments:@[ggp]];
            return graphPattern;
        } else if ([kw isEqualToString:@"SERVICE"]) {
            // 'SERVICE' 'SILENT'? VarOrIri GroupGraphPattern
            [self nextNonCommentToken];
            SPKSPARQLToken* silent  = [self parseOptionalTokenOfType:KEYWORD withValue:@"SILENT"];
            id<SPKTree> varOrIRI    = [self parseVarOrIRIWithErrors: errors];
            ASSERT_EMPTY(errors);
            if (!varOrIRI)
                return nil;
            id<GTWTerm> g           = varOrIRI.value;
            if (!g)
                return nil;
            
            id<SPKTree> graph   = [[SPKTree alloc] initWithType:kTreeNode value:g arguments:nil];
            id<SPKTree> silentFlag  = [[SPKTree alloc] initWithType:kTreeNode value:(silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral]) arguments:nil];
            id<SPKTree> graphAndSilent   = [[SPKTree alloc] initWithType:kTreeList arguments:@[graph, silentFlag]];
            id<SPKTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[SPKTree alloc] initWithType:kAlgebraService treeValue: graphAndSilent arguments:@[ggp]];
        } else if ([kw isEqualToString:@"FILTER"]) {
            [self nextNonCommentToken];
            id<SPKTree> f   = [self parseConstraintWithErrors:errors];
            ASSERT_EMPTY(errors);
            return [[SPKTree alloc] initWithType:kAlgebraFilter treeValue: f arguments:nil];
        } else if ([kw isEqualToString:@"VALUES"]) {
            return [self parseInlineDataWithErrors: errors];
        } else if ([kw isEqualToString:@"BIND"]) {
            return [self parseBindWithErrors: errors];
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Unexpected KEYWORD %@ while expecting GraphPatternNotTriples", t.value] withErrors:errors];
        }
    } else if (t.type == LBRACE) {
        // GroupGraphPattern ( 'UNION' GroupGraphPattern )*
        id<SPKTree> ggp = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp) {
            return nil;
        }
        
        t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"UNION"];
        while (t) {
            id<SPKTree> rhs = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            [self checkForSharedBlanksInPatterns:@[ggp, rhs] error:errors];
            ASSERT_EMPTY(errors);
            ggp = [[SPKTree alloc] initWithType:kAlgebraUnion arguments:@[ggp, rhs]];
            t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"UNION"];
        }
        return ggp;
    } else {
        return [self errorMessage:[NSString stringWithFormat:@"Expecting KEYWORD but got %@", t] withErrors:errors];
    }
    NSLog(@"parseGraphPatternNotTriplesWithError: not implemented yet");
    return nil;
}





#pragma mark -


- (SPKSPARQLToken*) parseExpectedTokenOfType: (SPKSPARQLTokenType) type withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        NSString* reason    = [NSString stringWithFormat:@"Expecting %@ but found %@", [SPKSPARQLToken nameOfSPARQLTokenOfType:type], t];
        return [self errorMessage:reason withErrors:errors];
    } else {
        return t;
    }
}

- (SPKSPARQLToken*) parseOptionalTokenOfType: (SPKSPARQLTokenType) type {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        return nil;
    } else {
        [self nextNonCommentToken];
        return t;
    }
}

- (SPKSPARQLToken*) parseExpectedTokenOfType: (SPKSPARQLTokenType) type withValue: (NSString*) string withErrors: (NSMutableArray*) errors {
    SPKSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        return [self errorMessage:[NSString stringWithFormat:@"Expecting %@['%@'] but found %@", [SPKSPARQLToken nameOfSPARQLTokenOfType:type], string, t] withErrors:errors];
    } else {
        if ([t.value isEqualToString: string]) {
            return t;
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting %@ value '%@' but found '%@'", [SPKSPARQLToken nameOfSPARQLTokenOfType:type], string, t.value] withErrors:errors];
        }
    }
}

- (SPKSPARQLToken*) parseOptionalTokenOfType: (SPKSPARQLTokenType) type withValue: (NSString*) string {
    SPKSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type != type) {
        return nil;
    } else {
        if ([t.value isEqualToString: string]) {
            [self nextNonCommentToken];
            return t;
        } else {
            return nil;
        }
    }
}

#pragma mark -

- (NSSet*) aggregatesForCurrentQuery {
    NSMutableSet* set   = [self.aggregateSets lastObject];
    return [set copy];
}

- (void) addSeenAggregate: (id<SPKTree>) agg {
    NSMutableSet* set   = [self.aggregateSets lastObject];
    [set addObject:agg];
    [self.seenAggregates removeLastObject];
    [self.seenAggregates addObject:@(YES)];
}

- (void) beginQueryScope {
    [self.seenAggregates addObject:@(NO)];
    [self.aggregateSets addObject:[NSMutableSet set]];
}

- (void) endQueryScope {
    [self.seenAggregates removeLastObject];
    [self.aggregateSets removeLastObject];
}

#pragma mark -

- (id<GTWTerm>) tokenAsTerm: (SPKSPARQLToken*) t withErrors: (NSMutableArray*) errors {
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
    } else if (t.type == STRING1D || t.type == STRING1S) {
        NSString* value = t.value;
        SPKSPARQLToken* hh  = [self parseOptionalTokenOfType:HATHAT];
        if (hh) {
            t   = [self nextNonCommentToken];
            id<GTWTerm> dt  = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWLiteral alloc] initWithValue:value datatype:dt.value];
        }
        SPKSPARQLToken* lang  = [self parseOptionalTokenOfType:LANG];
        if (lang) {
            return [[GTWLiteral alloc] initWithValue:value language:lang.value];
        }
        return [[GTWLiteral alloc] initWithValue:value];
    } else if (t.type == STRING3D || t.type == STRING3S) {
        NSString* value = t.value;
        SPKSPARQLToken* hh  = [self parseOptionalTokenOfType:HATHAT];
        if (hh) {
            t   = [self nextNonCommentToken];
            id<GTWTerm> dt  = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWLiteral alloc] initWithValue:value datatype:dt.value];
        }
        return [[GTWLiteral alloc] initWithValue:value];
    } else if ((t.type == KEYWORD) && [t.value isEqualToString:@"A"]) {
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
        NSString* value = [NSString stringWithFormat:@"+%@", t.value];
        if (t.type == INTEGER) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
        } else if (t.type == DECIMAL) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#decimal"];
        } else if (t.type == DOUBLE) {
            return [[GTWLiteral alloc] initWithValue:value datatype:@"http://www.w3.org/2001/XMLSchema#double"];
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Expecting numeric value after PLUS but found: %@", t] withErrors:errors];
        }
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
