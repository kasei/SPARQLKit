//
//  SPKSPARQLPluginHandler.h
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 8/3/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPARQLKit.h"

@interface SPKSPARQLPluginHandler : NSObject

+ (NSArray*) dataSourceClasses;
+ (NSArray*) parserClasses;
+ (Class) pluginClassWithName: (NSString*) name;
+ (Class) parserForMediaType: (NSString*) mediaType conformingToProtocol: (Protocol*) protocol;
+ (Class) parserForFilename: (NSString*) filename conformingToProtocol: (Protocol*) protocol;
+ (BOOL) registerClass: (Class) c;
+ (NSArray*) registeredClasses;

@end
