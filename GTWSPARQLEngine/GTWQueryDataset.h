#import <Foundation/Foundation.h>
#import "GTWSPARQLEngine.h"

@interface GTWQueryDataset : NSObject<GTWQueryDataset>

typedef NS_ENUM(NSInteger, GTWQueryDatasetAvailability) {
    GTWFullDataset,
    GTWRestrictedDataset
};

@property GTWQueryDatasetAvailability availabilityType;
@property NSMutableArray* defaultGraphsStack;
@property NSArray* graphs;

- (GTWQueryDataset*) initDatasetWithDefaultGraphs: (NSArray*) defaultGraphs;
- (GTWQueryDataset*) initDatasetWithDefaultGraphs: (NSArray*) defaultGraphs restrictedToGraphs: (NSArray*) graphs;
- (NSArray*) defaultGraphs;
- (NSArray*) availableGraphsFromModel: (id<GTWModel>) model;

@end
