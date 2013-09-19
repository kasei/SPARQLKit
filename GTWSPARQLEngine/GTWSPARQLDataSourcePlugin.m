//
//  GTWSPARQLDataSourcePlugin.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 8/3/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import <GTWSWBase/GTWSWBase.h>
#import "GTWSPARQLDataSourcePlugin.h"

@implementation GTWSPARQLDataSourcePlugin

NSString *ext = @"plugin";
NSString *appSupportSubpath = @"Application Support/GTWSPARQLEngine/PlugIns";

+ (BOOL)plugInClassIsValid:(Class)plugInClass {
    if([plugInClass conformsToProtocol:@protocol(GTWTripleStore)]) {
        if ([plugInClass instancesRespondToSelector: @selector(interfaceVersion)] && [plugInClass instancesRespondToSelector: @selector(initWithDictionary:)]) {
//            NSLog(@"is valid: %@", plugInClass);
            return YES;
        }
    }
    return NO;
}
            
+ (NSArray*) loadAllPlugins {
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
                [classes addObject:currPrincipalClass];
            }
        }
    }
//    NSLog(@"%@", classes);
    return classes;
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
                if ([[currBundlePath pathExtension] isEqualToString:ext]) {
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
