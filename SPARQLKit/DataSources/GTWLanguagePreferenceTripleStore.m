//
//  GTWLanguagePreferenceQuadStore.m
//  GTWLangaugePreferenceQuadStore
//
//  Created by Gregory Todd Williams on 6/27/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import "GTWLanguagePreferenceQuadStore.h"
#import <SPARQLKit/SPKSPARQLPluginHandler.h>
#import <SPARQLKit/SPKMemoryQuadStore.h>
#import <SPARQLKit/SPKLanguagePreference.h>

@implementation GTWLanguagePreferenceQuadStore

+ (NSString*) usage {
    return @"{ \"store\": <sub-store config> }";
}

+ (NSDictionary*) classesImplementingProtocols {
    NSSet* set  = [NSSet setWithObjects:@protocol(GTWQuadStore), nil];
    return @{ (id)[GTWLanguagePreferenceQuadStore class]: set };
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWQuadStore), nil];
}

- (NSSet*) requiredInitKeys {
    return [NSSet setWithArray:@[@"store"]];
}

- (instancetype) initWithStore:(id<GTWQuadStore>)store preferringLanguages:(NSDictionary*)prefLanguages {
    _store          = store;
    _langPref       = [[SPKLanguagePreference alloc] initWithPreferredLanguages:prefLanguages];
    
    return self;
}

- (instancetype) initWithDictionary: (NSDictionary*) dictionary {
    NSDictionary* _prefLanguages;
    _prefLanguages  = dictionary[@"prefLanguages"];
    if (!_prefLanguages) {
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        NSArray* languages = [defs objectForKey:@"AppleLanguages"];
        NSString* preferredLang = [languages objectAtIndex:0];
        _prefLanguages  = @{preferredLang: @(1.0)};
    }
    _langPref       = [[SPKLanguagePreference alloc] initWithPreferredLanguages:_prefLanguages];
    
    // This is code that's been copied from gtwsparql.m. It should be refactored at some point and put into SPARQLKit somewhere
    NSMutableDictionary* datasources    = [NSMutableDictionary dictionary];
    NSArray* plugins    = [SPKSPARQLPluginHandler dataSourceClasses];
    NSMutableArray* datasourcelist  = [NSMutableArray arrayWithArray:plugins];
    [datasourcelist addObject:[SPKMemoryQuadStore class]];
    
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
    }

    NSDictionary* dict      = dictionary[@"store"];
    NSString* sourceName    = dict[@"storetype"];
    Class c = [datasources objectForKey:sourceName];
    if (!c) {
        NSLog(@"No data source class found with config: %@", dict);
        return nil;
    }
    
    NSDictionary* pluginClasses = [c classesImplementingProtocols];
    for (Class pluginClass in pluginClasses) {
        NSSet* protocols    = pluginClasses[pluginClass];
        if ([protocols containsObject:@protocol(GTWQuadStore)]) {
            id<GTWDataSource,GTWQuadStore> store = [[pluginClass alloc] initWithDictionary:dict];
            if (!store) {
                NSLog(@"Failed to create triple store from source '%@'", pluginClass);
                return nil;
            }
//                *class  = pluginClass;
            _store  = store;
//                NSLog(@"constructed sub-store: %@", store);
            return self;
        }
    }
    return nil;
}

#pragma mark -

- (NSArray*) getQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError*__autoreleasing*)error {
    NSArray* quads  = [_store getQuadsMatchingSubject:s predicate:p object:o graph:g error:error];
    NSMutableArray* filtered    = [NSMutableArray array];
    for (id<GTWQuad> q in quads) {
        if ([_langPref languagePreferenceAllowsQuad:q fromStore:_store]) {
            [filtered addObject:q];
        }
    }
    return filtered;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError*__autoreleasing*)error {
    NSObject<GTWQuadStore>* store   = _store;
    SPKLanguagePreference* langPref = _langPref;
    return [_store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
        if ([langPref languagePreferenceAllowsQuad:q fromStore:store]) {
            block(q);
        }
    } error:error];
}

- (void) forwardInvocation:(NSInvocation*) invocation {
    [invocation invokeWithTarget: _store];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_store methodSignatureForSelector:selector];
}

@end
