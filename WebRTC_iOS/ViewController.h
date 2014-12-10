//
//  ViewController.h
//  WebRTC_iOS
//
//  Created by Yukishita Yohsuke on H26/12/10.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RTCPeerConnectionDelegate.h"
#import "RTCDataChannel.h"

@interface ViewController : UIViewController<RTCPeerConnectionDelegate, RTCDataChannelDelegate>


@end

