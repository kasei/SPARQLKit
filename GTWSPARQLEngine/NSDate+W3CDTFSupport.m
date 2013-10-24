//
//  NSDate+W3CDTFSupport.m
//
//  Version    0.0.2
//  Copyright  2009+, ODA Kaname (http://www.trashsuite.org/)
//  License    MIT License; http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
//

#import "NSDate+W3CDTFSupport.h"

// Private
@interface NSDate ()
+(NSDictionary*) W3CDTF_timeDictionaryWithString:(NSString*)timeString range:(NSRange)range;
@end

@implementation NSDate (W3CDTFSupport)

+(NSDate*)   dateWithW3CDTFString:(NSString*)dateAndTimeFormat havingTimeZone: (NSTimeZone**) tz
{
  NSTimeInterval interval;
  @autoreleasepool {
    NSRange separator = [dateAndTimeFormat rangeOfString:@"T"];
    NSString *timeString, *dateString;
    
    // セパレータが見つからなければ UTC として扱う
    if(separator.location == NSNotFound) {
      NSArray *dateArray = [dateAndTimeFormat componentsSeparatedByString:@"-"];
      dateString = [NSString stringWithFormat:@"%@-%@-%@",
              [dateArray objectAtIndex:0],
              ([dateArray count] >= 2) ? [dateArray objectAtIndex:1] : @"01",
              ([dateArray count] >= 3) ? [dateArray objectAtIndex:2] : @"01"
              ];
      timeString = @"00:00:00Z";
      // セパレータが見つかれば日時を分割
    } else {
      dateString = [dateAndTimeFormat substringToIndex:separator.location];
      timeString = [dateAndTimeFormat substringFromIndex:separator.location + 1];
    }
    
    // 日付を取得
    NSArray *dateArray = [dateString componentsSeparatedByString:@"-"];
    NSInteger year   = [[dateArray objectAtIndex:0] intValue];
    NSInteger month  = [[dateArray objectAtIndex:1] intValue];
    NSInteger day    = [[dateArray objectAtIndex:2] intValue];
    
    NSRange tzUTC   = [timeString rangeOfString:@"Z"];
    NSRange tzPlus  = [timeString rangeOfString:@"+"];
    NSRange tzMinus = [timeString rangeOfString:@"-"];
    
    NSInteger offsetSign = 1;
    NSInteger offsetHour, offsetMin;
    NSDictionary *timeDictionary;
    
    // UTC
    if(tzUTC.location != NSNotFound) {
      timeDictionary = [[self class] W3CDTF_timeDictionaryWithString:timeString range:tzUTC];
      // +XX:XX
    } else if (tzPlus.location != NSNotFound) {
      timeDictionary = [[self class] W3CDTF_timeDictionaryWithString:timeString range:tzPlus];
      // -XX:XX
    } else if (tzMinus.location != NSNotFound) {
      offsetSign  = -1;
      timeDictionary = [[self class] W3CDTF_timeDictionaryWithString:timeString range:tzMinus];
    } else {
      // floating
      NSRange range = { .location = [timeString length], .length = 0 };
      timeDictionary = [[self class] W3CDTF_timeDictionaryWithString:timeString range:range];
    }

      offsetHour = [[timeDictionary valueForKey:@"offsetHour"] intValue];
      offsetMin  = [[timeDictionary valueForKey:@"offsetMin"]  intValue];
      NSInteger offset = offsetSign * ((offsetHour * 3600) + (offsetMin * 60));

//      NSLog(@"time dictionary: %@", timeDictionary);
      if ([timeDictionary[@"offsetHour"] length]) {
          NSTimeZone* timezone    = [NSTimeZone timeZoneForSecondsFromGMT:offset];
//          NSLog(@"-> timezone %@", timezone);
          if (tz) {
              *tz   = timezone;
          }
          
      }
      
    // 時刻を取得
    NSArray *timeArray = [[timeDictionary valueForKey:@"timeString"] componentsSeparatedByString:@":"];
    NSInteger hour   = [[timeArray objectAtIndex:0] intValue];
    NSInteger minute   = [[timeArray objectAtIndex:1] intValue];
    NSInteger second   = ([timeArray count] > 2) ? [[timeArray objectAtIndex:2] intValue] : 0;
    
    // UTC Date を生成
    NSCalendarDate *utcDate = [
                   NSCalendarDate
                   dateWithYear:year month:month day:day
                   hour:hour minute:minute second:second
                   timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]
                   ];
    
    // オフセットを算出
    interval = [utcDate timeIntervalSinceReferenceDate] - offset;
    
    //  [NSAutoreleasePool showPools];
  }
  return [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
}

+(NSDate*) dateWithW3CDTFString:(NSString*)dateAndTimeFormat
{
  return [self dateWithW3CDTFString:dateAndTimeFormat havingTimeZone:nil];
}

+(NSDictionary*) W3CDTF_timeDictionaryWithString:(NSString*)timeString range:(NSRange)range
{
  NSString *offsetHour  = @"";
  NSString *offsetMin   = @"";
  NSString *substring = (range.location < [timeString length]) ? [timeString substringFromIndex:range.location + 1] : @"";
  NSString* sign  = [timeString substringWithRange:range];
  NSString* string    = [timeString substringToIndex:range.location];
  if ([sign isEqual: @"Z"]) {
      return @{@"timeString": string, @"offsetHour": @"0", @"offsetMin": @"0"};
  } else {
    NSArray  *offsetArray = [substring componentsSeparatedByString:@":"];
    
    if([offsetArray count] == 2) {
        offsetHour = [offsetArray objectAtIndex:0];
        offsetMin  = [offsetArray objectAtIndex:1];
    } else {
        offsetHour = offsetMin = @"";
    }
    return [NSDictionary
            dictionaryWithObjects:
            [NSArray arrayWithObjects:string, offsetHour, offsetMin, nil]
            forKeys:
            [NSArray arrayWithObjects:@"timeString", @"offsetHour", @"offsetMin", nil]
            ];
  }
}

-(NSString*) getW3CDTFString
{
  NSDateFormatter *dateFormatter = [NSDateFormatter new];

  [dateFormatter setLocale:[NSLocale systemLocale]];
  [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];

  return [dateFormatter stringFromDate:self];
}
@end
