#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import <GTWSWBase/GTWTriple.h>
#include <redland.h>

@interface SPKRedlandTripleStore : NSObject<GTWTripleStore, GTWMutableTripleStore>

@property librdf_model* model;
@property librdf_world* librdf_world_ptr;
@property id<GTWLogger> logger;

- (SPKRedlandTripleStore*) initWithName: (NSString*) name redlandPtr: (librdf_world*) librdf_world_ptr;
- (SPKRedlandTripleStore*) initWithStore: (librdf_storage*) store redlandPtr: (librdf_world*) librdf_world_ptr;

@end
