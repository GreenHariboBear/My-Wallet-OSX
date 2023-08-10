#import <Foundation/Foundation.h>

@class WebView;

typedef void(^NewWindowCallback)(NSURL *url);

@interface GBWebViewExternalLinkHandler : NSObject

+(WebView *)riggedWebViewWithLoadHandler:(NewWindowCallback)handler;

@end