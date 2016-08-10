//
//  NSDateFormatter+UBR.h
//  UrbanRunr
//
//  Created by Vishwas on 05/02/15.
//  Copyright (c) 2015 Anil Khanna. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDateFormatter (CF)

+(instancetype)CF_defaultDateFormatterWithGMT:(BOOL)gmt;

+(instancetype)CF_defaultDateFormatter;

+(instancetype)CF_defaultFormatter:(NSString*)format;

+(instancetype)CF_defaultTimeFormatterWith12HrFormat:(BOOL)is12Hr;

+(instancetype)CF_defaultDateTimeFormatterWith12HrFormat:(BOOL)is12Hr;


@end
