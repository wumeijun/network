//
//  NSURLRequest+DoggerMonitor.h
//  Soul_New
//
//  Created by Maggie on 2019/10/18.
//  Copyright © 2019 Soul. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (DoggerMonitor)

- (NSUInteger)dgm_getLineLength;
- (NSUInteger)dgm_getHeadersLengthWithCookie;
- (NSDictionary<NSString *, NSString *> *)dgm_getCookies;
- (NSUInteger)dgm_getBodyLength;

@end

NS_ASSUME_NONNULL_END
