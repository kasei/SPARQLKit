//
//  SPKLanguagePreference.m
//  SPARQLKit
//
//  Created by Gregory Todd Williams on 6/30/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import "SPKLanguagePreference.h"

@implementation SPKLanguagePreference

- (instancetype) initWithPreferredLanguages: (NSDictionary*) prefLangauges {
    if (self = [super init]) {
        _prefLanguages  = prefLangauges;
    }
    return self;
}

- (instancetype) init {
    if (self = [super init]) {
        NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
        NSArray* languages = [defs objectForKey:@"AppleLanguages"];
        NSString* preferredLang = [languages objectAtIndex:0];
        _prefLanguages  = @{preferredLang: @(1.0)};
    }
    return self;
}

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

- (NSSet*) availableLanguagesForTriple:(id<GTWTriple>)triple fromStore: (NSObject<GTWTripleStore>*) store {
    NSError* error;
    NSMutableSet* languages     = [NSMutableSet set]; // populate with other languages available for this triple
    [store enumerateTriplesMatchingSubject:triple.subject predicate:triple.predicate object:nil usingBlock:^(id<GTWTriple> t) {
        if (t.object.termType == GTWTermLiteral) {
            NSString* lang  = [t.object language];
            if (lang) {
                [languages addObject:lang];
            }
        }
    } error:&error];
    return languages;
}

- (NSSet*) availableLanguagesForQuad:(id<GTWQuad>)quad fromStore: (NSObject<GTWQuadStore>*) store {
    NSError* error;
    NSMutableSet* languages     = [NSMutableSet set]; // populate with other languages available for this triple
    [store enumerateQuadsMatchingSubject:quad.subject predicate:quad.predicate object:nil graph:quad.graph usingBlock:^(id<GTWQuad> q) {
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

- (BOOL) languagePreferenceAllowsTriple:(id<GTWTriple>)triple fromStore: (NSObject<GTWTripleStore>*) store {
    id<GTWTerm> object  = triple.object;
    GTWTermType type    = object.termType;
    if (type == GTWTermLiteral) {
        NSString* language  = [object language];
        if (language) {
            NSSet* availableLanguages   = [self availableLanguagesForTriple:triple fromStore:store];
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

- (BOOL) languagePreferenceAllowsQuad:(id<GTWQuad>)quad fromStore: (NSObject<GTWQuadStore>*) store {
    id<GTWTerm> object  = quad.object;
    GTWTermType type    = object.termType;
    if (type == GTWTermLiteral) {
        NSString* language  = [object language];
        if (language) {
            NSSet* availableLanguages   = [self availableLanguagesForQuad:quad fromStore:store];
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

@end
