//
//  ChatViewController.m
//  XMPPTest
//
//  Created by Mobikasa on 7/21/16.
//  Copyright © 2016 Xcode. All rights reserved.
//

#import "ChatViewController.h"
#import "XMPPHandler.h"
#import "JSQMessagesBubbleImage.h"
#import "MessageObject.h"
#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/UTCoreTypes.h>


@interface ChatViewController ()<NSFetchedResultsControllerDelegate,MPMediaPickerControllerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{

    NSFetchedResultsController *_fetchedResultsController;
    
    NSInteger _pageNumber;
    
    NSMutableArray *indexPathForTimeStamp;
    
    NSMutableArray *chatArray;
    
    bool isChat;


}



@end

@implementation ChatViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"JSQMessages";
    
    self.inputToolbar.contentView.textView.pasteDelegate = self;
   
    /**
     *  Load up our fake data for the demo
     */
    
    
    /**
     *  You can set custom avatar sizes
     */
//    if (![NSUserDefaults incomingAvatarSetting]) {
//        self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
//    }
//    
//    if (![NSUserDefaults outgoingAvatarSetting]) {
//        self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
//    }
    
    self.showLoadEarlierMessagesHeader = YES;
    
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage jsq_defaultTypingIndicatorImage]
//                                                                              style:UIBarButtonItemStylePlain
//                                                                             target:self
//                                                                             action:@selector(receiveMessagePressed:)];
    
    /**
     *  Register custom menu actions for cells.
     */
    [JSQMessagesCollectionViewCell registerMenuAction:@selector(customAction:)];
    
    
    /**
     *  OPT-IN: allow cells to be deleted
     */
    [JSQMessagesCollectionViewCell registerMenuAction:@selector(delete:)];
    
    /**
     *  Customize your toolbar buttons
     *
     *  self.inputToolbar.contentView.leftBarButtonItem = custom button or nil to remove
     *  self.inputToolbar.contentView.rightBarButtonItem = custom button or nil to remove
     */
    
    /**
     *  Set a maximum height for the input toolbar
     *
     *  self.inputToolbar.maximumHeight = 150;
     */
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
     [[self fetchedResultsController] sections];
    
 }

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
}


- (NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    _fetchedResultsController = [[XMPPHandler sharedHandler] fetchResultControllerForJid:@"rohit@localhost" withDelegate:self];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error])
    {
        NSLog(@"Error performing fetch: %@", error);
    }
   
    [self updateDatasourceForTimeStamp];
    //   if( _fetchedResultsController.fetchRequest.fetchOffset==0)
    //   {
    //       [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndex:19] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    //   }
    return _fetchedResultsController;
}

-(void)isXMPPConnected
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


#pragma mark - Actions

- (void)receiveMessagePressed:(UIBarButtonItem *)sender
{

}

//- (void)closePressed:(UIBarButtonItem *)sender
//{
//    [self.delegateModal didDismissJSQDemoViewController:self];
//}




#pragma mark - JSQMessagesViewController method overrides

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{

    [[XMPPHandler sharedHandler] connect];
    if (text.length>0 && [[XMPPHandler sharedHandler] isXmppConnected]) {
        NSString *jid=senderId;
        
//        if ([jid componentsSeparatedByString:@"@"].count<2) {
//            jid=[NSString stringWithFormat:@"%@@%@",_userName[@"username"],_currentUserJID];
//        }
        JSQMessage *message = [[JSQMessage alloc] initWithSenderId:@"gurpreet@mobikasa"
                                                 senderDisplayName:@"gurpreet"
                                                              date:[NSDate date]
                                                              text:text];
        

        
        
        
        
        [[XMPPHandler sharedHandler] saveMessage:message outgoing:YES :@"" :nil :@"" xmppStream:[[XMPPHandler sharedHandler] xmppStream]];
        
        
        
        
        [[XMPPHandler sharedHandler] sendMessageTo:jid andMessage:text withCompletion:^(BOOL status) {
            [self.inputToolbar.contentView.textView setText:nil];
   [self finishSendingMessageAnimated:YES];
        }];
    }
    else
    {
// @"error message"
    }
    }


- (void)didPressAccessoryButton:(UIButton *)sender
{
    
    [self.inputToolbar.contentView.textView resignFirstResponder];
    
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Media messages" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
        
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self.collectionView reloadData];
            // Cancel button tappped.
            [self dismissViewControllerAnimated:YES completion:^{
            }];
        }]];
        
    
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Send photo from gallery" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            [self selectPhoto];
            
        //    [self dismissViewControllerAnimated:YES completion:nil];
            
        }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Send photo from camera" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self takePhoto];
        
      //  [self dismissViewControllerAnimated:YES completion:nil];
        
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Send location" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        // OK button tapped.
        __weak typeof(self) weakSelf = self;
        [self  addLocationMediaMessageWithLat:@"51.5034070" withLong:@"-0.1275920" Completion:^{
            
            [weakSelf.collectionView reloadData];
            
        }];
        [self dismissViewControllerAnimated:YES completion:^{
         [self finishSendingMessageAnimated:YES];
        }];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Send video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        // OK button tapped.
        
        [self video];
      }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Send audio" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        // OK button tapped.
        [self pickAudio];
        
    }]];
        // Present action sheet.
        [self presentViewController:actionSheet animated:YES completion:nil];
    
    
    
    }




#pragma mark - JSQMessages CollectionView DataSource

- (NSString *)senderId {
    return @"rohit@localhost";
}

- (NSString *)senderDisplayName {
    return @"rohit";
}

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MessageObject * message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    NSLog(@"%@",message.isMediaMessage);
    int media = [message.isMediaMessage intValue];
    if (media  == 1) {
      
        if ([message.mediaType isEqualToString:@"photo"])
        {
            JSQPhotoMediaItem *item = [[JSQPhotoMediaItem alloc] initWithImage:[UIImage imageWithData:message.media]];
            JSQMessage *msg1  = [JSQMessage messageWithSenderId:message.senderId displayName:message.senderDisplayName media:item];
            return msg1;
            
        }
        else if([message.mediaType isEqualToString:@"video"])
        {
            JSQVideoMediaItem *videoItem = [[JSQVideoMediaItem alloc] initWithFileURL:[NSURL URLWithString:message.mediaURL] isReadyToPlay:YES];
            JSQMessage *videoMessage = [JSQMessage messageWithSenderId:message.senderId
                                                           displayName:message.senderDisplayName
                                                                 media:videoItem];
            
//            jsq *locationItem = [[JSQLocationMediaItem alloc] initWithLocation:location];
//            
//            JSQMessage *msg1  = [JSQMessage messageWithSenderId:message.senderId displayName:message.senderDisplayName media:locationItem];
            
            return  videoMessage;
        }
        
        else if([message.mediaType isEqualToString:@"location"]){
            
            NSString *locationString = [[NSString alloc] initWithData:message.media encoding:NSUTF8StringEncoding];

            NSArray * array = [locationString componentsSeparatedByString:@","];

            CLLocation * location = [[CLLocation alloc]initWithLatitude:[array.firstObject floatValue] longitude:[[array lastObject] floatValue]];
           
            JSQLocationMediaItem *locationItem = [[JSQLocationMediaItem alloc] initWithLocation:location];
     
            JSQMessage *msg1  = [JSQMessage messageWithSenderId:message.senderId displayName:message.senderDisplayName media:locationItem];
       
            return  msg1;
        }
        else if([message.mediaType isEqualToString:@"audio"])
        {
            
            JSQAudioMediaItem *item = [[JSQAudioMediaItem alloc] initWithData:message.media];
            
            JSQMessage *msg1  = [JSQMessage messageWithSenderId:message.senderId displayName:message.senderDisplayName media:item];
            return msg1;
        }
//        return msg1;
    }
    else
    {
        JSQMessage *msg  = [JSQMessage messageWithSenderId:message.senderId displayName:message.senderDisplayName text:message.text];
    return msg;
    }
    return nil;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    
    [[self fetchedResultsController] objectAtIndexPath:indexPath];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  You may return nil here if you do not want bubbles.
     *  In this case, you should set the background color of your collection view cell's textView.
     *
     *  Otherwise, return your previously created bubble image data objects.
     */
    
    JSQMessage *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    
    if ([message.senderId isEqualToString:self.senderId]) {
        return [XMPPHandler sharedHandler].outgoingBubbleImageData;
    }
    
    return [XMPPHandler sharedHandler].incomingBubbleImageData;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
//        JSQMessage *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
//    
//    if ([message.senderId isEqualToString:self.senderId]) {
//        if (![NSUserDefaults outgoingAvatarSetting]) {
//            return nil;
//        }
//    }
//    else {
//        if (![NSUserDefaults incomingAvatarSetting]) {
//            return nil;
//        }
//    }
//    
    
    return [[[XMPPHandler sharedHandler] avatars] objectForKey:@"rohit@localhost" ];

}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
    }
    
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    
    /**
     *  iOS7-style sender name labels
     */
    if ([message.senderId isEqualToString:self.senderId]) {
        return nil;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [[self fetchedResultsController] objectAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row-1 inSection:indexPath.section]];
        if ([[previousMessage senderId] isEqualToString:message.senderId]) {
            return nil;
        }
    }
    
    /**
     *  Don't specify attributes to use the defaults.
     */
    return [[NSAttributedString alloc] initWithString:message.senderDisplayName];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSArray *sections = [[self fetchedResultsController] sections];
    if (section < [sections count])
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = sections[section];
        NSLog(@"%lu",(unsigned long)sectionInfo.numberOfObjects);
        return sectionInfo.numberOfObjects;
    }
    return 0;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    JSQMessage *message = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    if (!message.isMediaMessage) {
        if ([message.senderId isEqualToString:self.senderId]) {
            cell.textView.textColor = [UIColor blackColor];
        }
        else {
            cell.textView.textColor = [UIColor whiteColor];
        }
 //       cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
 //                                             NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    }
    return cell;
}



#pragma mark - UICollectionView Delegate

#pragma mark - Custom menu items

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(customAction:)) {
        return YES;
    }
    return [super collectionView:collectionView canPerformAction:action forItemAtIndexPath:indexPath withSender:sender];
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(customAction:)) {
        [self customAction:sender];
        return;
    }
    [super collectionView:collectionView performAction:action forItemAtIndexPath:indexPath withSender:sender];
}

- (void)customAction:(id)sender
{
    NSLog(@"Custom action received! Sender: %@", sender);
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Custom Action", nil)
                                message:nil
                               delegate:nil
                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                      otherButtonTitles:nil]
     show];
}



#pragma mark - JSQMessages collection view flow layout delegate

#pragma mark - Adjusting cell label heights

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
      if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  iOS7-style sender name labels
     */
    JSQMessage *currentMessage = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    if ([[currentMessage senderId] isEqualToString:self.senderId]) {
        return 0.0f;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        if ([[previousMessage senderId] isEqualToString:[currentMessage senderId]]) {
            return 0.0f;
        }
    }
    
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{

    return 0.0f;

}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self updateDatasourceForTimeStamp];
    [self.collectionView reloadData];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - Responding to collection view tap events

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
    NSLog(@"Load earlier messages!");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView atIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Tapped avatar!");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    
    
    
    NSLog(@"Tapped message bubble!");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation
{
    NSLog(@"Tapped cell at %@!", NSStringFromCGPoint(touchLocation));
}

#pragma mark - JSQMessagesComposerTextViewPasteDelegate methods


- (BOOL)composerTextView:(JSQMessagesComposerTextView *)textView shouldPasteWithSender:(id)sender
{
    
        return NO;
}

-(void)updateDatasourceForTimeStamp{
    NSArray *sections = [[self fetchedResultsController] sections];
    id <NSFetchedResultsSectionInfo> sectionInfo = sections[0];
    NSDate *lastDate = nil;
    for (int i=0; i<[sectionInfo numberOfObjects]; i++) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        
        MessageObject *messageObj = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        
//        if (![lastDate isEqualToDateIgnoringTime:[NSDate dateWithTimeIntervalSince1970:[messageObj.timeStamp doubleValue]]]) {
//            [indexPathForTimeStamp addObject:indexPath];
//        }
        lastDate = messageObj.date;
    }
    //
}

- (void)addLocationMediaMessageWithLat:(NSString *)lat withLong: (NSString *)lng Completion:(JSQLocationMediaItemCompletionBlock)completion
{
    CLLocation *location = [[CLLocation alloc] initWithLatitude:[lat floatValue] longitude:[lng floatValue]];
    JSQLocationMediaItem *locationItem = [[JSQLocationMediaItem alloc] init];
    [locationItem setLocation:location withCompletionHandler:completion];
    JSQMessage *locationMessage = [JSQMessage messageWithSenderId:@"gurpreet@localhost"
                                                      displayName:@"gurpreet"
                                                            media:locationItem];
    NSData * data = [[NSString stringWithFormat:@"%@,%@",lat,lng] dataUsingEncoding:NSUTF8StringEncoding];
    [[XMPPHandler sharedHandler] saveMessage:locationMessage outgoing:YES :@"location" : data :nil  xmppStream:[[XMPPHandler sharedHandler] xmppStream]];
    
}



-(void)pickAudio
{
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = NO;
    [self presentViewController:mediaPicker animated:YES completion:nil];

}


#pragma mark media




- (void)mediaPicker: (MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
    
    [self mediaItemToData:[mediaItemCollection.items firstObject]];
    
        [self dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"You picked : %@",mediaItemCollection);
}


- (void)video {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie,      nil];
    
    [self presentViewController:imagePicker animated:YES completion:nil];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    
    
    if ([mediaType isEqualToString:@"public.movie"]) {
        
    
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        NSURL *videoUrl=(NSURL*)[info objectForKey:UIImagePickerControllerMediaURL];
        NSString *moviePath = [videoUrl path];
            NSURL *vedioURL;
            NSLog(@"vurl %@",vedioURL);
        [[XMPPHandler sharedHandler] addVideoMediaMessageWithPath:videoUrl];
        [self.collectionView reloadData];
        [self dismissViewControllerAnimated:YES completion:^{
            [self finishSendingMessageAnimated:YES];
        }];
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath)) {
            UISaveVideoAtPathToSavedPhotosAlbum (moviePath, nil, nil, nil);
        }
    }
    }
    else
    {
        sleep(2);
        UIImage *chosenImage = info[UIImagePickerControllerEditedImage];
        [[XMPPHandler sharedHandler] addPhotoMediaMessage:chosenImage];
        [self.collectionView reloadData];
        
    }

    [picker dismissViewControllerAnimated:YES completion:nil];

}



-(void)mediaItemToData : (MPMediaItem * ) curItem
{
    NSURL *url = [curItem valueForProperty: MPMediaItemPropertyAssetURL];
    
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL: url options:nil];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset: songAsset
                                                                      presetName:AVAssetExportPresetAppleM4A];
    
    exporter.outputFileType =   @"com.apple.m4a-audio";
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * myDocumentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [[NSDate date] timeIntervalSince1970];
    NSTimeInterval seconds = [[NSDate date] timeIntervalSince1970];
    NSString *intervalSeconds = [NSString stringWithFormat:@"%0.0f",seconds];
    
    NSString * fileName = [NSString stringWithFormat:@"%@.m4a",intervalSeconds];
    
    NSString *exportFile = [myDocumentsDirectory stringByAppendingPathComponent:fileName];
    
    NSURL *exportURL = [NSURL fileURLWithPath:exportFile];
    exporter.outputURL = exportURL;
    
    // do the export
    // (completion handler block omitted)
    [exporter exportAsynchronouslyWithCompletionHandler:
     ^{
         int exportStatus = exporter.status;
         
         switch (exportStatus)
         {
             case AVAssetExportSessionStatusFailed:
             {
                 NSError *exportError = exporter.error;
                 NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                 break;
             }
             case AVAssetExportSessionStatusCompleted:
             {
                 NSLog (@"AVAssetExportSessionStatusCompleted");
                 
                 NSData *data = [NSData dataWithContentsOfFile: [myDocumentsDirectory
                                                                 stringByAppendingPathComponent:fileName]];
                 
                 dispatch_async(dispatch_get_main_queue(), ^{
                     // code here
                 

                 [[XMPPHandler sharedHandler] addAudioMediaMessageWithAudio:data];
                 [self.collectionView reloadData];
                 [self dismissViewControllerAnimated:YES completion:^{
                     [self finishSendingMessageAnimated:YES];
                 }];

                 });
                 
                 break;
             }
             case AVAssetExportSessionStatusUnknown:
             {
                 NSLog (@"AVAssetExportSessionStatusUnknown"); break;
             }
             case AVAssetExportSessionStatusExporting:
             {
                 NSLog (@"AVAssetExportSessionStatusExporting"); break;
             }
             case AVAssetExportSessionStatusCancelled:
             {
                 NSLog (@"AVAssetExportSessionStatusCancelled"); break;
             }
             case AVAssetExportSessionStatusWaiting:
             {
                 NSLog (@"AVAssetExportSessionStatusWaiting"); break;
             }
             default:
             {
                 NSLog (@"didn't get export status"); break;
             }
         }
     }];
}

- (IBAction)takePhoto {
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:picker animated:YES completion:NULL];

}


- (IBAction)selectPhoto {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:NULL];
    
    
}


@end
