//
//  NSObject+NSDictionary_QueryBindings.h
//  SPARQLEngine
//
//  Created by Gregory Williams on 5/11/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (NSDictionary_QueryBindings)

- (NSDictionary*) join: (NSDictionary*) result;

@end
