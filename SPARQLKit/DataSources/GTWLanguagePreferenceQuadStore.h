//
//  GTWLanguagePreferenceQuadStore.h
//  GTWLangaugePreferenceQuadStore
//
//  Created by Gregory Todd Williams on 6/27/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWLanguagePreferenceQuadStore : NSObject<GTWQuadStore>

@property NSDictionary* prefLanguages;
@property id<GTWQuadStore> store;

+ (NSSet*) implementedProtocols;

@end
