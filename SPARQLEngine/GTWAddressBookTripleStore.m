#include <CommonCrypto/CommonDigest.h>
#import "GTWAddressBookTripleStore.h"
#import "GTWIRI.h"
#import "GTWLiteral.h"
#import "GTWTriple.h"

static id<GTWTerm> emitProperty (ABPerson* person, GTWIRI* subject, NSString* property, GTWIRI* predicate, Class class, void (^block)(id<GTWTriple> t)) {
    id<GTWTriple> t    = [[GTWTriple alloc] init];
    t.subject       = subject;
    t.predicate     = predicate;
    
    id value        = [person valueForProperty:property];
    if (value) {
        t.object        = [[class alloc] initWithString:value];
        block(t);
        return t.object;
    } else {
        return nil;
    }
}

static NSUInteger emitProperties (ABPerson* person, GTWIRI* subject, NSString* property, GTWIRI* predicate, Class class, void (^block)(id<GTWTriple> t), NSString* (^convert)(NSString* value)) {
    id<GTWTriple> t    = [[GTWTriple alloc] init];
    t.subject       = subject;
    t.predicate     = predicate;
    
    ABMultiValue* values        = [person valueForProperty:property];
    NSUInteger count    = 0;
    for (id ident in values) {
        NSString* value  = [values valueForIdentifier:ident];
        if (convert) {
            value   = convert(value);
        }
        if (value) {
            t.object        = [[class alloc] initWithValue:value];
            block(t);
            count++;
        }
    }
    return count;
}


@implementation GTWAddressBookTripleStore

- (GTWAddressBookTripleStore*) init {
    if (self = [super init]) {
        self.ab = [ABAddressBook sharedAddressBook];
    }
    return self;
}

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSMutableArray* triples = [NSMutableArray array];
    [self enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t) {
        [triples addObject:t];
    } error:error];
    return triples;
}

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error: (NSError**) error {
    NSDictionary* propertyPredicates    = @{
//                                            kABFirstNameProperty: @"http://xmlns.com/foaf/0.1/givenName",
//                                            kABLastNameProperty: @"http://xmlns.com/foaf/0.1/familyName",
                                            kABNicknameProperty: @{@"url": @"http://xmlns.com/foaf/0.1/nick", @"type": [GTWLiteral class]},
                                            };
    NSDictionary* multiPropertyPredicates    = @{
                                                 kABURLsProperty: @{@"url": @"http://xmlns.com/foaf/0.1/homepage", @"type": [GTWIRI class]},
                                                 kABHomePageProperty: @{@"url": @"http://xmlns.com/foaf/0.1/homepage", @"type": [GTWIRI class]},
                                                 kABEmailProperty: @{@"url": @"http://xmlns.com/foaf/0.1/mbox_sha1sum", @"type": [GTWLiteral class], @"convert": ^(NSString* value){
                                                     NSString* mbox = [NSString stringWithFormat:@"mailto:%@", value];
                                                     NSData *data = [mbox dataUsingEncoding:NSUTF8StringEncoding];
                                                     uint8_t digest[CC_SHA1_DIGEST_LENGTH];
                                                     CC_SHA1(data.bytes, (unsigned int) data.length, digest);
                                                     NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
                                                     for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
                                                         [output appendFormat:@"%02x", digest[i]];
                                                     }
//                                                     NSLog(@"%@ -> %@", output, mbox);
                                                     return output;
                                                 }},
                                            };
    
    
    
    
    NSArray* people = [self.ab people];
    GTWIRI* foafPerson  = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/Person"];
    GTWIRI* foafname  = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/name"];
    GTWIRI* foaflname  = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/familyName"];
    GTWIRI* foaffname  = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/givenName"];
//    GTWIRI* foafnick   = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/nick"];
//    GTWIRI* foafhomepage   = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/homepage"];
    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    
    for (ABPerson* p in people) {
        NSString* uid   = [p uniqueId];
        NSString* uri   = [NSString stringWithFormat:@"tag:kasei.us,2013-05-12:%@", uid];
        GTWIRI* person  = [[GTWIRI alloc] initWithIRI:uri];
        
        int showAsFlags = [[p valueForProperty:kABPersonFlags] intValue] & kABShowAsMask;
//        NSLog(@"person as company: %d", showAsFlags);
        if (!(showAsFlags & kABShowAsCompany)) {
            block([[GTWTriple alloc] initWithSubject:person predicate:rdftype object:foafPerson]);
            id<GTWTerm> fname   = emitProperty(p, person, kABFirstNameProperty, foaffname, [GTWLiteral class], block);
            id<GTWTerm> lname   = emitProperty(p, person, kABLastNameProperty, foaflname, [GTWLiteral class], block);
            
            for (NSString* property in propertyPredicates) {
                NSDictionary* data  = propertyPredicates[property];
                NSString* url   = data[@"url"];
                Class class     = data[@"type"];
                emitProperty(p, person, property, [[GTWIRI alloc] initWithIRI:url], class, block);
            }
            for (NSString* property in multiPropertyPredicates) {
                NSDictionary* data  = multiPropertyPredicates[property];
                NSString* url   = data[@"url"];
                Class class     = data[@"type"];
                emitProperties(p, person, property, [[GTWIRI alloc] initWithIRI:url], class, block, data[@"convert"]);
            }
            
            if (fname && lname) {
                block([[GTWTriple alloc] initWithSubject:person predicate:foafname object:[[GTWLiteral alloc] initWithString:[NSString stringWithFormat:@"%@ %@", fname.value, lname.value]]]);
            }
            
//            if (!(fname || lname)) {
//                NSLog(@"person without name or nick: %@", p);
//            }
        }
    }
    return YES;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    return [self enumerateTriplesWithBlock:^(id<GTWTriple> t){
        if (s) {
            if (![s isEqual:t.subject])
                return;
        }
        if (p) {
            if (![p isEqual:t.predicate])
                return;
        }
        if (o) {
            if (![o isEqual:t.object])
                return;
        }
        //        NSLog(@"enumerating matching quad: %@", q);
        block(t);
        
    } error: error];
}

- (NSEnumerator*) tripleEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSArray* triples    = [self getTriplesMatchingSubject:s predicate:p object:o error:error];
    return [triples objectEnumerator];
}

@end
