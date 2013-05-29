#include <libxml/parser.h>
#include <raptor2.h>
#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWSPARQLProtocolStore : NSObject<GTWTripleStore>

@property id<GTWLogger> logger;
@property NSString* endpoint;

- (GTWSPARQLProtocolStore*) initWithEndpoint: (NSString*) endpoint;

@end
