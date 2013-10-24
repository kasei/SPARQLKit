#import <Foundation/Foundation.h>

@interface NSDate (W3CDTFSupport)
+(NSDate*)   dateWithW3CDTFString:(NSString*)dateAndTimeFormat;
+(NSDate*)   dateWithW3CDTFString:(NSString*)dateAndTimeFormat havingTimeZone: (NSTimeZone**) tz;
-(NSString*) getW3CDTFString;
@end
