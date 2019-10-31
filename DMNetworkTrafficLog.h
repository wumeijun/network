//
//  DMNetworkTrafficLog.h
//  Soul_New
//
//  Created by Maggie on 2019/10/22.
//  Copyright © 2019 Soul. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DMNetworkTrafficLog : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) NSInteger lineLength;
@property (nonatomic, assign) NSInteger headerLength;
@property (nonatomic, assign) NSInteger bodyLength;
@property (nonatomic, assign) NSInteger length;

@end

NS_ASSUME_NONNULL_END
