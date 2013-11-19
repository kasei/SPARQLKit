#import <Foundation/Foundation.h>
#import "SPARQLKit.h"
#import <GTWSWBase/GTWModelBase.h>

@interface GTWQuadModel : GTWModelBase<GTWModel>

@property id<GTWQuadStore> store;

- (GTWQuadModel*) initWithQuadStore: (id<GTWQuadStore>) store;

@end
