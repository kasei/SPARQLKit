#import <Foundation/Foundation.h>

@interface NSDate (W3CDTFSupport)
+(NSDate*)   dateWithW3CDTFString:(NSString*)dateAndTimeFormat;
-(NSString*) getW3CDTFString;
@end
