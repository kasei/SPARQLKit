#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import <GTWSWBase/GTWModelBase.h>

@interface SPKQuadModel : GTWModelBase<GTWModel>

@property id<GTWQuadStore> store;

- (SPKQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store;

@end
