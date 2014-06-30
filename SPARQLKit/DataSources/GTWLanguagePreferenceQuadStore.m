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
    if (self = [super init]) {
        _store          = store;
        _prefLanguages  = prefLanguages;
    }
    return self;
}

- (instancetype) initWithDictionary: (NSDictionary*) dictionary {
    if (self = [super init]) {
        _prefLanguages  = dictionary[@"prefLanguages"];
        if (!_prefLanguages) {
            NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
            NSArray* languages = [defs objectForKey:@"AppleLanguages"];
            NSString* preferredLang = [languages objectAtIndex:0];
            _prefLanguages  = @{preferredLang: @(1.0)};
        }
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
    return self;
}

#pragma mark -

- (float) qvalueForLanguage:(NSString*)l {
    for (NSString* lang in _prefLanguages) {
        if ([l hasPrefix:lang]) {
            return [_prefLanguages[lang] floatValue];
        }
    }
    return 0.001;
}

- (float) siteQValueForLanguage:(NSString*)l {
    if ([l hasPrefix:@"en"]) {
        return 1.0;
    } else {
        return 0.9;
    }
}

- (NSSet*) availableLanguagesForQuad:(id<GTWQuad>)quad {
    NSError* error;
    NSMutableSet* languages     = [NSMutableSet set]; // populate with other languages available for this triple
    [_store enumerateQuadsMatchingSubject:quad.subject predicate:quad.predicate object:nil graph:quad.graph usingBlock:^(id<GTWQuad> q) {
        if (q.object.termType == GTWTermLiteral) {
            NSString* lang  = [q.object language];
            if (lang) {
                [languages addObject:lang];
            }
        }
    } error:&error];
    //            availableLanguages = { t.o.language | t \in G ^ t.o.type = LangLiteral(_) ^ t.s = s ^ t.p = p }
    return languages;
}

- (BOOL) languagePreferenceAllowsQuad:(id<GTWQuad>)quad {
    id<GTWTerm> object  = quad.object;
    GTWTermType type    = object.termType;
    if (type == GTWTermLiteral) {
        NSString* language  = [object language];
        if (language) {
            NSSet* availableLanguages   = [self availableLanguagesForQuad:quad];
            NSString* prefLang  = [availableLanguages anyObject];
            float prefLangMaxQ  = [self qvalueForLanguage:prefLang] * [self siteQValueForLanguage:prefLang];
            for (NSString* lang in availableLanguages) {
                float langQ = [self qvalueForLanguage:lang] * [self siteQValueForLanguage:lang];
                if (langQ > prefLangMaxQ) {
                    prefLangMaxQ    = langQ;
                    prefLang        = lang;
                }
            }
//            NSLog(@"--> %@ (%@ <=> %@)", object, language, prefLang);
            return [prefLang isEqualToString:language];
        } else {
            return YES;
        }
    } else {
        return YES;
    }
}


#pragma mark -

//- (NSArray*) getGraphsWithError:(NSError **)error {
//    return [_store getGraphsWithError:error];
//}
//
//- (BOOL) enumerateGraphsUsingBlock: (void (^)(id<GTWTerm> g)) block error:(NSError **)error {
//    return [_store enumerateGraphsUsingBlock:block error:error];
//}

- (NSArray*) getQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g error:(NSError **)error {
    NSArray* quads  = [_store getQuadsMatchingSubject:s predicate:p object:o graph:g error:error];
    NSMutableArray* filtered    = [NSMutableArray array];
    for (id<GTWQuad> q in quads) {
        if ([self languagePreferenceAllowsQuad:q]) {
            [filtered addObject:q];
        }
    }
    return filtered;
}

- (BOOL) enumerateQuadsMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o graph: (id<GTWTerm>) g usingBlock: (void (^)(id<GTWQuad> q)) block error:(NSError **)error {
    return [_store enumerateQuadsMatchingSubject:s predicate:p object:o graph:g usingBlock:^(id<GTWQuad> q) {
        if ([self languagePreferenceAllowsQuad:q]) {
            block(q);
        }
    } error:error];
}

- (void) forwardInvocation:(NSInvocation*) invocation {
    if (!_store) {
        [self doesNotRecognizeSelector: [invocation selector]];
    }
    [invocation invokeWithTarget: _store];
}

@end
