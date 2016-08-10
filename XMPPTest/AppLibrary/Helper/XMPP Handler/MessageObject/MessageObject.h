//
//  MessageObject.h
//  CoFETCH
//
//  Created by Anil Khanna on 8/7/15.
//  Copyright (c) 2015 Mobikasa. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface MessageObject : NSManagedObject

@property (nonatomic,retain) NSString *text;

@property (nonatomic,strong) NSNumber *isOutgoing;


@property (nonatomic,retain) NSString *senderDisplayName;
@property (nonatomic,retain) NSString *senderId;
@property (nonatomic,retain) NSString *me;

@property (nonatomic,retain) NSDate *date; //yyyy-MM-dd HH:mm:ss

@property (nonatomic,retain) NSNumber *timeStamp;
@property (nonatomic,retain) NSData *media;
@property (nonatomic,retain) NSString *mediaType;

@property (retain,nonatomic) NSNumber *isMediaMessage;

@property (retain,nonatomic) NSString *mediaURL;


@end
