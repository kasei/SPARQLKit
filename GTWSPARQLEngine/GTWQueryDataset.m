#import "GTWQueryDataset.h"
#import "GTWSPARQLEngine.h"

@implementation GTWQueryDataset

- (GTWQueryDataset*) initDatasetWithDefaultGraphs: (NSArray*) defaultGraphs {
    if (self = [super init]) {
        self.availabilityType   = GTWFullDataset;
        self.graphs             = nil;
        self.defaultGraphsStack = [NSMutableArray array];
        [self.defaultGraphsStack addObject:defaultGraphs];
    }
    return self;
}

- (GTWQueryDataset*) initDatasetWithDefaultGraphs: (NSArray*) defaultGraphs restrictedToGraphs: (NSArray*) graphs {
    if (self = [super init]) {
        self.availabilityType   = GTWRestrictedDataset;
        self.graphs             = graphs;
        self.defaultGraphsStack = [NSMutableArray array];
        [self.defaultGraphsStack addObject:defaultGraphs];
    }
    return self;
}

- (NSArray*) defaultGraphs {
    return [self.defaultGraphsStack lastObject];
}

- (void) pushDefaultGraphs: (NSArray*) graphs {
    [self.defaultGraphsStack addObject:graphs];
}

- (void) popDefaultGraphs {
    [self.defaultGraphsStack removeLastObject];
}

- (NSArray*) availableGraphsFromModel: (id<GTWModel>) model {
    if (self.availabilityType == GTWFullDataset) {
        NSMutableArray* graphs  = [NSMutableArray array];
        NSSet* defaultGraphs    = [NSSet setWithArray:[self.defaultGraphsStack lastObject]];
        [model enumerateGraphsUsingBlock:^(id<GTWTerm> g){
            if (![defaultGraphs containsObject:g]) {
                [graphs addObject:g];
            }
        } error:nil];
        return graphs;
    } else {
        return self.graphs;
    }
}

@end
