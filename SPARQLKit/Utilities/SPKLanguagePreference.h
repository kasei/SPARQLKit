//
//  SPKLanguagePreference.h
//  SPARQLKit
//
//  Created by Gregory Todd Williams on 6/30/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface SPKLanguagePreference : NSObject

@property NSDictionary* prefLanguages;

- (instancetype) initWithPreferredLanguages: (NSDictionary*) prefLangauges;
- (instancetype) init;
- (float) qvalueForLanguage:(NSString*)l;
- (float) siteQValueForLanguage:(NSString*)l;

- (NSSet*) availableLanguagesForTriple:(id<GTWTriple>)triple fromStore: (NSObject<GTWTripleStore>*) store;
- (BOOL) languagePreferenceAllowsTriple:(id<GTWTriple>)triple fromStore: (NSObject<GTWTripleStore>*) store;

- (NSSet*) availableLanguagesForQuad:(id<GTWQuad>)quad fromStore: (NSObject<GTWQuadStore>*) store;
- (BOOL) languagePreferenceAllowsQuad:(id<GTWQuad>)quad fromStore: (NSObject<GTWQuadStore>*) store;

@end
