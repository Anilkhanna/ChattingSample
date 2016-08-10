//
//  XMPPHandler.m
//  sampleXmpp
//
//  Created by Anil Khanna on 7/30/15.
//  Copyright (c) 2015 Mobikasa. All rights reserved.
//

#import "XMPPHandler.h"

#import "GCDAsyncSocket.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPReconnect.h"
#import "XMPPvCardCoreDataStorage.h"
#import "XMPPCapabilitiesCoreDataStorage.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPvCardAvatarModule.h"
#import "XMPPvCardCoreDataStorage.h"

#import "XMPPMessageDeliveryReceipts.h"
#import "XMPPMessage+XEP_0184.h"

// For composing state
#import "XMPPMessage+XEP_0085.h"

#import <CFNetwork/CFNetwork.h>

#import "XMPPvCardTemp.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPDateTimeProfiles.h"
#import "NSXMLElement+XMPP.h"
#import "ContactObject.h"
#import "MessageObject.h"
#import "MagicalRecord.h"
#import "NSDate+MB.h"
#import "XMPPPrivacy.h"
#import "NSDateFormatter+CF.h"
#import "JSQMessages.h"
//// Log levels: off, error, warn, info, verbose
//#if DEBUG
//static const int ddLogLevel = LOG_LEVEL_VERBOSE;
//#else
//static const int ddLogLevel = LOG_LEVEL_INFO;
//#endif

@interface XMPPHandler ()<XMPPRosterDelegate,XMPPStreamDelegate>{
    
    BOOL customCertEvaluation;
    
    BOOL _isXmppConnected;
    
    NSString *password;
    
    bool chatLoaded;
        
}

@property (nonatomic, strong) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong) XMPPRoster *xmppRoster;
@property (nonatomic, strong) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, strong) XMPPvCardCoreDataStorage *xmppvCardStorage;
@property (nonatomic, strong) XMPPPrivacy *xmppPrivacy;

- (void)goOnline;
- (void)goOffline;

@end


@implementation XMPPHandler

@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize xmppRoster;
@synthesize xmppRosterStorage;
@synthesize xmppvCardTempModule;
@synthesize xmppvCardStorage;
@synthesize xmppvCardAvatarModule;
@synthesize xmppCapabilities;
@synthesize xmppCapabilitiesStorage;

+(instancetype)sharedHandler{
    
    static XMPPHandler *object;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        object = [self new];
           });
    
    return object;
}


#pragma mark -- Custom methods used to handle xmpp chat.
///////////////////////////////////////////////////////////////////////////////////


- (void)sendMessageTo:(NSString*)jid andMessage:(NSString*)messagestr withCompletion:(onMessageSent)completion{
    
    _onMessageSendCompletion = completion;
    
    //    NSXMLElement *msg=[NSXMLElement elementWithName:@"message"];
    //    [msg addAttributeWithName:@"type" stringValue:@"chat"];
    //    [msg addAttributeWithName:@"to" stringValue:jid];
    //
    //    NSXMLElement *body=[NSXMLElement elementWithName:@"body" stringValue:messagestr];
    //
    //    [msg addChild:body];
    //
    //    [msg addChild:[NSXMLElement elementWithName:@"request" xmlns:@"urn:xmpp:receipts"]];
    //
    //    [xmppStream sendElement:msg];
    
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:[[messagestr dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]];
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"id" stringValue:[xmppStream generateUUID]];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    [message addAttributeWithName:@"to" stringValue:@"gurpreet@localhost"];
    
    
    
    NSString *val = [NSString stringWithFormat:@"%f",[[self getGMTDate] timeIntervalSince1970]*1000];
    
    NSArray *a = [val componentsSeparatedByString:@"."];
    
    long timeVal = [NSString stringWithFormat:@"%@",a[0]].doubleValue;
  
    
    [message addAttributeWithName:@"timeStamp" numberValue:[NSNumber numberWithDouble:timeVal]];
    [message addChild:body];
    NSXMLElement *status = [NSXMLElement elementWithName:@"active" xmlns:@"http://jabber.org/protocol/chatstates"];
    [message addChild:status];
    [xmppStream sendElement:message];
    
}



-(NSDate*)getGMTDate
{
    NSDate *date = [NSDate date] ;
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"YYYY-MM-dd HH:mm:ss Z"];
    NSTimeZone *nyTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    [df setTimeZone: nyTimeZone];
    NSLog(@"ny time is %@" , [df stringFromDate: date]);
    
    return  date;

}


- (void)updateWhenMessageReceived:(onMessageRecieve)completion{
    _onMessageRecieveCompletion = completion;
}


- (void) userTyping{
    
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat"];
    [message addComposingChatState];
    [xmppStream sendElement:message];
    
}

- (void) userStoppedTyping{
    
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat"];
    [message addPausedChatState];
    [xmppStream sendElement:message];
}

- (void) userComposingMessage:(onMessageComposing)completion{
    _onMessageComposingCompletion  = completion;
}

- (void) readAllChatfor:(NSString*)JID{

    NSArray *records;
    
    if (JID) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.fromUserJid == %@",JID];
        records = [ContactObject MR_findAllWithPredicate:predicate];
    }else{
        records = [ContactObject MR_findAll];
    }
    
    for (ContactObject *each in records) {
        [each setIsReadPending:@"NO"];
    }
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];

    
}

-(NSArray*)getAllChatListOfUser{

    NSSortDescriptor *sd1 = [NSSortDescriptor  sortDescriptorWithKey:@"timeStamp"
                             ascending:NO
                             selector:@selector(compare:)];
    
    NSArray *sortDescriptors = @[sd1];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[MessageObject MR_entityDescription]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setFetchBatchSize:1];
    
    NSArray *records = [MessageObject MR_executeFetchRequest:fetchRequest];
    return records;
    
}


- (NSFetchedResultsController*)fetchResultControllerForAllUserChatList:(id)delegate{
    
    NSSortDescriptor *sd1 = [NSSortDescriptor
                             sortDescriptorWithKey:@"date"
                             ascending:NO
                             selector:@selector(compare:)];
    
    NSArray *sortDescriptors = @[sd1];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[ContactObject MR_entityDescription]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setFetchBatchSize:1];
    
    NSFetchedResultsController *c = [ContactObject MR_fetchAllSortedBy:@"date" ascending:NO withPredicate:nil groupBy:nil delegate:delegate];
    
   return c;
    
}

- (NSInteger) updateUnreadChatsCount{

    NSSortDescriptor *sd1 = [NSSortDescriptor
                        sortDescriptorWithKey:@"date"
                             ascending:NO
                             selector:@selector(compare:)];
    
    NSArray *sortDescriptors = @[sd1];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[ContactObject MR_entityDescription]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setFetchBatchSize:1];
    

    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.isReadPending == %@",@"YES"];

    [fetchRequest setPredicate:predicate];
//    NSFetchedResultsController *c = [ContactObject MR_fetchAllSortedBy:@"date" ascending:NO withPredicate:predicate groupBy:nil delegate:(id)self];
//    
//    [c performFetch:nil];
    
    _totalUnreadChatsCount = [[ContactObject MR_executeFetchRequest:fetchRequest] count];
    
    return  _totalUnreadChatsCount;

}


- (void) deleteChatForJid:(NSString*)jid{
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.me LIKE[c] %@",jid];
    
    NSArray *records = [MessageObject MR_findAllWithPredicate:predicate];
    
    for (MessageObject *each in records) {
        [[NSManagedObjectContext MR_defaultContext] deleteObject:each];
    }
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];

    
}

- (void) deleteUserForJid:(NSString*)jid{
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.fromUserJid LIKE[c] %@",jid];
    
    NSArray *records = [ContactObject MR_findAllWithPredicate:predicate];
    
    for (MessageObject *each in records) {
        [[NSManagedObjectContext MR_defaultContext] deleteObject:each];
    }
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    
}

//XMPPMessageArchiving_Message_CoreDataObject

- (NSFetchedResultsController*)fetchResultControllerForJid:(NSString*)jid withDelegate:(id)delegate{
    NSPredicate *predicate = nil;
    
    if (jid) {
   //     predicate = [NSPredicate predicateWithFormat:@"SELF.me == %@",jid];
        predicate = [NSPredicate predicateWithFormat:@"SELF.me == %@",@"rohit"];
        
    }
    
//    return [MessageObject MR_fetchAllWithDelegate:delegate];
    return [MessageObject MR_fetchAllSortedBy:@"timeStamp" ascending:YES withPredicate:predicate groupBy:nil delegate:delegate];
  
   }


-(BOOL)authenticate
{
    if(![xmppStream isAuthenticated])
    {
        [self disconnect];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self connect];
        });
    }
    return YES;
}

-(void)setAvatar{
    JSQMessagesAvatarImageFactory *avatarFactory = [[JSQMessagesAvatarImageFactory alloc] initWithDiameter:kJSQMessagesCollectionViewAvatarSizeDefault];
    
    JSQMessagesAvatarImage *cookImage = [avatarFactory avatarImageWithImage:[UIImage imageNamed:@"rohit.jpeg"]];
    
    JSQMessagesAvatarImage *jobsImage = [avatarFactory avatarImageWithImage:[UIImage imageNamed:@"gopi.jpeg"]];
    
    
    self.avatars = @{ @"rohit@localhost" : jobsImage,
                      @"gurpreet@localhost" : cookImage
                      
                      };
    
    
    
    
    /**
     *  Create message bubble images objects.
     *
     *  Be sure to create your bubble images one time and reuse them for good performance.
     *
     */
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    
    self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
    self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleGreenColor]];


}

- (BOOL)connect
{
    if (![xmppStream isDisconnected]) {
       [self goOnline];
        return YES;
    }
    
    [self setAvatar];
    
    NSString *myJID ;  //= [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
    NSString *myPassword ;  //= [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];
    
    //
    // If you don't want to use the Settings view to set the JID,
    // uncomment the section below to hard code a JID and password.
    //
    myJID = [NSString stringWithFormat:@"%@@%@",@"rohit",XMPP_SERVER];
    myPassword = @"123456";
//
//    myJID = @"anil@localhost";
//    myPassword = @"redhat";
    
    if (myJID == nil || myPassword == nil) {
        return NO;
    }
    
    [xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
    password = myPassword;
    
    NSError *error = nil;
    if (![xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                            message:@"See console for error details."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
        
        NSLog(@"Error connecting: %@", error);
        
        return NO;
    }
    
    return YES;
}

-(void)setupXMPP
{
    if(![[XMPPHandler sharedHandler] isXmppConnected])
    {
        
        
        if([XMPPHandler sharedHandler].xmppStream)
        {
            
            [[XMPPHandler sharedHandler] connect];
            [[XMPPHandler sharedHandler] authenticate];
            
        }
        else{
            [[XMPPHandler sharedHandler] setupXMPPHandler];
        }
        
        
    }
    else
    {
        [[XMPPHandler sharedHandler] goOnline];
    }
}

- (BOOL)connectWithoutOnline
{
    if (![xmppStream isDisconnected]) {
       
        return YES;
    }
    
    NSString *myJID ;//= [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyJID];
    NSString *myPassword ; //= [[NSUserDefaults standardUserDefaults] stringForKey:kXMPPmyPassword];
    
    //
    // If you don't want to use the Settings view to set the JID,
    // uncomment the section below to hard code a JID and password.
    //
    myJID = [NSString stringWithFormat:@"%@@%@",@"rohit",XMPP_SERVER];
    myPassword = @"123456";
    //
    //    myJID = @"anil@localhost";
    //    myPassword = @"redhat";
    
    if (myJID == nil || myPassword == nil) {
        return NO;
    }
    
    [xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
    password = myPassword;
    
    NSError *error = nil;
    if (![xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                            message:@"See console for error details."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
        [alertView show];
        
        NSLog(@"Error connecting: %@", error);
        
        return NO;
    }
    
    return YES;
}

- (void)disconnect
{
    [self goOffline];
    [xmppStream disconnect];
    
}


-(void)registerForNotifications{
    //    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunchingWithOptions) name:UIApplicationDidFinishLaunchingNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -- Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext_roster
{
    return [xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)managedObjectContext_capabilities
{
    return [xmppCapabilitiesStorage mainThreadManagedObjectContext];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark --  Application delegate used to handle xmpp chat connectivity/presence/background.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)setupXMPPHandler{
//    [DDLog addLogger:[DDTTYLogger sharedInstance] withLogLevel:XMPP_LOG_FLAG_SEND_RECV];
    if(!_isXmppConnected)
    {
    _availableFriends = [NSMutableArray new];
    _totalFriends = [NSMutableArray new];
        _blockingArray = [NSMutableArray new];
    [self setupStream];
    [self connect];
    }
}

- (void)setupXMPPHandlerWithoutOnline{
    //    [DDLog addLogger:[DDTTYLogger sharedInstance] withLogLevel:XMPP_LOG_FLAG_SEND_RECV];
    if(!_isXmppConnected)
    {
        _availableFriends = [NSMutableArray new];
        _totalFriends = [NSMutableArray new];
        _blockingArray = [NSMutableArray new];
        [self setupStream];
        [self connectWithoutOnline];
    }
}


- (void)applicationWillResignActive{
    
}

- (void)applicationDidEnterBackground{
    
    UIApplication *application = [UIApplication sharedApplication];
    
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"The iPhone simulator does not process background network traffic. "
               @"Inbound traffic is queued until the keepAliveTimeout:handler: fires.");
#endif
    
    if ([application respondsToSelector:@selector(setKeepAliveTimeout:handler:)])
    {
        [application setKeepAliveTimeout:600 handler:^{
            
            NSLog(@"KeepAliveHandler");
            
            // Do other keep alive stuff here.
        }];
    }
    
    [self goOffline];
}

- (void)applicationWillEnterForeground{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)applicationDidBecomeActive{
    
    
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    
    UINavigationController *controller = (id)window.rootViewController;
    
    if ([controller isKindOfClass:[UINavigationController class]]) {
        
#warning TODO : Update everypage for badge handling.
        
//        CFEveryPage *cont = (id)[controller visibleViewController];
        
        _isXmppConnected = NO;
//        
//        if ([cont respondsToSelector:@selector(setupChattingBlocks)]) {
//            [cont setupChattingBlocks];
//            if (_onUserOnlineStatusCompletion)_onUserOnlineStatusCompletion(NO);
//        }
    }
    
    if ([self connect]) {
        [self goOnline];
    }
    
}

- (void)applicationWillTerminate{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self disconnect];
//    [self teardownStream];
}



-(void)setupStream{
    
    
    if(xmppStream==nil)
    {
    [self registerForNotifications];
    
    
    NSAssert(xmppStream == nil, @"Method setupStream invoked multiple times");
    
    // Setup xmpp stream
    //
    // The XMPPStream is the base class for all activity.
    // Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
    xmppStream = [[XMPPStream alloc] init];
    }
#if !TARGET_IPHONE_SIMULATOR
    {
        // Want xmpp to run in the background?
        //
        // P.S. - The simulator doesn't support backgrounding yet.
        //        When you try to set the associated property on the simulator, it simply fails.
        //        And when you background an app on the simulator,
        //        it just queues network traffic til the app is foregrounded again.
        //        We are patiently waiting for a fix from Apple.
        //        If you do enableBackgroundingOnSocket on the simulator,
        //        you will simply see an error message from the xmpp stack when it fails to set the property.
        
        xmppStream.enableBackgroundingOnSocket = YES;
    }
#endif
    
    xmppReconnect = [[XMPPReconnect alloc] init];
    
    
    xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    //	xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore];
    
    xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
    
    xmppRoster.autoFetchRoster = YES;
    xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
    // Setup vCard support
    //
    // The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
    // The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
    
    xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
    xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:xmppvCardStorage];
    
    xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:xmppvCardTempModule];
    
    
    xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:xmppCapabilitiesStorage];
    
    
    xmppCapabilities.autoFetchHashedCapabilities = YES;
    xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    
    
    
    
    
    // Activate xmpp modules
    
    [xmppReconnect         activate:xmppStream];
    [xmppRoster            activate:xmppStream];
    [xmppvCardTempModule   activate:xmppStream];
    [xmppvCardAvatarModule activate:xmppStream];
    [xmppCapabilities      activate:xmppStream];
    
    // Add ourself as a delegate to anything we may be interested in
    
    [xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [xmppStream setHostName:XMPP_IP];
    [xmppStream setHostPort:5222];
    
    
    XMPPMessageDeliveryReceipts* xmppMessageDeliveryRecipts = [[XMPPMessageDeliveryReceipts alloc]
                                                               initWithDispatchQueue:dispatch_get_main_queue()];
    xmppMessageDeliveryRecipts.autoSendMessageDeliveryReceipts = YES;
    xmppMessageDeliveryRecipts.autoSendMessageDeliveryRequests = YES;
    [xmppMessageDeliveryRecipts activate:xmppStream];
    
    
    // You may need to alter these settings depending on the server you're connecting to
    customCertEvaluation = YES;
}

- (void)teardownStream
{
    [xmppStream removeDelegate:self];
    [xmppRoster removeDelegate:self];
    
    [xmppReconnect         deactivate];
    [xmppRoster            deactivate];
    [xmppvCardTempModule   deactivate];
    [xmppvCardAvatarModule deactivate];
    [xmppCapabilities      deactivate];
    
    
    
    [xmppStream disconnect];
    
    xmppStream = nil;
    xmppReconnect = nil;
    xmppRoster = nil;
    xmppRosterStorage = nil;
    xmppvCardStorage = nil;
    xmppvCardTempModule = nil;
    xmppvCardAvatarModule = nil;
    xmppCapabilities = nil;
    xmppCapabilitiesStorage = nil;
}


- (void)goOnline
{

    XMPPPresence *presence = [XMPPPresence presenceWithType:@"available"]; // type="available" is implicit
    
    NSString *domain = [xmppStream.myJID domain];
    
    //Google set their presence priority to 24, so we do the same to be compatible.
    
    if([domain isEqualToString:@"gmail.com"]
       || [domain isEqualToString:@"gtalk.com"]
       || [domain isEqualToString:@"talk.google.com"])
    {
        NSXMLElement *priority = [NSXMLElement elementWithName:@"priority" stringValue:@"24"];
        [presence addChild:priority];
    }
    
    [[self xmppStream] sendElement:presence];
    
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    
    [[self xmppStream] sendElement:presence];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -- XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    NSString *expectedCertName = [xmppStream.myJID domain];
    if (expectedCertName)
    {
        settings[(NSString *) kCFStreamSSLPeerName] = expectedCertName;
    }
    
    if (customCertEvaluation)
    {
        settings[GCDAsyncSocketManuallyEvaluateTrust] = @(YES);
    }
}

-(void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error{
    
}

- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
 completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    // The delegate method should likely have code similar to this,
    // but will presumably perform some extra security code stuff.
    // For example, allowing a specific self-signed certificate that is known to the app.
    
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    _isXmppConnected = YES;
    
    NSError *error = nil;
    
    if (![[self xmppStream] authenticateWithPassword:password error:&error])
    {
        NSLog(@"Error authenticating: %@", error);
        _isXmppConnected = NO;
    }
    
    if (_onConenctionCompleted) {
        onConenctionCompleted(_isXmppConnected);
    }

}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    if ([iq.type isEqualToString:@"result"]) {
        XMPPvCardTemp *vcard =  [XMPPvCardTemp vCardTempFromElement:iq.childElement];
        if(_onUserUpdatePhotoCompletion)
        _onUserUpdatePhotoCompletion(YES);
        NSLog(@"%@",vcard);
    }
    return NO;
}


- (UIImage *)imageForUser:(XMPPJID *)jid
{
    
    NSData *photoData = [[self xmppvCardAvatarModule] photoDataForJID:jid];
    
    if (photoData) {
        return [UIImage imageWithData:photoData];
    }
    
    return nil;
}

- (NSString *)nickNameForUser:(XMPPJID *)jid{
    
  XMPPvCardTemp *card = [xmppvCardTempModule vCardTempForJID:jid shouldFetch:YES];
    if (card.nickname) {
        return card.nickname;
    }
    
    return jid.user;
}


-(void)sendFriendRequestTo:(NSString*)userName andNickName:(NSString*)nickName{
    
//    XMPPJID *newBuddy = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@@%@",userName,XMPP_SERVER]];
    
     XMPPJID *newBuddy = [XMPPJID jidWithString:userName];
    [[self xmppRoster] addUser:newBuddy withNickname:nickName];
    
}

- (XMPPvCardTemp *)userInfoFor:(XMPPJID *)jid{
    
    XMPPvCardTemp* temp = [[XMPPHandler sharedHandler].xmppvCardTempModule vCardTempForJID:jid shouldFetch:YES];
    NSLog(@"%@",temp);
    
    return  [[XMPPHandler sharedHandler].xmppvCardTempModule vCardTempForJID:jid shouldFetch:YES];
}

- (void)xmppvCardTempModule:(XMPPvCardTempModule *)vCardTempModule
        didReceivevCardTemp:(XMPPvCardTemp *)vCardTemp
                     forJID:(XMPPJID *)jid{
    
    // XMPPvCardTemp *storedCard = [vCardTempModule vCardTempForJID:[XMPPJID jidWithString:@"newUser1@administrator"] shouldFetch:YES];
    // NSLog(@"Stored card: %@",storedCard.prettyXMLString);
    
}

-(void)updateMyVCardDetailsWith:(NSString*)nickName withImage:(UIImage *)image{
    
    
    if ([xmppStream isAuthenticated]) {
        NSLog(@"authenticated");
        dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
        dispatch_async(queue, ^{
            
            //            XMPPvCardTempModule * xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:xmppvCardStorage];
            [xmppvCardTempModule  activate:[self xmppStream]];
            
            XMPPvCardTemp *myVcardTemp = [xmppvCardTempModule myvCardTemp];
            
            if (!myVcardTemp) {
                NSLog(@"TEST FOR VCARD");
                NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
                XMPPvCardTemp *newvCardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
                [newvCardTemp setNickname:nickName];
                
                if (image) {
                    NSData *imageData = UIImagePNGRepresentation(image);
                    [newvCardTemp setPhoto:imageData];
                }
                [xmppvCardTempModule updateMyvCardTemp:newvCardTemp];
            }else{
                //Set Values as normal
                NSLog(@"TEST FOR VCARD ELSE");
                
                NSLog(@"TEST FOR VCARD");
                NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
                XMPPvCardTemp *newvCardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
                [newvCardTemp setNickname:nickName];
                //                NSArray *interestsArray= [[NSArray alloc] initWithObjects:@"food", nil];
                //                [newvCardTemp setLabels:interestsArray];
                //                [newvCardTemp setMiddleName:@"Stt"];
                
                if (image) {
                    NSData *imageData = UIImagePNGRepresentation(image);
                    [newvCardTemp setPhoto:imageData];
                }
                
                [newvCardTemp setEmailAddresses:[NSMutableArray arrayWithObjects:@"email", nil]];
                
                [xmppvCardTempModule updateMyvCardTemp:newvCardTemp];
            }
        });
    }
}


-(void)updateMyVCardDetailsWith:(NSString*)nickName withImage:(UIImage *)image withUserId:(NSString*)userId{
    
    
    if ([xmppStream isAuthenticated]) {
        NSLog(@"authenticated");
        dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
        dispatch_async(queue, ^{
            
            //            XMPPvCardTempModule * xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:xmppvCardStorage];
            [xmppvCardTempModule  activate:[self xmppStream]];
            
            XMPPvCardTemp *myVcardTemp = [xmppvCardTempModule myvCardTemp];
            
            if (!myVcardTemp) {
                NSLog(@"TEST FOR VCARD");
                NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
                XMPPvCardTemp *newvCardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
                [newvCardTemp setNickname:nickName];
                [newvCardTemp setUid:userId];
                if (image) {
                    NSData *imageData = UIImagePNGRepresentation(image);
                    [newvCardTemp setPhoto:imageData];
                }
                [xmppvCardTempModule updateMyvCardTemp:newvCardTemp];
            }else{
                //Set Values as normal
                NSLog(@"TEST FOR VCARD ELSE");
                
                NSLog(@"TEST FOR VCARD");
                NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
                XMPPvCardTemp *newvCardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
                [newvCardTemp setNickname:nickName];
                [newvCardTemp setUid:userId];
                //                NSArray *interestsArray= [[NSArray alloc] initWithObjects:@"food", nil];
                //                [newvCardTemp setLabels:interestsArray];
                //                [newvCardTemp setMiddleName:@"Stt"];
                
                if (image) {
                    NSData *imageData = UIImagePNGRepresentation(image);
                    [newvCardTemp setPhoto:imageData];
                }
                
                [newvCardTemp setEmailAddresses:[NSMutableArray arrayWithObjects:@"email", nil]];
                
                [xmppvCardTempModule updateMyvCardTemp:newvCardTemp];
            }
        });
    }
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message{
    
    
    if ([message isChatMessageWithBody]) {
        if (_onMessageSendCompletion) _onMessageSendCompletion(YES);

//        XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
//        [storage archiveMessage:message outgoing:YES xmppStream:sender];
    
        
   //     need to change
        //    [self saveMessage:message outgoing:YES xmppStream:sender];
         }
}


- (void)saveMessage:(JSQMessage *)jsqMessage outgoing:(BOOL)isOutgoing : (NSString*)mediaType : (NSData *)media : (NSString*)mediaURL xmppStream:(XMPPStream *)xmppStream
{
    // Message should either have a body, or be a composing notification
    // Fetch-n-Update OR Insert new message
    
    MessageObject *newMessage = [MessageObject MR_createEntity];
    
    if(jsqMessage.text.length > 0)
    {
                newMessage.text = jsqMessage.text;
        
    }
    
    XMPPJID *messageJid = [XMPPJID jidWithString:isOutgoing ? jsqMessage.senderId : @"rohit@localhost"];
    
    
    newMessage.isOutgoing = [NSNumber numberWithBool:isOutgoing];
    
    newMessage.mediaURL = mediaURL;
    newMessage.me = @"rohit";
    
    newMessage.date = [[NSDate date] inGMT];
    
    
    newMessage.senderId = messageJid.bare;
    
    newMessage.senderDisplayName = jsqMessage.senderDisplayName;
    
    if (jsqMessage.isMediaMessage) {
        newMessage.mediaType = mediaType;
        if (media != nil) {
            newMessage.media = media;
            }
        
        if (mediaURL != nil) {
            newMessage.mediaURL = mediaURL;
        }
        
        newMessage.isMediaMessage = [NSNumber numberWithBool:YES];
    }
    else
    {
        newMessage.isMediaMessage = [NSNumber numberWithBool:NO];
        
    }

    if (mediaType.length > 0) {
        
        
        
    }
    
    NSTimeInterval since1970 = [jsqMessage.date timeIntervalSince1970]; // January 1st 1970
    
    double result = since1970 * 1000;
    
    newMessage.timeStamp = [NSNumber numberWithDouble:result];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.fromUserJid == %@",messageJid.bare];
    
    NSArray *records =  [ContactObject MR_findAllWithPredicate:predicate];
    
    for (ContactObject *each in records) {
        [each MR_deleteEntity];
    }
    
    ContactObject *contactObject = [ContactObject MR_createEntity];
    contactObject.isReadPending = @"YES";
    
    contactObject.messageBody = newMessage.text;
    contactObject.fromUserJid = newMessage.senderId;
    
//    if ([message delayedDeliveryDate]) {
//        contactObject.date=[[message delayedDeliveryDate] inGMT];
//    }else{
        contactObject.date=[[NSDate date] inGMT];
//    }
    
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    
    [self updateUnreadChatsCount];
}

-(void) updateJIDWithCompletion:(onUserUpdatePhoto)completion
{
    _onUserUpdatePhotoCompletion =completion;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    if ([message isChatMessageWithBody])
    {
             if(_onMessageRecieveCompletion)_onMessageRecieveCompletion(message);
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        {
        }
        else
        {
        
        }
    }else if ([message hasComposingChatState]){
        
        NSLog(@"Composing ");
        
    }else if ([message isChatMessage])
    {
        
        NSLog(@"isChatMessage ");
        
        NSArray *elements = [message elementsForXmlns:@"http://jabber.org/protocol/chatstates"];
        if ([elements count] >0)
        {
            for (NSXMLElement *element in elements)
            {
                NSString *cleanStatus = [element.name stringByReplacingOccurrencesOfString:@"cha:" withString:@""];
                
                if ([cleanStatus isEqualToString:@"composing"]) {
                    if(_onMessageComposingCompletion)_onMessageComposingCompletion(YES,message);
                }else{
                    if(_onMessageComposingCompletion)_onMessageComposingCompletion(NO,message);
                }
                
            }
        }
    }else if ([message hasReceiptResponse])
    {
        NSLog(@"----------- Message Delivered ---------- ");
    }
    
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    NSLog(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [presence fromStr]);
    
    if ([_availableFriends containsObject:presence.from.user]) {
        if (![presence.type isEqualToString:@"available"]) {
            [_availableFriends removeObject:presence.from.user];
        }
    }else{
        if ([presence.type isEqualToString:@"available"]) {
            [_availableFriends addObject:presence.from.user];
        }
    }
    if(presence.from.user){
    if (![_totalFriends containsObject:presence.from.user]) {
        [_totalFriends addObject:presence.from.user];
    }else{
        [_totalFriends removeObject:presence.from.user];
    }
    }


    
//    if([[self currentUser].user_detail isKindOfClass:[CMUserProfile class]])
//    {
  //  if ([presence.from.user isEqualToString:[self currentUser].user_detail.first_name]) {
        if ([presence.from.user isEqualToString:@"rohit"]) {
            
        _isXmppConnected = YES;
        if (_onUserOnlineStatusCompletion)_onUserOnlineStatusCompletion(YES);
    }
    //}
   //
    if  ([[presence type] isEqualToString:@"subscribe"]) {
        [xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];
    }
}

- (void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence{
    
    if ([presence.type isEqualToString:@"unavailable"]) {
           _isXmppConnected = NO;
           if (_onUserOnlineStatusCompletion)_onUserOnlineStatusCompletion(NO);
    }else  if ([presence.type isEqualToString:@"available"]){
        _isXmppConnected = YES;
        if (_onUserOnlineStatusCompletion)_onUserOnlineStatusCompletion(YES);

    }
    
}


- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    if (!_isXmppConnected)
    {
        NSLog(@"Unable to connect to server. Check xmppStream.hostName");
    }
    _isXmppConnected = NO;
    if (_onUserOnlineStatusCompletion)_onUserOnlineStatusCompletion(NO);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
    NSLog(@"%@: %@", THIS_FILE, THIS_METHOD);
    XMPPUserCoreDataStorageObject *user = [xmppRosterStorage userForJID:[presence from]
                                                             xmppStream:xmppStream
                                                   managedObjectContext:[self managedObjectContext_roster]];
    
    NSString *displayName = [user displayName];
    NSString *jidStrBare = [presence fromStr];
    NSString *body = nil;
    if (![displayName isEqualToString:jidStrBare])
    {
        body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", displayName, jidStrBare];
    }
    else
    {
        body = [NSString stringWithFormat:@"Buddy request from %@", displayName];
    }
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                            message:body
                                                           delegate:nil
                                                  cancelButtonTitle:@"Not implemented"
                                                  otherButtonTitles:nil];
        [alertView show];
    } 
    else 
    {
        // We are not active, so use a local notification instead
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"Not implemented";
        localNotification.alertBody = body;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
    

}


- (void)addAudioMediaMessageWithAudio : (NSData *)audioData
{
    /// NSString *filepath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"mp3"];
    
    JSQAudioMediaItem *audioItem = [[JSQAudioMediaItem alloc] initWithData:audioData];
    JSQMessage *audioMessage = [JSQMessage messageWithSenderId:@"gurpreet@localhost"
                                                   displayName:@"gurpreet"
                                                                                         media:audioItem];
    
    
    [self saveMessage:audioMessage outgoing:YES :@"audio" :audioData :nil xmppStream:[self xmppStream]];
   // [self saveMessage:audioMessage outgoing:YES :@"audio" :audioData  xmppStream:[self xmppStream]];
}

- (void)addPhotoMediaMessage : (UIImage *)photo
{
    JSQPhotoMediaItem *photoItem = [[JSQPhotoMediaItem alloc] initWithImage:photo];
    JSQMessage *photoMessage = [JSQMessage messageWithSenderId:@"gurpreet@localhost"
                                                   displayName:@"gurpreet"
                                                         media:photoItem];
    [self saveMessage:photoMessage outgoing:YES :@"photo" :[NSData dataWithData:UIImagePNGRepresentation(photo)] :nil xmppStream:[self xmppStream]];
}

- (void)addLocationMediaMessageWithLat:(NSString *)lat withLong: (NSString *)lng Completion:(JSQLocationMediaItemCompletionBlock)completion
{
    CLLocation *ferryBuildingInSF = [[CLLocation alloc] initWithLatitude:[lat floatValue] longitude:[lng floatValue]];
    JSQLocationMediaItem *locationItem = [[JSQLocationMediaItem alloc] init];
    [locationItem setLocation:ferryBuildingInSF withCompletionHandler:completion];
    
    JSQMessage *locationMessage = [JSQMessage messageWithSenderId:@"gurpreet@localhost"
                                                      displayName:@"gurpreet"
                                                            media:locationItem];
    NSData * data = [[NSString stringWithFormat:@"%@,%@",lat,lng] dataUsingEncoding:NSUTF8StringEncoding];
    [self saveMessage:locationMessage outgoing:YES :@"location" : data : nil  xmppStream:[self xmppStream]];

}

- (void)addVideoMediaMessageWithPath:(NSURL *)path
{
//    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"video" ofType:@"mp4"];
    JSQVideoMediaItem *videoItem = [[JSQVideoMediaItem alloc] initWithFileURL:path isReadyToPlay:YES];
    JSQMessage *videoMessage = [JSQMessage messageWithSenderId:@"gurpreet@localhost"
                                                   displayName:@"gurpreet"
                                                         media:videoItem];
    NSData *videoData = [NSData dataWithContentsOfURL:path];
    [self saveMessage:videoMessage outgoing:YES :@"video" :videoData :[path absoluteString]  xmppStream:[self xmppStream]];
}

@end
