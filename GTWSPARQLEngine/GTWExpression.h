#import <Foundation/Foundation.h>
#import "GTWTree.h"
#import "GTWSPARQLEngine.h"

@interface GTWExpression : GTWTree

+ (id<GTWTerm>) evaluateExpression: (GTWTree*) expr withResult: (NSDictionary*) result;

@end
