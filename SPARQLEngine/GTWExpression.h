#import <Foundation/Foundation.h>
#import "GTWTree.h"
#import "SPARQLEngine.h"

@interface GTWExpression : NSObject

+ (id<GTWTerm>) evaluateExpression: (GTWTree*) expr WithResult: (NSDictionary*) result;

@end
