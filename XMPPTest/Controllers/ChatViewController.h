//
//  ChatViewController.h
//  XMPPTest
//
//  Created by Mobikasa on 7/21/16.
//  Copyright © 2016 Xcode. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "JSQMessages.h"

//#import "DemoModelData.h"
//#import "NSUserDefaults+DemoSettings.h"


@class DemoMessagesViewController;

//@protocol JSQDemoViewControllerDelegate <NSObject>
//
//- (void)didDismissJSQDemoViewController:(DemoMessagesViewController *)vc;
//
//@end




@interface ChatViewController : JSQMessagesViewController <UIActionSheetDelegate, JSQMessagesComposerTextViewPasteDelegate>

//@property (weak, nonatomic) id<JSQDemoViewControllerDelegate> delegateModal;

//@property (strong, nonatomic) DemoModelData *demoData;

- (void)receiveMessagePressed:(UIBarButtonItem *)sender;

- (void)closePressed:(UIBarButtonItem *)sender;

@end
