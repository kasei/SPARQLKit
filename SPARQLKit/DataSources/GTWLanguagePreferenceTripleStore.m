//
//  GTWLanguagePreferenceTripleStore.m
//  GTWLanguagePreferenceTripleStore
//
//  Created by Gregory Todd Williams on 6/27/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import "GTWLanguagePreferenceTripleStore.h"
#import <SPARQLKit/SPKSPARQLPluginHandler.h>
#import <SPARQLKit/SPKLanguagePreference.h>

@implementation GTWLanguagePreferenceTripleStore

+ (NSString*) usage {
    return @"{ \"store\": <sub-store config> }";
}

+ (NSDictionary*) classesImplementingProtocols {
    NSSet* set  = [NSSet setWithObjects:@protocol(GTWTripleStore), nil];
    return @{ (id)[GTWLanguagePreferenceTripleStore class]: set };
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWTripleStore), nil];
}

- (NSSet*) requiredInitKeys {
    return [NSSet setWithArray:@[@"store"]];
}

- (instancetype) initWithStore:(id<GTWTripleStore>)store preferringLanguages:(NSDictionary*)prefLanguages {
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
        if ([protocols containsObject:@protocol(GTWTripleStore)]) {
            id<GTWDataSource,GTWTripleStore> store = [[pluginClass alloc] initWithDictionary:dict];
            if (!store) {
                NSLog(@"Failed to create triple store from source '%@'", pluginClass);
                return nil;
            }
//            *class  = pluginClass;
            _store  = store;
            return self;
        }
    }
    return nil;
}

#pragma mark -

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError * __autoreleasing*)error {
    NSArray* triples  = [_store getTriplesMatchingSubject:s predicate:p object:o error:error];
    NSMutableArray* filtered    = [NSMutableArray array];
    for (id<GTWTriple> t in triples) {
        if ([_langPref languagePreferenceAllowsTriple:t fromStore:_store]) {
            [filtered addObject:t];
        }
    }
    return filtered;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError *__autoreleasing*)error {
    NSObject<GTWTripleStore>* store   = _store;
    SPKLanguagePreference* langPref = _langPref;
    return [_store enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t) {
        if ([langPref languagePreferenceAllowsTriple:t fromStore:store]) {
            block(t);
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
