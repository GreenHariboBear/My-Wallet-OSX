/*
 Copyright (c) 2010, Dante Torres All rights reserved.
 
 Redistribution and use in source and binary forms, with or without 
 modification, are permitted provided that the following conditions 
 are met:
 
 * Redistributions of source code must retain the above copyright 
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright 
 notice, this list of conditions and the following disclaimer in the 
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the author nor the names of its 
 contributors may be used to endorse or promote products derived from 
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE.
 */

#import "JSBridgeWebView.h"
#import "SBJSON.h"


/*
	Those are some auxiliar procedures that are used internally.
 */
@interface JSBridgeWebView (Private)

// Verifies if a request URL is a JS notification.
-(NSArray*) getJSNotificationIds:(NSURL*) p_Url;

// Decodes a raw JSON dictionary.
-(NSDictionary*) translateDictionary:(NSDictionary*) dictionary;

// Returns the object that is stored in the objDic dictionary.
-(NSObject*) translateObject:(NSDictionary*) objDic;

// Decodes a base64 string and returns a NSData object.
-(id) dataWithBase64EncodedString:(NSString *)string;

@end



@implementation JSBridgeWebView

/*
	Init the JSBridgeWebView object. It sets the regular UIWebview delegate to self,
	since the object will be listening to JS notifications.
*/
-(id) initWithFrame:(CGRect)frame
{
	if ([super initWithFrame:frame])
	{
        [self setPolicyDelegate:self];
		bridgeDelegate = nil;
        usedIDs = [NSMutableSet set];
	}
	
	return self;
}

- (void)awakeFromNib
{
    [self setPolicyDelegate:self];
    bridgeDelegate = nil;
    usedIDs = [NSMutableSet set];
}

/*
	Init the JSBridgeWebView object. It sets the regular UIWebview delegate to self,
	since the object will be listening to JS notifications.
 */
-(id) init
{
	if ([super init]) 
	{
        [self setPolicyDelegate:self];
		bridgeDelegate = nil;
        usedIDs = [NSMutableSet set];
	}
	
	return self;
}

-(void)reset {
    usedIDs = [NSMutableSet set];
}

/*
	This is the reimplementation of the superclass setter method for the delegate property.
	This reimplementation hides the internal functionality of the class.
 
	It checks if the newDelegate object conforms to the JSBridgeWebViewDelegate.
 */
-(void) setJSDelegate:(NSObject<JSBridgeWebViewDelegate>*) newDelegate
{
	if([newDelegate conformsToProtocol:@protocol(JSBridgeWebViewDelegate)])
	{
		bridgeDelegate  = (id<JSBridgeWebViewDelegate>) newDelegate;
	} else 
	{
		assert(@"The delegate should comforms to the JSBridgeWebViewDelegate protocol.");
	}
}

/*
	This is the reimplementation of the superclass getter method for the delegate property.
 
	The method returns the bridgeDelegate object. The regular super.delegate object is used 
	internally only and it is set to self.
 */
-(id) JSdelegate
{
	return bridgeDelegate;
}

/*
	Verifies if the JS is trying to communicate. This verification is done
	by analysing the URL that the JS is trying to load.
 */
-(NSArray*) getJSNotificationIds:(NSURL*) p_Url
{
	NSString* strUrl = [p_Url absoluteString];
	NSArray* array = nil;
	
	// Checks if the URL means a JS notification.
	if ([strUrl hasPrefix:@"JSBridge://ReadNotificationWithId="]) {
		
		NSRange range = [strUrl rangeOfString:@"="];
		
		uint64_t index = range.location + range.length;
		
		NSString*  result = [strUrl substringFromIndex:index];
        
       array = [result componentsSeparatedByString:@","];
	}
	
	return array;
}

/*
	Translates a raw JSON dictionary into a new dictionary with Objective-C
	objects. The input dictionary contains only string objects, which represent the
	object types and values.
 */
-(NSDictionary*) translateDictionary:(NSDictionary*) dictionary
{
	NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:0];
	for (NSString* key in dictionary) {
		NSDictionary* tempDic = [dictionary objectForKey:key];
		
		NSObject* obj = [self translateObject:tempDic];
		
		[result setObject:obj forKey:key];
	}
	
	return result;
}

/*
	Translates a dictionary containing two objects with keys 'type' and 'value'
	into an actual Objective-C object. The objects may be NSString, NSNumber,
	UIImage and NSArray.
 */
-(NSObject*) translateObject:(NSDictionary*) objDic
{
	NSString* type = [objDic objectForKey:@"type"];
	NSObject* value = [objDic objectForKey:@"value"];
	NSObject* result = nil;
	
	if ([type compare:@"string"] == NSOrderedSame) {
		
		result = value;
	} else if ([type compare:@"number"] == NSOrderedSame) {
		
		result = [NSNumber numberWithDouble:[((NSString*)value) doubleValue]];
	} else if ([type compare:@"boolean"] == NSOrderedSame) {
		
		result = [NSNumber numberWithBool:[((NSString*)value) boolValue]];
	} else if ([type compare:@"image"] == NSOrderedSame) {
		
		NSData* imgData = [self dataWithBase64EncodedString:((NSString*)value)];
		result = [[NSImage alloc] initWithData:imgData] ;
	} else if ([type compare:@"array"] == NSOrderedSame) {
		
		NSDictionary* arrayData = (NSDictionary*) value;
		uint64_t count = [arrayData count];
		NSMutableArray* array = [NSMutableArray arrayWithCapacity:count];
		
		for (int i = 0; i < count; i++) {
			[array addObject:[self translateObject:[arrayData objectForKey:[NSString stringWithFormat:@"obj%d", i]]]];
		}
		result = array;
	} 
	
	return result;
}

/*
	Listen to any try of page loading. This method checks, by the URL to be loaded, if
	it is a JS notification.
 */
- (void)webView:(WebView *)p_WebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
    
	// Checks if it is a JS notification. It returns the ID ob the JSON object in the JS code. Returns nil if it is not.
	NSArray * IDArray = [self getJSNotificationIds:[request URL]];
        
	if([IDArray count] > 0)
	{
        for (NSString * jsNotId in IDArray) {
            if (![usedIDs containsObject:jsNotId]) {
                [usedIDs addObject:jsNotId];
                
                // Reads the JSON object to be communicated.
                NSString* jsonStr = [p_WebView stringByEvaluatingJavaScriptFromString:[NSString  stringWithFormat:@"JSBridge_getJsonStringForObjectWithId(%@)", jsNotId]];
                
                SBJsonParser* jsonObj = [[SBJsonParser alloc] init];
                
                NSDictionary* jsonDic = [jsonObj objectWithString:jsonStr];
                NSDictionary* dicTranslated = [self translateDictionary:jsonDic];
                        
                // Calls the delegate method with the notified object.
                if(bridgeDelegate)
                {
                    NSString * response = [bridgeDelegate webView:p_WebView didReceiveJSNotificationWithDictionary: dicTranslated];
                    
                    if (response != nil) {
                        
                        NSString * function = [NSString stringWithFormat:@"JSBridge_setResponseWithId(%@, \"%@\");", jsNotId, [response stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
                        
                        [p_WebView stringByEvaluatingJavaScriptFromString:function];
                    } else {
                        [p_WebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSBridge_setResponseWithId(%@, null);", jsNotId]];
                    }
                }
            }
		}
        
		[listener ignore];
	} else {
		// If it is not a JS notification, pass it to the delegate.
		[listener use];
	}
}


/*
	Auxiliar method to decode a base64 string. Returns a NSdata object.
 
	I got this piece of code from MiloBird's post at http://www.cocoadev.com/index.pl?BaseSixtyFour.
 */
- (id)dataWithBase64EncodedString:(NSString *)string;
{
	const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	if (string == nil)
		[NSException raise:NSInvalidArgumentException format:@""];
	if ([string length] == 0)
		return [NSData data];
	
	static char *decodingTable = NULL;
	if (decodingTable == NULL)
	{
		decodingTable = malloc(256);
		if (decodingTable == NULL)
			return nil;
		memset(decodingTable, CHAR_MAX, 256);
		NSUInteger i;
		for (i = 0; i < 64; i++)
			decodingTable[(short)encodingTable[i]] = i;
	}
	
	const char *characters = [string cStringUsingEncoding:NSASCIIStringEncoding];
	if (characters == NULL)     //  Not an ASCII string!
		return nil;
	char *bytes = malloc((([string length] + 3) / 4) * 3);
	if (bytes == NULL)
		return nil;
	NSUInteger length = 0;
	
	NSUInteger i = 0;
	while (YES)
	{
		char buffer[4];
		short bufferLength;
		for (bufferLength = 0; bufferLength < 4; i++)
		{
			if (characters[i] == '\0')
				break;
			if (isspace(characters[i]) || characters[i] == '=')
				continue;
			buffer[bufferLength] = decodingTable[(short)characters[i]];
			if (buffer[bufferLength++] == CHAR_MAX)      //  Illegal character!
			{
				free(bytes);
				return nil;
			}
		}
		
		if (bufferLength == 0)
			break;
		if (bufferLength == 1)      //  At least two characters are needed to produce one byte!
		{
			free(bytes);
			return nil;
		}
		
		//  Decode the characters in the buffer to bytes.
		bytes[length++] = (buffer[0] << 2) | (buffer[1] >> 4);
		if (bufferLength > 2)
			bytes[length++] = (buffer[1] << 4) | (buffer[2] >> 2);
		if (bufferLength > 3)
			bytes[length++] = (buffer[2] << 6) | buffer[3];
	}
	
	realloc(bytes, length);
	return [NSData dataWithBytesNoCopy:bytes length:length];
}


@end
