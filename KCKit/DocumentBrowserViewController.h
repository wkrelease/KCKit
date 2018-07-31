//
//  DocumentBrowserViewController.h
//  KCKit
//
//  Created by king on 2018/7/31.
//  Copyright © 2018 KC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DocumentBrowserViewController : UIDocumentBrowserViewController

- (void)presentDocumentAtURL:(NSURL *)documentURL;

@end
