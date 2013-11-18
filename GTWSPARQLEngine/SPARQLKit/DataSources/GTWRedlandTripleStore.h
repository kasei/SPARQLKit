#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"
#import <GTWSWBase/GTWTriple.h>
#include <redland.h>

@interface GTWRedlandTripleStore : NSObject<GTWTripleStore, GTWMutableTripleStore>

@property librdf_model* model;
@property librdf_world* librdf_world_ptr;
@property id<GTWLogger> logger;

- (GTWRedlandTripleStore*) initWithName: (NSString*) name redlandPtr: (librdf_world*) librdf_world_ptr;
- (GTWRedlandTripleStore*) initWithStore: (librdf_storage*) store redlandPtr: (librdf_world*) librdf_world_ptr;

@end
