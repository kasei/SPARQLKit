#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#include <raptor2.h>

@interface SPKRedlandParser : NSObject<GTWRDFParser>

@property raptor_world* raptor_world_ptr;
@property raptor_parser* parser;
@property (retain) NSData* data;
@property (retain) NSFileHandle* fh;
@property (retain, readwrite) GTWIRI* baseURI;
//@property (copy) void(^handler)(id<Triple>t);

- (SPKRedlandParser*) initWithData: (NSData*) data inFormat: (NSString*) format base: (id<GTWIRI>) base WithRaptorWorld: (raptor_world*) raptor_world_ptr;

@end
