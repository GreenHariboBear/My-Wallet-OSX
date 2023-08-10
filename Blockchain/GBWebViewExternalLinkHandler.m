#import "GBWebViewExternalLinkHandler.h"

#import <WebKit/WebKit.h>

@interface GBWebViewExternalLinkHandler ()

@property (strong, nonatomic) WebView                           *attachedWebView;
@property (strong, nonatomic) GBWebViewExternalLinkHandler      *retainedSelf;
@property (copy, nonatomic) NewWindowCallback                   handler;

@end

@implementation GBWebViewExternalLinkHandler

-(id)init {
    if (self = [super init]) {
        //create a new webview with self as the policyDelegate, and keep a ref to it
        self.attachedWebView = [WebView new];
        self.attachedWebView.policyDelegate = self;
    }
    
    return self;
}

-(void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
    //execute handler
    if (self.handler) {
        self.handler([actionInformation objectForKey:WebActionOriginalURLKey]);
    }
    
    //our job is done so safe to unretain yourself
    self.retainedSelf = nil;
}

+(WebView *)riggedWebViewWithLoadHandler:(NewWindowCallback)handler {
    //create a new handler
    GBWebViewExternalLinkHandler *newWindowHandler = [GBWebViewExternalLinkHandler new];
    
    //store the block
    newWindowHandler.handler = handler;
    
    //retain yourself so that we persist until the webView:decidePolicyForNavigationAction:request:frame:decisionListener: method has been called
    newWindowHandler.retainedSelf = newWindowHandler;
    
    //return the attached webview
    return newWindowHandler.attachedWebView;
}

@end