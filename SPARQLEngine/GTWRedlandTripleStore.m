#import "GTWRedlandTripleStore.h"
#import "GTWIRI.h"
#import "GTWBlank.h"
#import "GTWLiteral.h"

@implementation GTWRedlandTripleStore

- (GTWRedlandTripleStore*) initWithName: (NSString*) name redlandPtr: (librdf_world*) librdf_world_ptr {
    if (self = [self init]) {
        librdf_storage* storage     = librdf_new_storage(librdf_world_ptr, "trees", [name UTF8String], "new='yes'");
        self.librdf_world_ptr       = librdf_world_ptr;
        self.model	= librdf_new_model(librdf_world_ptr, storage, NULL);
        return self;
    }
    return self;
}

- (GTWRedlandTripleStore*) initWithStore: (librdf_storage*) storage redlandPtr: (librdf_world*) librdf_world_ptr {
    if (self = [self init]) {
        self.librdf_world_ptr       = librdf_world_ptr;
        self.model                  = librdf_new_model(librdf_world_ptr, storage, NULL);
        return self;
    }
    return self;
}

- (void) dealloc {
    NSLog(@"cleaning up librdf storage...");
    librdf_free_model(self.model);
    return;
}

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSMutableArray* array   = [NSMutableArray array];
    [self enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<Triple>t){
        [array addObject:t];
    } error:error];
    return nil;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<Triple> t)) block error:(NSError **)error {
    NSMutableString* queryString    = [NSMutableString stringWithString:@"SELECT * WHERE { "];
    if (s) {
        [queryString appendFormat:@"%@ ", s];
    } else {
        [queryString appendFormat:@"?subject "];
    }

    if (s) {
        [queryString appendFormat:@"%@ ", p];
    } else {
        [queryString appendFormat:@"?predicate "];
    }

    if (o) {
        [queryString appendFormat:@"%@ ", o];
    } else {
        [queryString appendFormat:@"?object "];
    }
    
    [queryString appendFormat:@" }"];
	librdf_query* query	= librdf_new_query(self.librdf_world_ptr, "sparql", NULL, (unsigned const char*) [queryString UTF8String], NULL);
	librdf_query_results* results	= librdf_model_query_execute(self.model, query);
    while (!librdf_query_results_finished(results)) {
        const char **names=NULL;
        librdf_node* values[10];
        if (librdf_query_results_get_bindings(results, &names, values)) {
            NSLog(@"librdf get_bindings failed");
            return NO;
        }
        
        if (names) {
            GTWTriple* t    = [[GTWTriple alloc] init];
            if (s) {
                t.subject   = s;
            }
            if (p) {
                t.predicate = p;
            }
            if (o) {
                t.object    = o;
            }
            int i;
            for(i=0; names[i]; i++) {
                id<GTWTerm> term;
                const char* name	= names[i];
                //				fprintf(stdout, "%s=", names[i]);
                if(values[i]) {
                    librdf_node_type type	= librdf_node_get_type(values[i]);
                    librdf_uri* uri;
                    unsigned char* value;
                    char* lang;
                    switch (type) {
                        case LIBRDF_NODE_TYPE_RESOURCE:
                            uri		= librdf_node_get_uri(values[i]);
                            term    = [[GTWIRI alloc] initWithIRI:[NSString stringWithCString:(const char*) librdf_uri_as_string(uri) encoding:NSUTF8StringEncoding]];
                            break;
                        case LIBRDF_NODE_TYPE_LITERAL:
                            value	= librdf_node_get_literal_value(values[i]);
                            if ((lang = librdf_node_get_literal_value_language(values[i]))) {
                                term    = [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding] language:[NSString stringWithCString:lang encoding:NSUTF8StringEncoding]];
                            } else if ((uri = librdf_node_get_literal_value_datatype_uri(values[i]))) {
                                term    = [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding] datatype:[NSString stringWithCString:(const char*) raptor_uri_as_string(uri) encoding:NSUTF8StringEncoding]];
                            } else {
                                term    = [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding]];
                            }
                            break;
                        case LIBRDF_NODE_TYPE_BLANK:
                            term    = [[GTWBlank alloc] initWithID:[NSString stringWithCString:(const char*) librdf_node_get_blank_identifier(values[i]) encoding:NSUTF8StringEncoding]];
                            break;
                        default:
                            break;
                    }
                    
                    if (term != NULL) {
                        [t setValue:term forKey:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]];
//                        int var	= gtw_execution_context_variable_number(t->ctx, name);
//                        gtw_solution_set_mapping(r, var, n);
                    }
                    //					librdf_node_print(values[i], stdout);
                    librdf_free_node(values[i]);
                }
                //					else
                //					fputs("NULL", stdout);
                //				if(names[i+1])
                //					fputs(", ", stdout);
            }
            block(t);
        }
        
        librdf_query_results_next(results);
    }
    
    return YES;
}

- (NSEnumerator*) tripleEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSArray* triples    = [self getTriplesMatchingSubject:s predicate:p object:o error:error];
    return [triples objectEnumerator];
}

- (BOOL) addTriple: (id<Triple>) t error:(NSError **)error {
    librdf_node *s  = [self objectToRaptorTerm:t.subject];
    librdf_node *p  = [self objectToRaptorTerm:t.predicate];
    librdf_node *o  = [self objectToRaptorTerm:t.object];
    librdf_model_add(self.model, s, p, o);
    return YES;
}

- (BOOL) removeTriple: (id<Triple>) t error:(NSError **)error {
    librdf_node *s  = [self objectToRaptorTerm:t.subject];
    librdf_node *p  = [self objectToRaptorTerm:t.predicate];
    librdf_node *o  = [self objectToRaptorTerm:t.object];
    librdf_statement* st    = librdf_new_statement_from_nodes(self.librdf_world_ptr, s, p, o);
    librdf_model_remove_statement(self.model, st);
    return YES;
}

- (id<GTWTerm>) raptorTermToObject: (librdf_node*) term {
    librdf_node_type type	= librdf_node_get_type(term);
    librdf_uri* uri;
    unsigned char* value;
    char* lang;
    switch (type) {
        case LIBRDF_NODE_TYPE_RESOURCE:
            uri		= librdf_node_get_uri(term);
            return [[GTWIRI alloc] initWithIRI:[NSString stringWithCString:(const char*) librdf_uri_as_string(uri) encoding:NSUTF8StringEncoding]];
        case LIBRDF_NODE_TYPE_LITERAL:
            value	= librdf_node_get_literal_value(term);
            if ((lang = librdf_node_get_literal_value_language(term))) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding] language:[NSString stringWithCString:lang encoding:NSUTF8StringEncoding]];
            } else if ((uri = librdf_node_get_literal_value_datatype_uri(term))) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding] datatype:[NSString stringWithCString:(const char*) raptor_uri_as_string(uri) encoding:NSUTF8StringEncoding]];
            } else {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*) value encoding:NSUTF8StringEncoding]];
            }
            break;
        case LIBRDF_NODE_TYPE_BLANK:
            return [[GTWBlank alloc] initWithID:[NSString stringWithCString:(const char*) librdf_node_get_blank_identifier(term) encoding:NSUTF8StringEncoding]];
            break;
        default:
            break;
    }
    return nil;
}

- (librdf_node*) objectToRaptorTerm: (id<GTWTerm>) term {
    if ([term isKindOfClass:[GTWIRI class]]) {
        return librdf_new_node_from_uri_string(self.librdf_world_ptr, (const unsigned char*) [[term value] UTF8String]);
    } else if ([term isKindOfClass:[GTWLiteral class]]) {
        GTWLiteral* l   = (GTWLiteral*) term;
        if (l.datatype) {
            librdf_uri* dt  = librdf_new_uri(self.librdf_world_ptr, (const unsigned char*) [[l datatype] UTF8String]);
            return librdf_new_node_from_typed_literal(self.librdf_world_ptr, (const unsigned char*) [[l value] UTF8String], NULL, dt);
        } else {
            return librdf_new_node_from_literal(self.librdf_world_ptr, (const unsigned char*) [[l value] UTF8String], [[l language] UTF8String], 0);
        }
    } else if ([term isKindOfClass:[GTWBlank class]]) {
        return librdf_new_node_from_blank_identifier(self.librdf_world_ptr, (const unsigned char*) [[term value] UTF8String]);
    } else {
        return nil;
    }
}

- (NSString*) description {
    NSLog(@"librdf world: %p\n", self.librdf_world_ptr);
    librdf_serializer* s    = librdf_new_serializer(self.librdf_world_ptr, NULL, NULL, NULL);
    NSLog(@"librdf serializer: %p\n", s);
    librdf_uri* base        = librdf_new_uri(self.librdf_world_ptr, (const unsigned char*) "http://base/");
    unsigned char* ttl      = librdf_serializer_serialize_model_to_string(s, base, self.model);
    NSString* string        = [NSString stringWithCString:(const char*) ttl encoding:NSUTF8StringEncoding];
    librdf_free_uri(base);
    librdf_free_serializer(s);
    return string;
}

@end
