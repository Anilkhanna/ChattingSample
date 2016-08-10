//
//  XMPPHandler.h
//  sampleXmpp
//
//  Created by Anil Khanna on 7/30/15.
//  Copyright (c) 2015 Mobikasa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPFramework.h"
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>
#import "XMPPvCardTemp.h"
#import <CoreLocation/CoreLocation.h>
#import "JSQMessages.h"
//#define XMPP_SERVER @"cardamom.mobikasa.net"////live
#define XMPP_IP @"54.187.94.25"
#define XMPP_SERVER @"localhost"
//staging

typedef void(^onMessageSent)(BOOL);
typedef void(^onMessageRecieve)(XMPPMessage *message);
typedef void(^onMessageComposing)(BOOL status, XMPPMessage *message);
typedef void(^onUserOnlineStatus)(BOOL);
typedef void(^onUserUpdatePhoto)(BOOL);
typedef void(^onConenctionCompleted)(BOOL);



@interface XMPPHandler : NSObject

+(instancetype)sharedHandler;

- (void)setupXMPPHandler;

@property (nonatomic,strong) NSMutableArray *availableFriends;
@property (nonatomic,strong) NSMutableArray *blockingArray;
@property (nonatomic,strong) NSMutableArray *totalFriends;
@property (nonatomic,assign) NSInteger totalUnreadChatsCount;
@property (strong, nonatomic) NSDictionary *avatars;
@property (nonatomic,readonly) BOOL isXmppConnected;

@property (nonatomic,strong) onMessageRecieve onMessageRecieveCompletion;
@property (nonatomic,strong) onMessageSent onMessageSendCompletion;
@property (nonatomic,strong) onMessageComposing onMessageComposingCompletion;
@property (nonatomic,strong) onUserOnlineStatus onUserOnlineStatusCompletion;
@property (nonatomic,strong) onUserUpdatePhoto onUserUpdatePhotoCompletion;
@property (nonatomic,strong) onConenctionCompleted onConenctionCompleted;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubbleImageData;

@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubbleImageData;


- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

// Connectivity
- (BOOL)connect;
- (void)disconnect;
- (void)goOffline;
- (BOOL)connectWithoutOnline;
- (void)setupXMPPHandlerWithoutOnline;
// Messages
- (void) sendMessageTo:(NSString*)jid andMessage:(NSString*)message withCompletion:(onMessageSent)completion;
- (void) updateWhenMessageReceived:(onMessageRecieve)completion;
- (void) userTyping;
- (void) userStoppedTyping;
- (void) userComposingMessage:(onMessageComposing)completion;
- (void) readAllChatfor:(NSString*)JID;
- (NSInteger) updateUnreadChatsCount;
- (void) deleteChatForJid:(NSString*)jid;
-(void) updateJIDWithCompletion:(onUserUpdatePhoto)completion;
-(void)setMessageCompletionBlock :(onMessageRecieve)message;
-(NSArray*)getAllChatListOfUser;
-(void)setupXMPP;
// Fetch Result Controller for messages request;
- (NSFetchedResultsController*)fetchResultControllerForAllUserChatList:(id)delegate;
- (NSFetchedResultsController*)fetchResultControllerForJid:(NSString*)jid withDelegate:(id)delegate;

- (void)teardownStream;
// UserInfo
- (UIImage *)imageForUser:(XMPPJID *)jid;
-(BOOL)authenticate;
- (NSString *)nickNameForUser:(XMPPJID *)jid;

- (XMPPvCardTemp *)userInfoFor:(XMPPJID *)jid;
-(void)sendFriendRequestTo:(NSString*)userName andNickName:(NSString*)nickName;

-(void)updateMyVCardDetailsWith:(NSString*)nickName withImage:(UIImage *)image;
-(void)updateMyVCardDetailsWith:(NSString*)nickName withImage:(UIImage *)image withUserId:(NSString*)userId;
-(void)blockUser :(NSString*)blockingJid;
@property (nonatomic, strong) XMPPStream *xmppStream;

- (void)setupXMPPPrivacy;
-(void)privacyblock : (NSString*)jid;
- (void) deleteUserForJid:(NSString*)jid;
- (void)goOnline;
- (void)addPhotoMediaMessage;
- (void)saveMessage:(JSQMessage *)jsqMessage outgoing:(BOOL)isOutgoing : (NSString*)mediaType : (NSData *)media : (NSString*)mediaURL xmppStream:(XMPPStream *)xmppStream;

- (void)addLocationMediaMessageWithLat:(NSString *)lat withLong:(NSString *)lng Completion:(JSQLocationMediaItemCompletionBlock)completion;
- (void)addVideoMediaMessage;

- (void)addAudioMediaMessage;
- (void)addAudioMediaMessageWithAudio : (NSData *)audioData;
- (void)addPhotoMediaMessage : (UIImage *)photo;
- (void)addVideoMediaMessageWithPath:(NSURL *)path;

@end
