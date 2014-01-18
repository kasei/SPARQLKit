//
//  NSString+GTWUtilities.m
//  SPARQLKit
//
//  Created by Gregory Williams on 1/13/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "NSString+GTWUtilities.h"

@implementation NSString (GTWUtilities)

- (NSArray*) gtw_componentsSeparatedByPattern:(NSString*)pat maximumItems:(NSInteger)max {
    NSMutableArray* components  = [NSMutableArray array];
    NSString* string    = self;
    NSRange range   = [string rangeOfString:pat options:NSRegularExpressionSearch];
    while (range.location != NSNotFound) {
        range   = [string rangeOfString:pat options:NSRegularExpressionSearch];
        NSString* comp  = [string substringToIndex:range.location];
        [components addObject:comp];
        string  = [string substringFromIndex:(range.location+range.length)];
        range   = [string rangeOfString:pat options:NSRegularExpressionSearch];
    }
    [components addObject:string];
    if (max > 0 && [components count] > max) {
        NSRange keep  = NSMakeRange(0, max-1);
        NSMutableArray* newarray;
        if (keep.length > 0) {
            newarray    = [[components subarrayWithRange:keep] mutableCopy];
        } else {
            newarray    = [NSMutableArray array];
        }
        NSArray* smush  = [components subarrayWithRange:NSMakeRange(max-1, [components count]-max+1)];
        NSString* new   = [smush componentsJoinedByString:@""];
        [newarray addObject:new];
        return [newarray copy];
    } else {
        return [components copy];
    }
}

@end
