//
//  GTWLanguagePreferenceTripleStore.h
//  GTWLangaugePreferenceTripleStore
//
//  Created by Gregory Todd Williams on 6/27/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>
#import "SPKLanguagePreference.h"

@interface GTWLanguagePreferenceTripleStore : NSProxy<GTWTripleStore> {
    NSObject<GTWTripleStore>* _store;
}

@property SPKLanguagePreference* langPref;

+ (NSSet*) implementedProtocols;

@end
