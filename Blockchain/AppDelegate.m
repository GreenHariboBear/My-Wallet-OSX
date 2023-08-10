//
//  AppDelegate.m
//  Blockchain
//
//  Created by Ben Reeves on 15/08/2013.
//  Copyright (c) 2013 Ben Reeves. All rights reserved.
//

#import "AppDelegate.h"
#import "GBWebViewExternalLinkHandler.h"
#import <Quartz/Quartz.h>
#import "NSData+Base64.h"

@implementation AppDelegate


-(NSString*)getApplicationDocumentsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

-(id)getKey:(NSString*)dictionary {
    NSString * key = [dictionary valueForKey:@"key"];

    //NSLog(@"GET %@", key);

   return [[NSUserDefaults standardUserDefaults] valueForKey:key];
}

-(id)saveKey:(NSString*)dictionary {
    
    NSString * key = [dictionary valueForKey:@"key"];
    NSString * value = [dictionary valueForKey:@"value"];
    
    //NSLog(@"SAVE %@ %@", key, value);
    
    //Hack for wallet data, also save in app documents
    if ([key isEqualToString:@"payload"]) {
        NSString * documentsDirectory = [self getApplicationDocumentsPath];
                
        NSError * error = nil;
        [value writeToFile:[documentsDirectory stringByAppendingPathComponent:@"wallet.aes.json"] atomically:FALSE encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            NSLog(@"%@", error);
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:value forKey:key];

    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return nil;
}

-(id)removeKey:(NSString*)dictionary {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[dictionary valueForKey:@"key"]];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return nil;
}

-(id)clearKeys:(NSString*)dictionary {
    NSString * appDomain = [[NSBundle mainBundle] bundleIdentifier];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];

    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return nil;
}


-(id)scanQrCode:(NSDictionary*)dictionary {
    
    IKPictureTaker * pictureTaker = [IKPictureTaker pictureTaker];
    
    NSSize size;
    size.height = 600.0f;
    size.width = 600.0f;
    [pictureTaker setValue:[NSValue valueWithSize:size] forKey:IKPictureTakerOutputImageMaxSizeKey];
    
    NSUInteger result = [pictureTaker runModal];
    
    if (result == NSOKButton) {
        NSImage * image = [pictureTaker outputImage];
        
        CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                                 context:nil
                                                   hints:nil];
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
        
        [newRep setSize:[image size]];   // if you want the same resolution
        
        NSData * data = [newRep representationUsingType:NSPNGFileType properties:nil];
        
        NSString * uri = [[[@"data:image/png;base64," stringByAppendingString:[data base64EncodedString]] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        
        return uri;
    }
    
    return nil;
}

- (NSString*)webView:(WebView*) webview didReceiveJSNotificationWithDictionary:(NSDictionary*) dictionary
{
    NSString * function = (NSString*)[dictionary objectForKey:@"function"];
    
    NSLog(@"%@", function);
    
    if (function != nil) {
        SEL selector = NSSelectorFromString(function);
        if ([self respondsToSelector:selector])
            return [self performSelector:selector withObject:dictionary];
        else
            return nil;
    }
    
    return nil;
}


- (id)showNotification:(NSDictionary*) dictionary {
    [self showNotification:[dictionary valueForKey:@"title"] description:[dictionary valueForKey:@"description"]];

    return nil;
}


- (void)showNotification:(NSString *)title description:(NSString*)description {
    if (notificationCenterIsAvailable) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = title;
        notification.informativeText =description;
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}

-(WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request {
    
    return [GBWebViewExternalLinkHandler riggedWebViewWithLoadHandler:^(NSURL *url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}


- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    
    // Get the URL
    NSString *urlStr = [[event paramDescriptorForKeyword:keyDirectObject]
                        stringValue];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
        [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"\
                                                              var urlStr = '%@';\
                                                              window.location.hash = '#' + urlStr;\
                                                              console.log(window.location);\
                                                              var send_container = $(\"#send-coins\");\
                                                              send_container.trigger('click');\
                                                              var recipient = send_container.find('.tab-pane.active').find('.recipient').first();\
                                                              MyWallet.handleURI(urlStr, recipient);", [urlStr stringByReplacingOccurrencesOfString:@"'" withString:@"\'"]]];
        
        NSLog(@"%@", urlStr);
    });
}

-(void)awakeFromNib
{
    NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
    [em setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    
    NSLog(@"didFinishLoadForFrame:");
          
    NSString * resources = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Data/Resources/"];

    NSURL * url = [NSURL fileURLWithPath:resources];
        
    [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"resource = '%@';", [url absoluteString]]];
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

-(void)initWebview {
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    notificationCenterIsAvailable = (NSClassFromString(@"NSUserNotificationCenter")!=nil);
    
    NSString * resources = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Data/"];
    
    NSString * indexPath = [resources stringByAppendingPathComponent:@"index.html"];
    
    WebPreferences* prefs = [self.webView preferences];
    
    NSString * documentsDirectory = [self getApplicationDocumentsPath];
    
    [prefs performSelector:@selector(_setLocalStorageDatabasePath:) withObject:documentsDirectory];
    [prefs performSelector:@selector(setLocalStorageEnabled:) withObject:[NSNumber numberWithBool:TRUE]];
    
    [prefs setJavaScriptEnabled:YES];
    [prefs setJavaScriptCanOpenWindowsAutomatically:YES];
    
    [self.webView setJSDelegate:self];
    
    [self.webView setUIDelegate:self];
    
    if (notificationCenterIsAvailable) {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    [self.webView setFrameLoadDelegate:self];
    
    [[self.webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]]];
}

-(void)reload:(NSString*)dictionary {
    [self.webView reset];
    
    [self initWebview];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self initWebview];
}

@end
