//
//  AppDelegate.h
//  Blockchain
//
//  Created by Ben Reeves on 15/08/2013.
//  Copyright (c) 2013 Ben Reeves. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "JSBridgeWebView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, JSBridgeWebViewDelegate> {
    BOOL notificationCenterIsAvailable;
}

@property (retain) IBOutlet JSBridgeWebView *webView;

@property (assign) IBOutlet NSWindow *window;

- (NSString*)webView:(WebView*) webview didReceiveJSNotificationWithDictionary:(NSDictionary*) dictionary;

@end
