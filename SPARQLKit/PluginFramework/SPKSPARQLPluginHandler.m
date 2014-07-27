//
//  SPKSPARQLPluginHandler.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 8/3/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <GTWSWBase/GTWSWBase.h>
#import "SPKSPARQLPluginHandler.h"
#import "GTWConneg.h"

static NSMutableSet* registeredClasses() {
	static NSMutableSet *_registeredClasses = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_registeredClasses = [NSMutableSet set];
	});
    return _registeredClasses;
}

@implementation SPKSPARQLPluginHandler

static NSString *ext = @".plugin";
static NSString *appSupportSubpath = @"Application Support/SPARQLKit/PlugIns";

+ (BOOL) registerClass: (Class) c {
    if ([self plugInClassIsValid:c]) {
        NSMutableSet* classes   = registeredClasses();
        [classes addObject:c];
        return YES;
    }
    return NO;
}

+ (NSArray*) registeredClasses {
    NSMutableSet* classes   = registeredClasses();
    return [classes allObjects];
}

+ (BOOL)plugInClassIsValid:(Class)plugInClass {
    if (![plugInClass respondsToSelector: @selector(interfaceVersion)]) {
        goto bad_plugin;
    }
    if (![plugInClass respondsToSelector: @selector(classesImplementingProtocols)]) {
        goto bad_plugin;
    }
    return YES;
bad_plugin:
    NSLog(@"%@ is not a valid plugin class", plugInClass);
    return NO;
}

+ (NSArray*) dataSourceClasses {
    [self loadAllPlugins];
    NSArray* classes    = [self registeredClasses];
    NSMutableArray* sources = [NSMutableArray array];
    for (Class principleClass in classes) {
        NSDictionary* pluginClasses = [principleClass classesImplementingProtocols];
        for (Class pluginClass in pluginClasses) {
            if (![pluginClass respondsToSelector: @selector(implementedProtocols)]) {
//                NSLog(@"no implementedProtocols found in %@", pluginClass);
                continue;
            }
            if (![pluginClass respondsToSelector: @selector(usage)]) {
//                NSLog(@"no usage found in %@", pluginClass);
                continue;
            }
            if (![pluginClass instancesRespondToSelector: @selector(initWithDictionary:)]) {
//                NSLog(@"no initWithDictionary found in %@", pluginClass);
                continue;
            }
            
            if ([pluginClass conformsToProtocol:@protocol(GTWTripleStore)] || [pluginClass conformsToProtocol:@protocol(GTWQuadStore)]) {
                [sources addObject:pluginClass];
            }
        }
    }
    return sources;
}

+ (NSArray*) parserClasses {
    [self loadAllPlugins];
    NSArray* classes    = [self registeredClasses];
    NSMutableArray* parsers = [NSMutableArray array];
    for (Class principleClass in classes) {
        NSDictionary* pluginClasses = [principleClass classesImplementingProtocols];
        for (Class pluginClass in pluginClasses) {
            NSSet* protocols    = pluginClasses[pluginClass];
            if ([protocols containsObject:@protocol(GTWRDFParser)] || [protocols containsObject:@protocol(GTWSPARQLResultsParser)]) {
                [parsers addObject:pluginClass];
            }
        }
    }
    return parsers;
}

+ (NSArray*) serializerClasses {
    [self loadAllPlugins];
    NSArray* classes    = [self registeredClasses];
    NSMutableArray* serializers = [NSMutableArray array];
    for (Class principleClass in classes) {
        NSDictionary* pluginClasses = [principleClass classesImplementingProtocols];
        for (Class pluginClass in pluginClasses) {
            NSSet* protocols    = pluginClasses[pluginClass];
            if ([protocols containsObject:@protocol(GTWTriplesSerializer)] || [protocols containsObject:@protocol(GTWQuadsSerializer)] || [protocols containsObject:@protocol(GTWSPARQLResultsSerializer)]) {
                [serializers addObject:pluginClass];
            }
        }
    }
    return serializers;
}

+ (NSArray*) serializerClassesConformingToProtocol:(Protocol*)protocol {
    NSArray* classes    = [self serializerClasses];
    NSMutableArray* matching    = [NSMutableArray array];
    for (Class c in classes) {
        if (protocol) {
            if ([c conformsToProtocol:protocol]) {
                [matching addObject:c];
            }
        } else {
            [matching addObject:c];
        }
    }
    return matching;
}

+ (Class) parserForMediaType:(NSString*)mediaType conformingToProtocol:(Protocol*)protocol {
    NSArray* classes    = [self parserClasses];
    for (Class c in classes) {
        NSSet* mediaTypes   = [c handledParserMediaTypes];
        if ([mediaTypes containsObject:mediaType]) {
            if (protocol) {
                if ([c conformsToProtocol:protocol]) {
                    return c;
                }
            } else {
                return c;
            }
        }
    }
    return nil;
}

+ (Class) serializerForMediaType:(NSString*)mediaType conformingToProtocol:(Protocol*)protocol {
    NSArray* classes    = [self serializerClasses];
    for (Class c in classes) {
        NSSet* mediaTypes   = [c handledSerializerMediaTypes];
        if ([mediaTypes containsObject:mediaType]) {
            if (protocol) {
                if ([c conformsToProtocol:protocol]) {
                    return c;
                }
            } else {
                return c;
            }
        }
    }
    return nil;
}

+ (Class) parserForFilename: (NSString*) filename conformingToProtocol: (Protocol*) protocol {
    NSArray* classes    = [self parserClasses];
    for (Class c in classes) {
        NSSet* extensions   = [c handledFileExtensions];
        for (NSString* ext in extensions) {
            if ([filename hasSuffix:ext]) {
                if (protocol) {
                    if ([c conformsToProtocol:protocol]) {
                        return c;
                    }
                } else {
                    return c;
                }
            }
        }
    }
    return nil;
}

+ (Class) pluginClassWithName: (NSString*) name {
    [self loadAllPlugins];
    NSArray* classes    = [self registeredClasses];
    for (Class principleClass in classes) {
        NSDictionary* pluginClasses = [principleClass classesImplementingProtocols];
        for (Class pluginClass in pluginClasses) {
            NSString* n = NSStringFromClass(pluginClass);
            if ([n isEqualToString:name])
                return pluginClass;
        }
    }
    return nil;
}

+ (void) loadAllPlugins {
    NSMutableArray *classes;
    NSMutableArray *bundlePaths;
    NSEnumerator *pathEnum;
    NSString *currPath;
    NSBundle *currBundle;
    Class currPrincipalClass;
//    id currInstance;
    
    bundlePaths = [NSMutableArray array];

    if(!classes) {
        classes = [[NSMutableArray alloc] init];
    }
    
    [bundlePaths addObjectsFromArray:[self allBundles]];
    
    pathEnum = [bundlePaths objectEnumerator];
    while (currPath = [pathEnum nextObject]) {
        currBundle = [NSBundle bundleWithPath:currPath];
        if (currBundle) {
            currPrincipalClass = [currBundle principalClass];
            if (currPrincipalClass && [self plugInClassIsValid:currPrincipalClass]) { // Validation
                [self registerClass:currPrincipalClass];
                [classes addObject:currPrincipalClass];
            }
        }
    }
//    NSLog(@"%@", classes);
//    return classes;
}

+ (NSMutableArray *)allBundles {
    NSArray *librarySearchPaths;
    NSEnumerator *searchPathEnum;
    NSString *currPath;
    NSMutableArray *bundleSearchPaths = [NSMutableArray array];
    NSMutableArray *allBundles = [NSMutableArray array];
    
    librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
    
    searchPathEnum = [librarySearchPaths objectEnumerator];
    while (currPath = [searchPathEnum nextObject]) {
//        NSLog(@"current path: %@", currPath);
        [bundleSearchPaths addObject: [currPath stringByAppendingPathComponent:appSupportSubpath]];
    }
    [bundleSearchPaths addObject: [[NSBundle mainBundle] builtInPlugInsPath]];

//    NSLog(@"----------->");
    searchPathEnum = [bundleSearchPaths objectEnumerator];
    while (currPath = [searchPathEnum nextObject]) {
//        NSLog(@"current path: %@", currPath);
        NSDirectoryEnumerator *bundleEnum;
        NSString *currBundlePath;
        bundleEnum = [[NSFileManager defaultManager] enumeratorAtPath:currPath];
        if (bundleEnum) {
            while (currBundlePath = [bundleEnum nextObject]) {
//                NSLog(@"-> %@", currBundlePath);
                if ([currBundlePath hasSuffix:ext]) {
                    id bundle   = [currPath stringByAppendingPathComponent:currBundlePath];
//                    NSLog(@"---------> Bundle: %@", bundle);
                    [allBundles addObject:bundle];
                }
            }
        }
    }
    
    return allBundles;
}

@end
