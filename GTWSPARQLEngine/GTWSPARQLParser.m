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

- (BOOL) currentQuerySeenAggregates {
    if ([self.seenAggregates count]) {
        NSNumber* s = [self.seenAggregates lastObject];
        return [s boolValue];
    } else {
        return NO;
    }
}

- (GTWSPARQLParser*) init {
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

- (id<GTWTree>) parseSPARQL: (NSString*) queryString withBaseURI: (NSString*) base error: (NSError**) error {
    NSString *unescaped = [queryString mutableCopy];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)unescaped, NULL, transform, YES);
    
    self.lexer      = [[GTWSPARQLLexer alloc] initWithString:unescaped];
    self.baseIRI    = [[GTWIRI alloc] initWithValue:base];
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

- (id<GTWTree>) parseWithError: (NSError**) error {
    GTWSPARQLToken* t;
    id<GTWTree> algebra;
    [self beginQueryScope];
    NSMutableArray* errors  = [NSMutableArray array];
    
    @autoreleasepool {
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
            algebra = [self parseDescribeQueryWithErrors: errors];
            if ([errors count])
                goto cleanup;
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
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (YES) {
        if (t.type != KEYWORD)
            break;
        
        if ([t.value isEqual:@"PREFIX"]) {
            [self nextNonCommentToken];
            GTWSPARQLToken* name    = [self nextNonCommentToken];
            if ([name.args count] > 2 || ([name.args count] == 2 && ![[name.args objectAtIndex:1] isEqual: @""])) {
                [self errorMessage:[NSString stringWithFormat: @"Expecting PNAME_NS in PREFIX declaration, but found PNAME_LN %@", [name.args componentsJoinedByString:@":"]] withErrors:errors];
                return;
            }
            GTWSPARQLToken* iri     = [self nextNonCommentToken];
            if (name && iri) {
                [self.namespaces setValue:iri.value forKey:name.value];
            } else {
                [self errorMessage:@"Failed to parse PREFIX declaration" withErrors:errors];
                return;
            }
        } else if ([t.value isEqual:@"BASE"]) {
            [self nextNonCommentToken];
            GTWSPARQLToken* iri     = [self nextNonCommentToken];
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
                [project addObject:[[GTWTree alloc] initWithType:kTreeNode value:term arguments:nil]];
            } else if (t.type == LPAREN) {
                [self nextNonCommentToken];
                id<GTWTree> expr    = [self parseExpressionWithErrors: errors];
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:KEYWORD withValue:@"AS" withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> var     = [self parseVarWithErrors: errors];
                id<GTWTerm> term    = var.value;
                ASSERT_EMPTY(errors);
                [self parseExpectedTokenOfType:RPAREN withErrors:errors];
                ASSERT_EMPTY(errors);
                id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:@[expr, var]];
                id<GTWTree> pvar    = [[GTWTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
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
    id<GTWTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp)
        return nil;
    
    id<GTWTree> algebra = ggp;

    // SolutionModifier
    algebra = [self parseSolutionModifierForAlgebra:algebra withProjectionArray: project distinct:distinct withErrors:errors];
    ASSERT_EMPTY(errors);

    if (dataset) {
        algebra = [[GTWTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
    }
    
    if (star && [self currentQuerySeenAggregates]) {
        return [self errorMessage:@"SELECT * not legal with GROUP BY" withErrors:errors];
    }
    
    return algebra;
}

- (id<GTWTree>) rewriteTree: (id<GTWTree>) tree withAggregateMapping: (NSDictionary*) mapping withErrors: (NSMutableArray*) errors {
    if (!tree)
        return nil;
    if (tree.type == kAlgebraExtend) {
        id<GTWTree> tv          = tree.treeValue;
        id<GTWTree> expr        = [self rewriteTree:tv.arguments[0] withAggregateMapping:mapping withErrors:errors];
        GTWVariable* v          = [mapping objectForKey:expr];
        if (v) {
            id<GTWTree> tn  = [[GTWTree alloc] initWithType:kTreeNode value:v arguments:nil];
            id<GTWTree> pair    = [[GTWTree alloc] initWithType:kTreeList arguments:@[tn, tv.arguments[1]]];
            id<GTWTree> ext = [[GTWTree alloc] initWithType:kAlgebraExtend treeValue:pair arguments:nil];
            return ext;
        }
    } else if ([mapping objectForKey:tree]) {
        GTWVariable* v          = [mapping objectForKey:tree];
        id<GTWTree> tn  = [[GTWTree alloc] initWithType:kTreeNode value:v arguments:nil];
        return tn;
    }
    
    NSMutableArray* args    = [NSMutableArray array];
    id<GTWTree> tv          = [self rewriteTree:tree.treeValue withAggregateMapping:mapping withErrors:errors];
    for (id t in tree.arguments) {
        id<GTWTree> newTree = [self rewriteTree:t withAggregateMapping:mapping withErrors:errors];
        [args addObject:newTree];
    }
    id<GTWTree> newt    = [[GTWTree alloc] initWithType:tree.type value:tree.value treeValue:tv arguments:args];
    return newt;
}

- (id<GTWTree>) rewriteAlgebra: (id<GTWTree>) algebra forProjection: (NSArray*) project withAggregateMapping: (NSDictionary*) mapping withErrors: (NSMutableArray*) errors {
    GTWTree* vlist;
    if ([mapping count]) {
        NSMutableArray* mappedProject  = [NSMutableArray array];
        for (id<GTWTree> tree in project) {
            id<GTWTree> t   = [self rewriteTree:tree withAggregateMapping:mapping withErrors:errors];
            ASSERT_EMPTY(errors);
            [mappedProject addObject:t];
        }
        vlist = [[GTWTree alloc] initWithType:kTreeList arguments:mappedProject];
    } else {
        vlist   = [[GTWTree alloc] initWithType:kTreeList arguments:project];
    }
    
    algebra = [[GTWTree alloc] initWithType:kAlgebraProject treeValue:vlist arguments:@[algebra]];
    algebra = [self algebraVerifyingProjectionAndGroupingInAlgebra: algebra withErrors:errors];
    ASSERT_EMPTY(errors);
    return algebra;
}

//        [10]  	ConstructQuery	  ::=  	'CONSTRUCT' ( ConstructTemplate DatasetClause* WhereClause SolutionModifier | DatasetClause* 'WHERE' '{' TriplesTemplate? '}' SolutionModifier )
- (id<GTWTree>) parseConstructQueryWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"CONSTRUCT" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LBRACE) {
        id<GTWTree> template    = [self parseConstructTemplateWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        id<GTWTree> dataset     = [self parseDatasetClausesWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp) {
            NSLog(@"-------------------");
        }
        id<GTWTree> algebra = [self parseSolutionModifierForAlgebra:ggp withProjectionArray: nil distinct:NO withErrors:errors];
        ASSERT_EMPTY(errors);
        
        if (dataset) {
            algebra = [[GTWTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
        }

        algebra     = [[GTWTree alloc] initWithType:kAlgebraConstruct arguments:@[template, algebra]];
        return algebra;
    } else {
        id<GTWTree> dataset = [self parseDatasetClausesWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:KEYWORD withValue:@"WHERE" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> ggp         = [self parseConstructTemplateWithErrors: errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> template = [self parseSolutionModifierForAlgebra:ggp withProjectionArray: nil distinct:NO withErrors:errors];
        ASSERT_EMPTY(errors);
     
        id<GTWTree> algebra;
        if (dataset) {
            algebra = [[GTWTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[template]];
        } else {
            algebra = template;
        }

        algebra     = [[GTWTree alloc] initWithType:kAlgebraConstruct arguments:@[template, algebra]];
        return algebra;
    }
}

//[11]  	DescribeQuery	  ::=  	'DESCRIBE' ( VarOrIri+ | '*' ) DatasetClause* WhereClause? SolutionModifier
- (id<GTWTree>) parseDescribeQueryWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"DESCRIBE" withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    BOOL star;
    NSMutableArray* vars    = [NSMutableArray array];
    if (t.type == STAR) {
        star    = YES;
        [self parseExpectedTokenOfType:STAR withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        star    = NO;
        while ([self tokenIsVarOrTerm:t]) {
            id<GTWTree> var = [self parseVarOrIRIWithErrors:errors];
            ASSERT_EMPTY(errors);
            [vars addObject:var];
            t   = [self peekNextNonCommentToken];
        }
    }

    // DatasetClause*
    id<GTWTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    GTWSPARQLToken* where   = [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp;
    if (where) {
        ggp     = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp)
            return nil;
    } else {
        ggp = [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
    }
    
    id<GTWTree> algebra = ggp;
    // SolutionModifier
    algebra = [self parseSolutionModifierForAlgebra:algebra withProjectionArray: nil distinct:NO withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if (dataset) {
        algebra = [[GTWTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[algebra]];
    }
    
    if (star) {
        NSSet* set  = [algebra inScopeVariables];
        for (id<GTWTerm> t in set) {
            id<GTWTree> tn  = [[GTWTree alloc] initWithType:kTreeNode value:t arguments:nil];
            [vars addObject:tn];
        }
    }
    id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:vars];
    return [[GTWTree alloc] initWithType:kAlgebraDescribe treeValue:list arguments:@[algebra]];
}

//[73]  	ConstructTemplate	  ::=  	'{' ConstructTriples? '}'
//[74]  	ConstructTriples	  ::=  	TriplesSameSubject ( '.' ConstructTriples? )?
- (id<GTWTree>) parseConstructTemplateWithErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LBRACE withErrors:errors];
    ASSERT_EMPTY(errors);

    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == RBRACE) {
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        id<GTWTree> tmpl    = [self triplesByParsingTriplesBlockWithErrors: errors];
        ASSERT_EMPTY(errors);
        
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);

        id<GTWTree> triples = [self reduceTriplePaths:tmpl];
        return triples;
    }
}

- (id<GTWTree>) algebraVerifyingExtend: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    if (algebra.type == kAlgebraExtend) {
        id<GTWTree> list    = algebra.treeValue;
        id<GTWTree> n       = list.arguments[1];
        id<GTWTerm> t       = n.value;
        id<GTWTree> suba    = list.arguments[0];
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

- (id<GTWTree>) algebraVerifyingProjection: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    id<GTWTree> projectList = algebra.treeValue;
    NSArray* plist          = projectList.arguments;
    
    id<GTWTree> pattern     = algebra.arguments[0];
    NSSet* scopeVars        = [pattern inScopeVariables];
    for (id<GTWTree> v in plist) {
        if (v.type == kAlgebraExtend) {
            id<GTWTree> list    = v.treeValue;
            id<GTWTree> n   = list.arguments[1];
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

- (id<GTWTree>) algebraVerifyingProjectionAndGroupingInAlgebra: (id<GTWTree>) algebra withErrors: (NSMutableArray*) errors {
    id<GTWTree> projectList = algebra.treeValue;
    NSArray* plist          = projectList.arguments;
    
    algebra = [self algebraVerifyingProjection:algebra withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if ([self currentQuerySeenAggregates]) {
        NSSet* groupVars    = [(GTWTree*)algebra projectableAggregateVariables];
        
        NSMutableSet* newProjection = [NSMutableSet set];
        for (id<GTWTree> v in plist) {
            if (v.type == kTreeNode) {
                id<GTWTerm> t   = v.value;
                if (![groupVars containsObject:t]) {
                    if (!([t isKindOfClass:[GTWVariable class]] && [t.value hasPrefix:@".agg"])) { // XXX this is a hack to recognize the fake variables (like ?.1) introduced by aggregation
                        if (![newProjection containsObject:t]) {
                            return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed", t] withErrors:errors];
                        }
                    }
                }
            } else {
                NSSet* vars = [v nonAggregatedVariables];
                for (id<GTWTerm> t in vars) {
                    if (![groupVars containsObject:t]) {
                        if (!([t isKindOfClass:[GTWVariable class]] && [t.value hasPrefix:@".agg"])) { // XXX this is a hack to recognize the fake variables (like ?.1) introduced by aggregation
                            if (![newProjection containsObject:t]) {
                                return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed", t] withErrors:errors];
                            }
                        }
                    }
                }
                if (v.type == kAlgebraExtend) {
                    id<GTWTree> list    = v.treeValue;
                    id<GTWTree> nt      = list.arguments[1];
                    id<GTWTerm> var     = nt.value;
                    [newProjection addObject:var];
                }
            }
        }
    }
    
    return algebra;
}

- (id<GTWTree>) parseAskQueryWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"ASK" withErrors:errors];
    ASSERT_EMPTY(errors);
    
    // DatasetClause*
    id<GTWTree> dataset = [self parseDatasetClausesWithErrors: errors];
    ASSERT_EMPTY(errors);
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp) {
        return nil;
    }
    
    if (dataset) {
        ggp = [[GTWTree alloc] initWithType:kAlgebraDataset treeValue: dataset arguments:@[ggp]];
    }
    
    //@@ SolutionModifier
    return [[GTWTree alloc] initWithType:kAlgebraAsk arguments:@[ggp]];
}

//[13]  	DatasetClause	  ::=  	'FROM' ( DefaultGraphClause | NamedGraphClause )
//[14]  	DefaultGraphClause	  ::=  	SourceSelector
//[15]  	NamedGraphClause	  ::=  	'NAMED' SourceSelector
//[16]  	SourceSelector	  ::=  	iri
- (id<GTWTree>) parseDatasetClausesWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t       = [self parseOptionalTokenOfType:KEYWORD withValue:@"FROM"];
    NSMutableSet* namedSet  = [NSMutableSet set];
    NSMutableSet* defSet    = [NSMutableSet set];
    while (t) {
        GTWSPARQLToken* named   = [self parseOptionalTokenOfType:KEYWORD withValue:@"NAMED"];
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
    
    id<GTWTree> namedTree   = [[GTWTree alloc] initWithType:kTreeSet value:namedSet arguments:nil];
    id<GTWTree> defTree     = [[GTWTree alloc] initWithType:kTreeSet value:defSet arguments:nil];
    id<GTWTree> pair        = [[GTWTree alloc] initWithType:kTreeList arguments:@[defTree, namedTree]];
    return pair;
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
    return [[GTWTree alloc] initWithType:kAlgebraBGP arguments:triples];
}

//[8]  	SubSelect	  ::=  	SelectClause WhereClause SolutionModifier ValuesClause
- (id<GTWTree>) parseSubSelectWithError: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:KEYWORD withValue:@"SELECT" withErrors:errors];
    ASSERT_EMPTY(errors);
    NSUInteger distinct = 0;
    [self beginQueryScope];
    
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
                id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:@[expr, var]];
                id<GTWTree> pvar    = [[GTWTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
                [project addObject:pvar];
            }
            t   = [self peekNextNonCommentToken];
        }
    }
    
    [self parseOptionalTokenOfType:KEYWORD withValue:@"WHERE"];
    id<GTWTree> ggp     = [self parseGroupGraphPatternWithError:errors];
    ASSERT_EMPTY(errors);
    if (!ggp) {
        [self endQueryScope];
        return nil;
    }
    
    id<GTWTree> algebra = ggp;
    
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
            id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:@[expr, var]];
            cond    = [[GTWTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
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
- (id<GTWTree>) parseOrderConditionAscending: (BOOL*) ascending withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* asc = [self parseOptionalTokenOfType:KEYWORD withValue:@"ASC"];
    *ascending  = YES;
    BOOL forceBrackettedExpression = asc ? YES : NO;
    if (!asc) {
        GTWSPARQLToken* desc = [self parseOptionalTokenOfType:KEYWORD withValue:@"DESC"];
        if (desc) {
            forceBrackettedExpression   = YES;
            *ascending  = NO;
        }
    }
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (forceBrackettedExpression || t.type == LPAREN) {
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
    } else if (t.type == IRI || t.type == PREFIXNAME) {
        return [self parseFunctionCallWithErrors:errors];
    } else {
        return [self parseBuiltInCallWithErrors:errors];
    }
}

//[70]  	FunctionCall	  ::=  	iri ArgList
- (id<GTWTree>) parseFunctionCallWithErrors: (NSMutableArray*) errors {
    id<GTWTree> func    = [self parseIRIOrFunctionWithErrors: errors];
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
- (id<GTWTree>) parseSolutionModifierForAlgebra: (id<GTWTree>) algebra withProjectionArray: (NSArray*) project distinct: (BOOL) distinct withErrors: (NSMutableArray*) errors {
    NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
    GTWSPARQLToken* t;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"GROUP"];
    
    BOOL needGrouping   = NO;
    NSMutableArray* groupConditions   = [NSMutableArray array];
    if (t) {
        needGrouping    = YES;
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> cond;
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
    
    id<GTWTree> havingConstraint    = nil;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"HAVING"];
    if (t) {
        havingConstraint    = [self parseConstraintWithErrors:errors];
        ASSERT_EMPTY(errors);
    }
    
    id<GTWTree> orderList   = nil;
    t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"ORDER"];
    if (t) {
        [self parseExpectedTokenOfType:KEYWORD withValue:@"BY" withErrors:errors];
        ASSERT_EMPTY(errors);
        NSMutableArray* conds   = [NSMutableArray array];
        id<GTWTree> cond;
        BOOL asc    = YES;
        while ((cond = [self parseOrderConditionAscending:&asc withErrors:errors])) {
            ASSERT_EMPTY(errors);
            [conds addObject:cond];
            [conds addObject:[[GTWTree alloc] initLeafWithType:kTreeNode value: [GTWLiteral integerLiteralWithValue:(asc ? 1 : -1)]]];
        }
        ASSERT_EMPTY(errors);
        orderList  = [[GTWTree alloc] initWithType:kTreeList arguments:conds];
    }

    
    id<GTWTree> groupingTree;
    if (needGrouping || [groupConditions count]) {
        NSSet* aggregates  = [self aggregatesForCurrentQuery];
        NSUInteger i    = 0;
        NSMutableArray* aggregateList   = [NSMutableArray array];
        for (id<GTWTree, NSCopying> agg in aggregates) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".agg%lu", i++]];
            mapping[agg]   = v;
            id<GTWTree> aggPair   = [[GTWTree alloc] initWithType:kTreeList value:v arguments:@[agg]];
            [aggregateList addObject:aggPair];
        }
        id<GTWTree> groupList   = [[GTWTree alloc] initWithType:kTreeList arguments:groupConditions];
        id<GTWTree> aggregateTree   = [[GTWTree alloc] initWithType:kTreeList arguments:aggregateList];
        groupingTree    = [[GTWTree alloc] initWithType:kTreeList arguments:@[groupList, aggregateTree]];
    }

    if (groupingTree) {
        algebra = [[GTWTree alloc] initWithType:kAlgebraGroup treeValue: groupingTree arguments:@[algebra]];
    }

    if (project) {
        NSSet* scopeVars    = [algebra inScopeVariables];
        NSMutableArray* nonExtends  = [NSMutableArray array];
        for (id<GTWTree> proj in project) {
            if (proj.type == kAlgebraExtend) {
                if ([self currentQuerySeenAggregates]) {
                    NSSet* nonAggVars   = [proj nonAggregatedVariables];
                    NSSet* groupVars    = [(GTWTree*)algebra projectableAggregateVariables];
                    for (id<GTWTerm> var in nonAggVars) {
                        if (![groupVars containsObject:nonAggVars]) {
                            return [self errorMessage:[NSString stringWithFormat:@"Projecting non-grouped variable %@ not allowed", var] withErrors:errors];
                        }
                    }
                }
                proj.arguments  = @[algebra];
                algebra         = proj;
                id<GTWTree> var = proj.treeValue.arguments[1];
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
        for (id<GTWTree,NSCopying> k in mapping) {
            id<GTWTerm> v   = mapping[k];
            id<GTWTree> tn  = [[GTWTree alloc] initWithType:kTreeNode value:v arguments:nil];
            treeMap[k]      = tn;
        }
        id<GTWTree> constraint  = [self rewriteTree:[havingConstraint copyReplacingValues:treeMap] withAggregateMapping:mapping withErrors:errors];
        ASSERT_EMPTY(errors);
        algebra = [[GTWTree alloc] initWithType:kAlgebraFilter treeValue: constraint arguments:@[algebra]];
    }
    
    if (orderList) {
        NSArray* list    = orderList.arguments;
        NSMutableArray* mappedList  = [NSMutableArray array];
        for (id<GTWTree> t in list) {
            GTWVariable* v  = [mapping objectForKey:t];
            if (v) {
                id<GTWTree> tn  = [[GTWTree alloc] initWithType:kTreeNode value:v arguments:nil];
                [mappedList addObject:tn];
            } else {
                [mappedList addObject:t];
            }
        }
        id<GTWTree> mappedOrderList = [[GTWTree alloc] initWithType:kTreeList arguments:mappedList];
        algebra = [[GTWTree alloc] initWithType:kAlgebraOrderBy treeValue: mappedOrderList arguments:@[algebra]];
    }
    
    if (project) {
        algebra = [self rewriteAlgebra: algebra forProjection: project withAggregateMapping: mapping withErrors:errors];
        ASSERT_EMPTY(errors);
    } else {
        NSSet* vars = [algebra inScopeVariables];
        NSMutableArray* project   = [NSMutableArray array];
        for (id<GTWTerm> v in vars) {
            [project addObject:[[GTWTree alloc] initWithType:kTreeNode value:v arguments:nil]];
        }
        GTWTree* vlist  = [[GTWTree alloc] initWithType:kTreeList arguments:project];
        algebra = [[GTWTree alloc] initWithType:kAlgebraProject treeValue:vlist arguments:@[algebra]];
    }
    
    t   = [self peekNextNonCommentToken];
    if (t && t.type == KEYWORD) {
        id<GTWTerm> limit, offset;
        if ([t.value isEqual: @"LIMIT"]) {
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
        } else if ([t.value isEqual: @"OFFSET"]) {
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
            algebra = [[GTWTree alloc] initWithType:kAlgebraDistinct arguments:@[algebra]];
        }
        
        if (limit || offset) {
            if (!limit)
                limit   = [[GTWLiteral alloc] initWithValue:@"-1" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            if (!offset)
                offset   = [[GTWLiteral alloc] initWithValue:@"0" datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            algebra   = [[GTWTree alloc] initWithType:kAlgebraSlice arguments:@[
                          algebra,
                          [[GTWTree alloc] initLeafWithType:kTreeNode value: offset],
                          [[GTWTree alloc] initLeafWithType:kTreeNode value: limit],
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
    GTWSPARQLToken* t;
    BOOL allowTriplesBlock  = YES;
    while (ok) {
        t   = [self peekNextNonCommentToken];
        if (!t) {
            return [self errorMessage:@"Unexpected EOF in GroupGraphPatternSub" withErrors:errors];
        }
        GTWSPARQLTokenType type = t.type;
        
        id<GTWTree> algebra;
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
                    if ([t.value isEqual:@"A"]) {
                        if (!allowTriplesBlock)
                            break;
                        algebra = [self triplesByParsingTriplesBlockWithErrors:errors];
                        allowTriplesBlock   = NO;
                        ASSERT_EMPTY(errors);
                        if (!algebra)
                            return [self errorMessage:@"Could not parse TriplesBlock in GroupGraphPatternSub" withErrors:errors];
                        [args addObject:[self reduceTriplePaths: algebra]];
                    } else {
                        algebra = [self treeByParsingGraphPatternNotTriplesWithError:errors];
                        allowTriplesBlock   = YES;
                        ASSERT_EMPTY(errors);
                        if (!algebra)
                            return [self errorMessage:@"Could not parse GraphPatternNotTriples in GroupGraphPatternSub (2)" withErrors:errors];
                        [args addObject:algebra];
                        [self parseOptionalTokenOfType:DOT];
                    }
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
    
    if ([reordered count] == 1) {
        return reordered[0];
    } else {
        return [[GTWTree alloc] initWithType:kTreeList arguments:reordered];
    }
}

- (NSArray*) reorderTrees: (NSArray*) args errors:(NSMutableArray*) errors {
    NSMutableArray* reordered   = [NSMutableArray array];
    NSMutableArray* workItems   = [args mutableCopy];
    NSMutableArray* filters     = [NSMutableArray array];
    NSMutableArray* bgp         = [NSMutableArray array];
    while ([workItems count]) {
        id<GTWTree> t   = [workItems firstObject];
        [workItems removeObjectAtIndex:0];
        if (t.type == kTreeTriple || t.type == kTreePath) {
            [bgp addObject:t];
        } else if (t.type == kAlgebraExtend) {
            if (t.arguments && [t.arguments count]) {
                [bgp addObject:t];
            } else {
                id<GTWTree> pattern;
                if ([bgp count]) {
                    pattern = [[GTWTree alloc] initWithType:kTreeList arguments:bgp];
                    bgp         = [NSMutableArray array];
                } else if ([reordered count]) {
                    pattern = [reordered lastObject];
                    [reordered removeLastObject];
                } else {
                    pattern = [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
                }
                t.arguments = @[pattern];
                t   = [self algebraVerifyingExtend:t withErrors:errors];
                ASSERT_EMPTY(errors);
                [bgp addObject:t];
            }
        } else if (t.type == kAlgebraFilter) {
            if (t.arguments && [t.arguments count]) {
                [bgp addObject:t];
            } else {
                [filters insertObject:t atIndex:0];
            }
        } else if (t.type == kTreeList) {
            NSArray* children   = [self reorderTrees:t.arguments errors:errors];
            ASSERT_EMPTY(errors);
            t.arguments = children;
            [reordered addObject:t];
        } else {
            // wrap everything up from the left of this pattern
            if ([bgp count]) {
                id<GTWTree> pattern = [[GTWTree alloc] initWithType:kTreeList arguments:bgp];
                bgp         = [NSMutableArray array];
                while ([filters count]) {
                    id<GTWTree> filter  = [filters lastObject];
                    [filters removeLastObject];
                    filter.arguments = @[pattern];
                    pattern = [self algebraVerifyingExtend:filter withErrors:errors];
                    ASSERT_EMPTY(errors);
                }
                filters  = [NSMutableArray array];
                [reordered addObject:pattern];
            }
            
            if ((t.type == kAlgebraLeftJoin || t.type == kAlgebraMinus) && [t.arguments count] == 1) {
                // need to make the previous pattern the lhs of this optional/minus pattern
                id<GTWTree> pattern;
                if ([reordered count]) {
                    pattern = [reordered lastObject];
                    [reordered removeLastObject];
                } else {
                    pattern = [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
                }
                [self checkForSharedBlanksInPatterns:@[pattern, t.arguments[0]] error:errors];
                ASSERT_EMPTY(errors);
                t.arguments = @[pattern, t.arguments[0]];
                [reordered addObject:t];
            } else if (t.type == kAlgebraBGP || t.type == kAlgebraJoin || t.type == kAlgebraGraph || t.type == kAlgebraService || t.type == kAlgebraUnion || t.type == kAlgebraSlice || t.type == kAlgebraProject || t.type == kTreeResultSet || t.type == kAlgebraDistinct || t.type == kAlgebraReduced || t.type == kAlgebraLeftJoin || t.type == kAlgebraMinus) {
                [reordered addObject:t];
            } else {
                return [self errorMessage:[NSString stringWithFormat:@"unknown type of tree in GroupGraphPatternSub: %@", t] withErrors:errors];
            }
        }
    }
    if ([bgp count]) {
        id<GTWTree> pattern = [[GTWTree alloc] initWithType:kAlgebraBGP arguments:bgp];
        pattern = [self algebraByApplyingFilters:filters toAlgebra:pattern withErrors:errors];
        ASSERT_EMPTY(errors);
        [reordered addObject:pattern];
    }
    if ([filters count]) {
        id<GTWTree> ggp = [[GTWTree alloc] initWithType:kTreeList arguments:reordered];
        ggp             = [self algebraByApplyingFilters:filters toAlgebra:ggp withErrors:errors];
        ASSERT_EMPTY(errors);
        reordered   = [NSMutableArray arrayWithObject:ggp];
    }
    return reordered;
}

- (BOOL) checkForSharedBlanksInPatterns: (NSArray*) args error: (NSMutableArray*) errors {
    NSMutableSet* seen  = [NSMutableSet set];
    for (id<GTWTree> p in args) {
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

- (id<GTWTree>) algebraByApplyingFilters: (NSMutableArray*) filters toAlgebra: algebra withErrors: (NSMutableArray*) errors {
    if ([filters count] == 0) {
        return algebra;
    } else if ([filters count] == 1) {
        id<GTWTree> filter  = filters[0];
        filter.arguments    = @[algebra];
        [filters removeAllObjects];
        return filter;
    } else {
        NSMutableArray* exprs   = [NSMutableArray array];
        for (id<GTWTree> f in filters) {
            [exprs addObject:f.treeValue];
        }
        id<GTWTree> conj    = [[GTWTree alloc] initWithType:kExprAnd arguments:exprs];
        id<GTWTree> filter  = [[GTWTree alloc] initWithType:kAlgebraFilter treeValue: conj arguments:@[algebra]];
        [filters removeAllObjects];
        return filter;
    }
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

    id<GTWTree> list    = [[GTWTree alloc] initWithType:kTreeList arguments:@[expr, var]];
    id<GTWTree> bind    = [[GTWTree alloc] initWithType:kAlgebraExtend treeValue: list arguments:@[]];
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
        [self parseExpectedTokenOfType:RBRACE withErrors:errors];
        ASSERT_EMPTY(errors);
        
        NSMutableArray* results = [NSMutableArray array];
        for (id<GTWTree> value in values) {
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            id<GTWTree> key     = var;
            dict[key.value]     = value;
            id<GTWTree> result  = [[GTWTree alloc] initWithType:kTreeResult value:dict arguments:nil];
            [results addObject:result];
        }
        
        return [[GTWTree alloc] initWithType:kTreeResultSet arguments:results];
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
                if (![value isKindOfClass:[NSNull class]]) {
                    dict[key.value]   = value;
                }
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
    while ([self tokenIsTerm:t] || (t.type == KEYWORD && [t.value isEqual: @"UNDEF"])) {
        if (t.type == KEYWORD && [t.value isEqual: @"UNDEF"]) {
            [self nextNonCommentToken];
            [values addObject:[NSNull null]];
        } else {
            [self nextNonCommentToken];
            id<GTWTerm> term   = [self tokenAsTerm:t withErrors:errors];
            id<GTWTree> data    = [[GTWTree alloc] initWithType:kTreeNode value:term arguments:nil];
            ASSERT_EMPTY(errors);
            [values addObject:data];
        }
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
        id<GTWTree> subject = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTree> propertyObjectTriples = [self parsePropertyListPathNotEmptyForSubject:subject withErrors:errors];
        if (!propertyObjectTriples)
            return nil;
        [triples addObjectsFromArray:propertyObjectTriples.arguments];
        return triples;
    } else {
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
        t   = [self parseExpectedTokenOfType:KEYWORD withValue:@"A" withErrors:errors];
        ASSERT_EMPTY(errors);
        id<GTWTerm> term   = [self tokenAsTerm:t withErrors:errors];
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
    id<GTWTree> node   = nil;
    id<GTWTree> triples = [self parseGraphNodeAsNode:&node withErrors:errors];
    ASSERT_EMPTY(errors);
    // TODO: the triples parsed in graphnode go missing here
    return node;
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
        [self parseExpectedTokenOfType:SEMICOLON withErrors:errors];
        ASSERT_EMPTY(errors);
        t   = [self peekNextNonCommentToken];
        id<GTWTree> verb    = nil;
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
    ASSERT_EMPTY(errors);
    
    NSMutableArray* triples     = [NSMutableArray arrayWithArray:triplesTree.arguments];
    NSMutableArray* objects = [NSMutableArray arrayWithObject:node];
    
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t && t.type == COMMA) {
        [self nextNonCommentToken];

        id<GTWTree> triplesTree     = [self parseObjectPathAsNode:&node withErrors:errors];
        ASSERT_EMPTY(errors);
        [triples addObjectsFromArray:triplesTree.arguments];
        [objects addObject:node];
        t   = [self peekNextNonCommentToken];
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
        [self parseExpectedTokenOfType:KEYWORD withValue:@"A" withErrors:errors];
        id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else if (t.type == BANG) {
        [self parseExpectedTokenOfType:BANG withErrors:errors];
        id<GTWTree> path    = [self parsePathNegatedPropertySetWithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kPathNegate arguments:@[path]];
    } else {
        id<GTWTree> path    = [self parseIRIWithErrors:errors];
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
        
        // TODO: is this really optional? what sort of a path is '(' ')' ?
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
            id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            id<GTWTree> path    = [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
            return [[GTWTree alloc] initWithType:kPathInverse arguments:@[path]];
        } else {
            id<GTWTree> path    = [self parseIRIWithErrors: errors];
            return [[GTWTree alloc] initWithType:kPathInverse arguments:@[path]];
        }
    } else if (t.type == KEYWORD && [t.value isEqual: @"A"]) {
        [self nextNonCommentToken];
        id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        return [[GTWTree alloc] initWithType:kTreeNode value: term arguments:nil];
    } else {
        return [self parseIRIWithErrors: errors];
    }
}

// [98]  	TriplesNode	  ::=  	Collection |	BlankNodePropertyList
- (id<GTWTree>) parseTriplesNodeAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == LPAREN) {
        return [self triplesByParsingCollectionAsNode: (id<GTWTree>*) node withErrors: errors];
    } else {
        NSArray* plist  = [self propertyObjectPairsByParsingBlankNodePropertyListAsNode:node WithErrors:errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kTreeList arguments:plist];
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

//[102]  	Collection	  ::=  	'(' GraphNode+ ')'
- (id<GTWTree>) triplesByParsingCollectionAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> graphNodePath    = [self parseGraphNodeAsNode: node withErrors:errors];
    NSMutableArray* triples = [NSMutableArray arrayWithArray:graphNodePath.arguments];
    NSMutableArray* nodes   = [NSMutableArray arrayWithObject:*node];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type != RPAREN) {
        id<GTWTree> graphNodePath    = [self parseGraphNodeAsNode: node withErrors:errors];
        ASSERT_EMPTY(errors);
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

// [103]  	CollectionPath	  ::=  	'(' GraphNodePath+ ')'
- (id<GTWTree>) triplesByParsingCollectionPathAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    [self parseExpectedTokenOfType:LPAREN withErrors:errors];
    ASSERT_EMPTY(errors);
    id<GTWTree> graphNodePath    = [self parseGraphNodePathAsNode:node withErrors:errors];
    ASSERT_EMPTY(errors);
    NSMutableArray* triples = [NSMutableArray arrayWithArray:graphNodePath.arguments];
    if (!(*node)) {
        NSLog(@"no node in collection path");
    }
    NSMutableArray* nodes   = [NSMutableArray arrayWithObject:*node];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    while (t.type != RPAREN) {
        id<GTWTree> graphNodePath    = [self parseGraphNodePathAsNode:node withErrors:errors];
        ASSERT_EMPTY(errors);
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
            id<GTWTree> ttree   = [[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
            if (!ttree) {
                return [self errorMessage:@"(1) no triple tree" withErrors:errors];
            }
            [triples addObject:ttree];
            if (i == [nodes count]-1) {
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:rdfnil];
                id<GTWTree> ttree   = [[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(2) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
            } else {
                GTWBlank* newbnode  = self.bnodeIDGenerator(nil);
                id<GTWTree> newlist = [[GTWTree alloc] initWithType:kTreeNode value: newbnode arguments:nil];
                GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdfrest object:newlist.value];
                id<GTWTree> ttree   = [[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
                if (!ttree) {
                    return [self errorMessage:@"(3) no triple tree" withErrors:errors];
                }
                [triples addObject:ttree];
                list    = newlist;
            }
        }
    } else {
        GTWTriple* triple   = [[GTWTriple alloc] initWithSubject:list.value predicate:rdffirst object:rdfnil];
        id<GTWTree> ttree   = [[GTWTree alloc] initWithType:kTreeTriple value:triple arguments:nil];
        if (!ttree) {
            return [self errorMessage:@"(4) no triple tree" withErrors:errors];
        }
        [triples addObject:ttree];
    }
    
    return [[GTWTree alloc] initWithType:kTreeList arguments:triples];
}

// [104]  	GraphNode	  ::=  	VarOrTerm |	TriplesNode
- (id<GTWTree>) parseGraphNodeAsNode: (id<GTWTree>*) node withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if ([self tokenIsVarOrTerm:t]) {
        *node   = [self parseVarOrTermWithErrors: errors];
        ASSERT_EMPTY(errors);
        return [[GTWTree alloc] initWithType:kTreeList arguments:@[]];
    } else {
        return [self parseTriplesNodeAsNode:node withErrors:errors];
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

- (BOOL) tokenIsVarOrTerm: (GTWSPARQLToken*) t {
    if ([self tokenIsTerm:t])
        return YES;
    if (t.type == VAR)
        return YES;
    if (t.type == KEYWORD && [t.value isEqualToString:@"A"])
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
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    return [[GTWTree alloc] initWithType:kTreeNode value:t arguments:nil];
}

// [107]  	VarOrIri	  ::=  	Var | iri
- (id<GTWTree>) parseVarOrIRIWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    GTWTermType type    = [t termType];
    if (type == GTWTermVariable || type == GTWTermIRI) {
        return [[GTWTree alloc] initWithType:kTreeNode value: t arguments:nil];
    } else {
        return [self errorMessage:[NSString stringWithFormat:@"Expected Var or IRI, but found %@", t] withErrors:errors];
    }
}

// [108]  	Var	  ::=  	VAR1 | VAR2
- (id<GTWTree>) parseVarWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    
    GTWTermType type    = [t termType];
    if (type == GTWTermVariable) {
        return [[GTWTree alloc] initWithType:kTreeNode value: t arguments:nil];
    } else {
        return [self errorMessage:[NSString stringWithFormat:@"Expected Var, but found %@", t] withErrors:errors];
    }
}

// [110]  	Expression	  ::=  	ConditionalOrExpression
- (id<GTWTree>) parseExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseConditionalOrExpressionWithErrors:errors];
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
    return expr;
}

//[113]  	ValueLogical	  ::=  	RelationalExpression
- (id<GTWTree>) parseValueLogicalWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseRelationalExpressionWithErrors:errors];
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
    return expr;
}

//[115]  	NumericExpression	  ::=  	AdditiveExpression
- (id<GTWTree>) parseNumericExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseAdditiveExpressionWithErrors:errors];
    return expr;
}

//[116]  	AdditiveExpression	  ::=  	MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )* )*
- (id<GTWTree>) parseAdditiveExpressionWithErrors: (NSMutableArray*) errors {
    id<GTWTree> expr    = [self parseMultiplicativeExpressionWithErrors:errors];
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    
    // TODO: handle ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )*
    while (t && (t.type == PLUS || t.type == MINUS)) {
        [self nextNonCommentToken];
        id<GTWTree> rhs  = [self parseMultiplicativeExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        expr    = [[GTWTree alloc] initWithType:(t.type == PLUS ? kExprPlus : kExprMinus) arguments:@[expr, rhs]];
        t   = [self peekNextNonCommentToken];
    }
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
        if (t.type == NIL || t.type == ANON || t.type == BNODE) {
            return [self errorMessage:[NSString stringWithFormat:@"Expected PrimaryExpression term (IRI, Literal, or Var) but found %@", t] withErrors:errors];
        }
        id<GTWTree> expr    = [self parseVarOrTermWithErrors:errors];
        ASSERT_EMPTY(errors);
        return expr;
    } else {
        return [self parseBuiltInCallWithErrors:errors];
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
        
        t   = [self peekNextNonCommentToken];
        if (t.type == RPAREN) {
            [self parseExpectedTokenOfType:RPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            id<GTWTree> func    = [[GTWTree alloc] initWithType:kExprFunction value:iri.value arguments:@[]];
            return func;
        } else {
            // distinct flag isn't currently used in the algebra tree, because no functions actually make use of it.
            [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
            id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            if (!expr) {
                NSLog(@"no expression in parseIRIOrFunctionWithErrors:");
            }
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
        }
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
    if (t.type == KEYWORD && agg_range.location == 0 && ((![t.value isEqual:@"MINUTES"]))) {    // the length check is in case we've mistaken a longer token (e.g. MINUTES) for MIN here
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
        NSMutableArray* arguments   = [NSMutableArray array];
        t   = [self parseOptionalTokenOfType:NIL];
        if (!t) {
            [self parseExpectedTokenOfType:LPAREN withErrors:errors];
            ASSERT_EMPTY(errors);
            id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
            ASSERT_EMPTY(errors);
            [arguments addObject:expr];
            
            t   = [self parseOptionalTokenOfType:COMMA];
            while (t) {
                id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
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
        GTWTreeType functype    = [funcdict objectForKey:funcname];
        if (functype == kExprIRI) {
            id<GTWTree> base    = [[GTWTree alloc] initWithType:kTreeNode value:self.baseIRI arguments:nil];
            [arguments addObject:base];
        }
        id<GTWTree> func    = [[GTWTree alloc] initWithType:functype arguments:arguments];
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
- (id<GTWTree>) parseAggregateWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
    ASSERT_EMPTY(errors);
    if ([t.value isEqual: @"COUNT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
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
        [self addSeenAggregate:agg];
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
        [self addSeenAggregate:agg];
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
        [self addSeenAggregate:agg];
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
        [self addSeenAggregate:agg];
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
        [self addSeenAggregate:agg];
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
        [self addSeenAggregate:agg];
        return agg;
    } else if ([t.value isEqual: @"GROUP_CONCAT"]) {
        [self parseExpectedTokenOfType:LPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        GTWSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
        id<GTWTree> expr    = [self parseExpressionWithErrors:errors];
        ASSERT_EMPTY(errors);
        
        GTWSPARQLToken* sc  = [self parseOptionalTokenOfType:SEMICOLON];
        NSString* separator = @" ";
        if (sc) {
            [self parseExpectedTokenOfType:KEYWORD withValue:@"SEPARATOR" withErrors:errors];
            ASSERT_EMPTY(errors);
            [self parseExpectedTokenOfType:EQUALS withErrors:errors];
            ASSERT_EMPTY(errors);
            GTWSPARQLToken* t   = [self nextNonCommentToken];
            id<GTWTerm> str     = [self tokenAsTerm:t withErrors:errors];
            ASSERT_EMPTY(errors);
            
            separator   = str.value;
        }
        id<GTWTree> agg     = [[GTWTree alloc] initWithType:kExprGroupConcat value: @[@(d ? YES : NO), separator] arguments:@[expr]];
        [self parseExpectedTokenOfType:RPAREN withErrors:errors];
        ASSERT_EMPTY(errors);
        [self addSeenAggregate:agg];
        return agg;
    }
    return nil;
}

- (id<GTWTree>) parseIRIWithErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* token     = [self nextNonCommentToken];
    id<GTWTerm> t   = [self tokenAsTerm:token withErrors:errors];
    ASSERT_EMPTY(errors);
    
    if (![t isKindOfClass:[GTWIRI class]]) {
        return [self errorMessage:[NSString stringWithFormat:@"Expected IRI but found %@", t] withErrors:errors];
    }
    
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
        [self parseExpectedTokenOfType:DOT withErrors:errors];
        ASSERT_EMPTY(errors);
        
        t   = [self peekNextNonCommentToken];
        // TODO: Check if TriplesBlock can be parsed (it's more than just tokenIsVarOrTerm:)
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
}

// [56]  	GraphPatternNotTriples	  ::=  	GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
- (id<GTWTree>) treeByParsingGraphPatternNotTriplesWithError: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self peekNextNonCommentToken];
    if (t.type == KEYWORD) {
        NSString* kw    = t.value;
        if ([kw isEqual:@"OPTIONAL"]) {
            // 'OPTIONAL' GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            if (ggp.type == kAlgebraFilter) {
                id<GTWTree> expr    = ggp.treeValue;
                return [[GTWTree alloc] initWithType:kAlgebraLeftJoin treeValue: expr arguments:[ggp.arguments copy]];
            } else {
                return [[GTWTree alloc] initWithType:kAlgebraLeftJoin arguments:@[ggp]];
            }
        } else if ([kw isEqual:@"MINUS"]) {
            // 'MINUS' GroupGraphPattern
            [self nextNonCommentToken];
            id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
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
            id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            id<GTWTree> graph   = [[GTWTree alloc] initWithType:kTreeNode value:g arguments:nil];
            
            NSMutableArray* list    = [NSMutableArray arrayWithObject:graph];
            if (ggp.type == kAlgebraFilter) {
                id<GTWTree> filterExpr  = ggp.treeValue;
                [list addObject:filterExpr];
                ggp     = ggp.arguments[0];
            }
            
            id<GTWTree> graphAndFilter   = [[GTWTree alloc] initWithType:kTreeList arguments:list];
            id<GTWTree> graphPattern    = [[GTWTree alloc] initWithType:kAlgebraGraph treeValue: graphAndFilter arguments:@[ggp]];
            return graphPattern;
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
            
            id<GTWTree> graph   = [[GTWTree alloc] initWithType:kTreeNode value:g arguments:nil];
            id<GTWTree> silentFlag  = [[GTWTree alloc] initWithType:kTreeNode value:(silent ? [GTWLiteral trueLiteral] : [GTWLiteral falseLiteral]) arguments:nil];
            id<GTWTree> graphAndSilent   = [[GTWTree alloc] initWithType:kTreeList arguments:@[graph, silentFlag]];
            id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            if (!ggp)
                return nil;
            return [[GTWTree alloc] initWithType:kAlgebraService treeValue: graphAndSilent arguments:@[ggp]];
        } else if ([kw isEqual:@"FILTER"]) {
            [self nextNonCommentToken];
            id<GTWTree> f   = [self parseConstraintWithErrors:errors];
            ASSERT_EMPTY(errors);
            return [[GTWTree alloc] initWithType:kAlgebraFilter treeValue: f arguments:nil];
        } else if ([kw isEqual:@"VALUES"]) {
            return [self parseInlineDataWithErrors: errors];
        } else if ([kw isEqual:@"BIND"]) {
            return [self parseBindWithErrors: errors];
        } else {
            return [self errorMessage:[NSString stringWithFormat:@"Unexpected KEYWORD %@ while expecting GraphPatternNotTriples", t.value] withErrors:errors];
        }
    } else if (t.type == LBRACE) {
        // GroupGraphPattern ( 'UNION' GroupGraphPattern )*
        id<GTWTree> ggp = [self parseGroupGraphPatternWithError:errors];
        ASSERT_EMPTY(errors);
        if (!ggp) {
            return nil;
        }
        
        t   = [self parseOptionalTokenOfType:KEYWORD withValue:@"UNION"];
        while (t) {
            id<GTWTree> rhs = [self parseGroupGraphPatternWithError:errors];
            ASSERT_EMPTY(errors);
            [self checkForSharedBlanksInPatterns:@[ggp, rhs] error:errors];
            ASSERT_EMPTY(errors);
            ggp = [[GTWTree alloc] initWithType:kAlgebraUnion arguments:@[ggp, rhs]];
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


- (GTWSPARQLToken*) parseExpectedTokenOfType: (GTWSPARQLTokenType) type withErrors: (NSMutableArray*) errors {
    GTWSPARQLToken* t   = [self nextNonCommentToken];
    if (!t)
        return nil;
    if (t.type != type) {
        NSString* reason    = [NSString stringWithFormat:@"Expecting %@ but found %@", [GTWSPARQLToken nameOfSPARQLTokenOfType:type], t];
        return [self errorMessage:reason withErrors:errors];
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

- (NSSet*) aggregatesForCurrentQuery {
    NSMutableSet* set   = [self.aggregateSets lastObject];
    return [set copy];
}

- (void) addSeenAggregate: (id<GTWTree>) agg {
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
}

- (BOOL) haveSubject {
    return ([self.stack count] > 0);
}

- (void) pushNewSubject: (id<GTWTerm>) subj {
    NSMutableArray* preds   = [[NSMutableArray alloc] init];
    NSArray* pair   = @[subj, preds];
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
