//
//  SPKServiceDescriptionGenerator.h
//  SPARQLKit
//
//  Created by Gregory Williams on 1/21/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface SPKServiceDescriptionGenerator : NSObject

- (NSString*) serviceDescriptionStringForModel:(id<GTWModel>)model dataset:(id<GTWDataset>)dataset quantile:(NSUInteger)quantile;
- (void) printServiceDescriptionToFile:(FILE*)f forModel:(id<GTWModel>)model dataset:(id<GTWDataset>)dataset quantile:(NSUInteger)quantile;

@end
