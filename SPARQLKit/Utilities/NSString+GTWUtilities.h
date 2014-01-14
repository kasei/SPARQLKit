//
//  NSString+GTWUtilities.h
//  SPARQLKit
//
//  Created by Gregory Williams on 1/13/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GTWUtilities)

- (NSArray*) componentsSeparatedByPattern:(NSString*)pat maximumItems:(NSInteger)max;

@end
