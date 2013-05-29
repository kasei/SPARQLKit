#import <Foundation/Foundation.h>
#import "GTWTree.h"
#include <raptor2.h>
#include <rasqal/rasqal.h>
#import "GTWSPARQLEngine.h"

@interface GTWRasqalSPARQLParser : NSObject<GTWSPARQLParser>

@property rasqal_world* rasqal_world_ptr;

- (GTWRasqalSPARQLParser*) initWithRasqalWorld: (rasqal_world*) rasqal_world_ptr;
- (GTWTree*) parserSPARQL: (NSString*) queryString withBaseURI: (NSString*) base;

@end
