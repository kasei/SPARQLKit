//
//  GTWLanguagePreferenceQuadStore.h
//  GTWLangaugePreferenceQuadStore
//
//  Created by Gregory Todd Williams on 6/27/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>
#import "SPKLanguagePreference.h"

@interface GTWLanguagePreferenceQuadStore : NSProxy<GTWQuadStore> {
    NSObject<GTWQuadStore>* _store;
}

@property SPKLanguagePreference* langPref;
//@property NSDictionary* prefLanguages;

+ (NSSet*) implementedProtocols;

@end
