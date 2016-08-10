//
//  ContactObject.h
//  
//
//  Created by Anil Khanna on 8/11/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface ContactObject : NSManagedObject

@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * fromUserJid;
@property (nonatomic, retain) NSString  *isReadPending;
@property (nonatomic, retain) NSString * messageBody;

@end
