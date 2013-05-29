#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import "GTWSPARQLEngine.h"

@interface GTWAddressBookTripleStore : NSObject<GTWTripleStore>

@property id<GTWLogger> logger;
@property ABAddressBook* ab;

@end
