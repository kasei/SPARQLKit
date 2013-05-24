#import "GTWRedlandParser.h"
#import "GTWTriple.h"
#import "GTWIRI.h"
#import "GTWLiteral.h"
#import "GTWBlank.h"

static id<GTWTerm> raptorTermToObject (raptor_term* term) {
    raptor_term_type type   = term->type;
    switch (type) {
        case RAPTOR_TERM_TYPE_BLANK:
            return [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"%s", term->value.blank.string]];
        case RAPTOR_TERM_TYPE_LITERAL:
            if (term->value.literal.datatype) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%s", term->value.literal.string] datatype:[NSString stringWithFormat:@"%s", raptor_uri_as_string(term->value.literal.datatype)]];
            } else if (term->value.literal.language) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%s", term->value.literal.string] language:[NSString stringWithFormat:@"%s", term->value.literal.language]];
            } else {
                return [[GTWLiteral alloc] initWithValue:[NSString stringWithFormat:@"%s", term->value.literal.string]];
            }
        case RAPTOR_TERM_TYPE_URI:
            return [[GTWIRI alloc] initWithIRI:[NSString stringWithFormat:@"%s", raptor_uri_as_string(term->value.uri)]];
        default:
            return nil;
    }
}

static void statement_handler(void* user_data, raptor_statement* statement) {
    id<GTWTerm> s   = raptorTermToObject(statement->subject);
    id<GTWTerm> p   = raptorTermToObject(statement->predicate);
    id<GTWTerm> o   = raptorTermToObject(statement->object);
    void(^block)(id<GTWTriple>)        = (__bridge void(^)(id<GTWTriple>)) user_data;
    if (s && p && o) {
        id<GTWTriple> t    = [[GTWTriple alloc] initWithSubject:s predicate:p object:o];
        block(t);
    }
    /* do something with the statement */
}

@implementation GTWRedlandParser

- (GTWRedlandParser*) initWithData: (NSData*) data inFormat: (NSString*) format WithRaptorWorld: (raptor_world*) raptor_world_ptr {
    if (self = [super init]) {
        self.baseURI            = @"http://base.example.com/";
        self.data               = data;
        self.raptor_world_ptr   = raptor_world_ptr;
        self.parser             = raptor_new_parser(raptor_world_ptr, [format UTF8String]);
    }
    return self;
}

- (void) dealloc {
    raptor_free_parser(self.parser);
}

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    void* user_data         = (__bridge void*) block;;
    raptor_parser_set_statement_handler(self.parser, user_data, statement_handler);
    
    raptor_uri* base_uri    = raptor_new_uri(self.raptor_world_ptr, (const unsigned char*) [self.baseURI UTF8String]);
//    const unsigned char *buffer;
//    size_t buffer_len;
    
    raptor_parser_parse_start(self.parser, base_uri);
    
    if (self.data) {
        raptor_parser_parse_chunk(self.parser, [self.data bytes], [self.data length], 0);
    }
    
    raptor_parser_parse_chunk(self.parser, NULL, 0, 1); /* no data and is_end = 1 */
    return YES;
}

@end
