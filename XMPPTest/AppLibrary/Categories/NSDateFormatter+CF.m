//
//  NSDateFormatter+UBR.m
//  UrbanRunr
//
//  Created by Vishwas on 05/02/15.
//  Copyright (c) 2015 Anil Khanna. All rights reserved.
//

#import "NSDateFormatter+CF.h"

@implementation NSDateFormatter (CF)


+(instancetype)CF_defaultDateFormatterWithGMT:(BOOL)gmt{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    //yyyy-MM-dd'T'HH:mm:ss.SSS'Z'
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];

    if (gmt) {
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

    }
    
    return dateFormatter;
}

+(instancetype)CF_defaultDateFormatter{
    return [NSDateFormatter CF_defaultDateFormatterWithGMT:NO];
}


+(instancetype)CF_defaultFormatter:(NSString*)format{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:format];
    
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    return dateFormatter;
}


+(instancetype)CF_defaultTimeFormatterWith12HrFormat:(BOOL)is12Hr{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:(is12Hr) ? @"hh:mm a" : @"HH:mm"];
    
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    return dateFormatter;
}


+(instancetype)CF_defaultDateTimeFormatterWith12HrFormat:(BOOL)is12Hr{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:(is12Hr) ? @"MM-dd-yyyy HH:mm a" : @"MM-dd-yyyy HH:mm"];
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    return dateFormatter;
}


@end
