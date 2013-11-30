#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

@interface SPKMemoryQuadStore : NSObject<GTWQuadStore,GTWMutableQuadStore>

@property id<GTWLogger> logger;
@property NSMutableSet* quads;
@property dispatch_queue_t queue;
@property NSMutableDictionary* indexes;
@property NSMutableDictionary* indexKeys;

- (BOOL) addIndexType: (NSString*) type value: (NSArray*) positions synchronous: (BOOL) sync error: (NSError*__autoreleasing*) error;
- (NSString*) bestIndexForMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g;

@end
