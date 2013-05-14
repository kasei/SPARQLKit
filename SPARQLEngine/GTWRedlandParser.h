#import <Foundation/Foundation.h>
#import "SPARQLEngine.h"
#include <raptor2.h>

@interface GTWRedlandParser : NSObject<GTWRDFParser>

@property raptor_world* raptor_world_ptr;
@property raptor_parser* parser;
@property (retain) NSData* data;
@property (retain) NSFileHandle* fh;
@property (retain, readwrite) NSString* baseURI;
//@property (copy) void(^handler)(id<Triple>t);

- (GTWRedlandParser*) initWithData: (NSData*) data inFormat: (NSString*) format WithRaptorWorld: (raptor_world*) raptor_world_ptr;

@end
