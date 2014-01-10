//
//  GTWSPARQLConnection.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "HTTPConnection.h"

@interface GTWSPARQLConnection : HTTPConnection

- (NSString *)dateAsString:(NSDate *)date;

@end
