//
//  NSURLResponse+DoggerMonitor.h
//  Soul_New
//
//  Created by Maggie on 2019/10/18.
//  Copyright © 2019 Soul. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLResponse (DoggerMonitor)

- (NSUInteger)dm_getLineLength;
- (NSUInteger)dm_getHeadersLength;

@end

NS_ASSUME_NONNULL_END
