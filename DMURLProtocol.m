//
//  DMURLProtocol.m
//  SparrowSDK
//
//  Created by 周凌宇 on 03/07/2018.
//

#import "DMURLProtocol.h"
#import "NSData+GZIP.h"
#import "NSURLRequest+DoggerMonitor.h"
#import "DMNetworkTrafficLog.h"
//#import "DMDataManager.h"
//#import "DMDataManager+NetworkTraffic.h"
#import "NSURLResponse+DoggerMonitor.h"
#import "NSData+GZIP.h"
#import "DMURLSessionConfiguration.h"
#import "DMNetworkTrafficManager.h"

static NSString *const DMHTTP = @"LPDHTTP";

@interface DMURLProtocol() <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLRequest *dm_request;
@property (nonatomic, strong) NSURLResponse *dm_response;
@property (nonatomic, strong) NSMutableData *dm_data;

@end

@implementation DMURLProtocol

#pragma mark - init
- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

+ (void)start {
    DMURLSessionConfiguration *sessionConfiguration = [DMURLSessionConfiguration defaultConfiguration];
    for (id protocolClass in [DMNetworkTrafficManager manager].protocolClasses) {
        [NSURLProtocol registerClass:protocolClass];
    }
    if (![sessionConfiguration isSwizzle]) {
        [sessionConfiguration load];
    }
}

+ (void)end {
    DMURLSessionConfiguration *sessionConfiguration = [DMURLSessionConfiguration defaultConfiguration];
    [NSURLProtocol unregisterClass:[DMURLProtocol class]];
    if ([sessionConfiguration isSwizzle]) {
        [sessionConfiguration unload];
    }
}


/**
 需要监控的请求

 @param request 此次请求
 @return 是否需要监控
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request.URL.scheme isEqualToString:@"https"]) {
        return NO;
    }
    // 拦截过的不再拦截
    if ([NSURLProtocol propertyForKey:DMHTTP inRequest:request] ) {
        return NO;
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    [NSURLProtocol setProperty:@YES
                        forKey:DMHTTP
                     inRequest:mutableReqeust];
    return [mutableReqeust copy];
}

- (void)startLoading {
    NSURLRequest *request = [[self class] canonicalRequestForRequest:self.request];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    self.dm_request = self.request;
}

- (void)stopLoading {
    [self.connection cancel];

    DMNetworkTrafficLog *model = [[DMNetworkTrafficLog alloc] init];
    model.path = self.request.URL.path;
    model.host = self.request.URL.host;
//    model.type = DMNetworkTrafficDataTypeResponse;
    model.lineLength = [self.dm_response dm_getLineLength];
    model.headerLength = [self.dm_response dm_getHeadersLength];
    if ([self.dm_response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self.dm_response;
        NSData *data = self.dm_data;
        if ([[httpResponse.allHeaderFields objectForKey:@"Content-Encoding"] isEqualToString:@"gzip"]) {
            data = [self.dm_data gzippedData];
        }
        model.bodyLength = data.length;
    }
    model.length = model.lineLength + model.headerLength + model.bodyLength;
    NSLog(@"response=========== %@%@  %@==%@",model.host,model.path,@(model.bodyLength),@(model.length));

//    [model settingOccurTime];
//    [[DMDataManager defaultDB] addNetworkTrafficLog:model];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    [self.client URLProtocol:self didFailWithError:error];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection{
    return YES;
}

-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
//    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
//    {
        // 不管证书是否有效都使用
        NSString *thePath = [[NSBundle mainBundle] pathForResource:@"clientNew" ofType:@"p12"];
        NSData *PKCS12Data = [[NSData alloc] initWithContentsOfFile:thePath];
        CFDataRef inPKCS12Data = (CFDataRef)CFBridgingRetain(PKCS12Data);
        SecIdentityRef identity;
        
        // 读取p12证书中的内容
        OSStatus result = [self extractP12Data:inPKCS12Data toIdentity:&identity];
        if(result != errSecSuccess){
            [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
            return;
        }
        
        SecCertificateRef certificate = NULL;
        SecIdentityCopyCertificate (identity, &certificate);
        
        const void *certs[] = {certificate};
        CFArrayRef certArray = CFArrayCreate(kCFAllocatorDefault, certs, 1, NULL);
        
        NSURLCredential *credential = [NSURLCredential credentialWithIdentity:identity certificates:(NSArray*)CFBridgingRelease(certArray) persistence:NSURLCredentialPersistencePermanent];

        
        [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
//    }
//    else
//    {
//        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
//    }
}

-(OSStatus) extractP12Data:(CFDataRef)inP12Data toIdentity:(SecIdentityRef*)identity {
    
    OSStatus securityError = errSecSuccess;
    
    CFStringRef password = CFSTR("soulapp123!@#1");
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { password };
    
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    securityError = SecPKCS12Import(inP12Data, options, &items);
    
    if (securityError == 0) {
        CFDictionaryRef ident = CFArrayGetValueAtIndex(items,0);
        const void *tempIdentity = NULL;
        tempIdentity = CFDictionaryGetValue(ident, kSecImportItemIdentity);
        *identity = (SecIdentityRef)tempIdentity;
    }
    
    if (options) {
        CFRelease(options);
    }
    
    return securityError;
}



#pragma mark - NSURLConnectionDataDelegate

-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (response != nil) {
        self.dm_response = response;
        [self.client URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
    }

    DMNetworkTrafficLog *model = [[DMNetworkTrafficLog alloc] init];
    model.path = request.URL.path;
    model.host = request.URL.host;
//    model.type = DMNetworkTrafficDataTypeRequest;
    model.lineLength = [connection.currentRequest dgm_getLineLength];
    model.headerLength = [connection.currentRequest dgm_getHeadersLengthWithCookie];
    model.bodyLength = [connection.currentRequest dgm_getBodyLength];
    model.length = model.lineLength + model.headerLength + model.bodyLength;
//    [model settingOccurTime];
//    [[DMDataManager defaultDB] addNetworkTrafficLog:model];
    NSLog(@"request=========== + %@%@  %@",model.host,model.path,@(model.length));
    return request;
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    self.dm_response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self.dm_data appendData:data];
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [[self client] URLProtocolDidFinishLoading:self];
}

- (NSMutableData *)dm_data {
    if (_dm_data == nil) {
        _dm_data = [NSMutableData data];
    }
    return _dm_data;
}

@end
