#import "GTWRedlandParser.h"
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWBlank.h>

static id<GTWTerm> raptorTermToObject (raptor_term* term) {
    raptor_term_type type   = term->type;
    switch (type) {
        case RAPTOR_TERM_TYPE_BLANK:
            return [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"%s", term->value.blank.string]];
        case RAPTOR_TERM_TYPE_LITERAL:
            if (term->value.literal.datatype) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*)term->value.literal.string encoding:NSUTF8StringEncoding] datatype:[NSString stringWithFormat:@"%s", raptor_uri_as_string(term->value.literal.datatype)]];
            } else if (term->value.literal.language) {
                return [[GTWLiteral alloc] initWithString:[NSString stringWithCString:(const char*)term->value.literal.string encoding:NSUTF8StringEncoding] language:[NSString stringWithFormat:@"%s", term->value.literal.language]];
            } else {
                return [[GTWLiteral alloc] initWithValue:[NSString stringWithCString:(const char*)term->value.literal.string encoding:NSUTF8StringEncoding]];
            }
        case RAPTOR_TERM_TYPE_URI:
            return [[GTWIRI alloc] initWithIRI:[NSString stringWithFormat:@"%s", raptor_uri_as_string(term->value.uri)]];
        default:
            return nil;
    }
}

void message_handler(void *user_data, raptor_log_message* message) {
    if (user_data) {
        void(^block)(raptor_log_message*)        = (__bridge void(^)(raptor_log_message*)) user_data;
        block(message);
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

- (GTWRedlandParser*) initWithData: (NSData*) data inFormat: (NSString*) format base: (id<GTWIRI>) base WithRaptorWorld: (raptor_world*) raptor_world_ptr {
    if (self = [super init]) {
        if (!base) {
            base    = [[GTWIRI alloc] initWithValue:@"http://base.example.com/"];
        }
        self.baseURI            = base;
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
    void* user_data         = (__bridge void*) block;
    raptor_parser_set_statement_handler(self.parser, user_data, statement_handler);
    __block NSError* _error = nil;
    @synchronized([self class]) {
        void(^errorHandler)(raptor_log_message*)   = ^(raptor_log_message* message){
            NSMutableString* desc   = [NSMutableString stringWithFormat:@"%s", message->text];
            if (message->locator) {
                [desc appendFormat:@" at "];
                if (message->locator->file) {
                    [desc appendFormat:@"%s ", message->locator->file];
//                } else if (message->locator->uri) {
//                    [desc appendFormat:@"%s ", raptor_uri_as_string(message->locator->uri)];
                } else {
//                    [desc appendFormat:@" "];
                }
                [desc appendFormat:@"(line %d, column %d)", message->locator->line, message->locator->column];
            }
            _error  = [NSError errorWithDomain:@"us.kasei.sparql.parser.redland" code:message->code userInfo:@{@"description": desc}];
        };
        raptor_world_set_log_handler(self.raptor_world_ptr, (__bridge void*) errorHandler, message_handler);
        raptor_uri* base_uri    = raptor_new_uri(self.raptor_world_ptr, (const unsigned char*) [self.baseURI.value UTF8String]);
    //    const unsigned char *buffer;
    //    size_t buffer_len;
        
        raptor_parser_parse_start(self.parser, base_uri);
        
        if (self.data) {
            raptor_parser_parse_chunk(self.parser, [self.data bytes], [self.data length], 0);
        }
        
        raptor_parser_parse_chunk(self.parser, NULL, 0, 1); /* no data and is_end = 1 */
    }
    raptor_world_set_log_handler(self.raptor_world_ptr, nil, message_handler);
    
    if (_error) {
        if (error) {
            *error  = _error;
        }
        return NO;
    } else {
        return YES;
    }
}

@end
