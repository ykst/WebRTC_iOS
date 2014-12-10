//
//  ViewController.m
//  WebRTC_iOS
//
//  Created by Yukishita Yohsuke on H26/12/10.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>

#import "RTCEAGLVideoView.h"
#import "RTCMediaStream.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCMediaConstraints.h"
#import "RTCPeerConnection.h"
#import "RTCPair.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCAudioTrack.h"
#import "RTCICECandidate.h"

#import "ViewController.h"

#define ERROR(fmt, ...) NSLog(@"ERROR:%s:%s:%d: " fmt,  __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define INFO(fmt, ...) NSLog(@"INFO:%s:%s:%d: " fmt,  __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define CHECKPOINT INFO("⚑")

#define ASSERT(b) ({ int __b = (int)(b); if(!(__b)) { ERROR("failed (%s)\n", #b); abort(); } __b;})

#define DUMP(x) printf(_Generic((x), \
    char *: "%s = %s\n", \
    const char *: "%s = %s\n", \
    char [4096]: "%s = %s\n", \
    uint64_t: "%s = %llu\n", \
    int: "%s = %d\n", \
    unsigned int: "%s = %u\n", \
    size_t: "%s = %zu\n", \
    float: "%s = %f\n", \
    void *: "%s = %p\n", \
    default: "%s = %d\n" \
), #x, x)

@interface ViewController () {
    RTCEAGLVideoView *_local_view;
    RTCEAGLVideoView *_remote_view;

    RTCMediaStream *_local_media_stream;
    RTCMediaConstraints *_constraints;

    RTCPeerConnection *_pc;
    RTCDataChannel *_dc;
}

@end

@implementation ViewController

#pragma mark - ViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    RTCPeerConnectionFactory *pc_factory = [RTCPeerConnectionFactory new];
    [self _setupSubviews];
    [self _setupPeerConnection:pc_factory];
    [self _setupMediaStreams:pc_factory];
    [self _setupDataChannel];
}

- (void)_setupSubviews
{
    _local_view = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 160, 120)];
    _remote_view = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 240, 160, 120)];

    [self.view addSubview:_local_view];
    [self.view addSubview:_remote_view];
}

- (void)_setupPeerConnection:(RTCPeerConnectionFactory *)pc_factory
{
    [RTCPeerConnectionFactory initializeSSL];

    NSArray *optional_constraints =
        @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
          [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"],
          [[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"],
          [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"],
          //[[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"],
          //[[RTCPair alloc] initWithKey:@"RtpDataChannels" value:@"true"],
          ];

    _constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@[]
                                                         optionalConstraints:optional_constraints];


    _pc = [pc_factory peerConnectionWithICEServers:@[]
                                        constraints:_constraints
                                           delegate:self];
}

- (void)_setupMediaStreams:(RTCPeerConnectionFactory *)pc_factory
{
    _local_media_stream = [pc_factory mediaStreamWithLabel:@"ARDAMS"];

    [self _setupVideoStream:pc_factory];
    [self _setupAudioStream:pc_factory];
}

- (void)_setupVideoStream:(RTCPeerConnectionFactory *)pc_factory

{
    ASSERT(_local_media_stream != NULL);
    ASSERT(_local_view != NULL);

    NSString *camera_id = nil;

    for (AVCaptureDevice *dev in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] ) {
        // NOTE: Change here to use the rear camera
        // if (dev.position == AVCaptureDevicePositionBack) {
        if (dev.position == AVCaptureDevicePositionFront) {
            camera_id = [dev localizedName];
            break;
        }
    }

    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:camera_id];
    RTCVideoSource *source     = [pc_factory videoSourceWithCapturer:capturer constraints:nil];
    RTCVideoTrack *video_track = [pc_factory videoTrackWithID:@"ARDAMSv0" source:source];

    [_local_media_stream addVideoTrack:video_track];
    [video_track addRenderer:_local_view];
}

- (void)_setupAudioStream:(RTCPeerConnectionFactory *)pc_factory

{
    ASSERT(_local_media_stream != NULL);

    RTCAudioTrack *audio_track = [pc_factory audioTrackWithID:@"ARDAMSa0"];

    [_local_media_stream addAudioTrack:audio_track];
}

- (void)_setupDataChannel
{
    ASSERT(_pc != NULL);

    _dc = [_pc createDataChannelWithLabel:@"foobar" config:[RTCDataChannelInit new]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection
{
    CHECKPOINT;
}

- (void)peerConnectionOnError:(RTCPeerConnection *)peerConnection
{
    CHECKPOINT;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged
{
    CHECKPOINT;
    DUMP(stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream
{
    CHECKPOINT;
    [stream removeVideoTrack:[stream.videoTracks objectAtIndex:0]];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate
{
    CHECKPOINT;

    DUMP([candidate.sdpMid UTF8String]);
    DUMP(candidate.sdpMLineIndex);
    DUMP([candidate.sdp UTF8String]);

    NSDictionary *json =
        @{ @"type" : @"candidate",
           @"label" : [NSNumber numberWithInt:candidate.sdpMLineIndex],
           @"id" : candidate.sdpMid,
           @"candidate" : candidate.sdp };

    NSError *error;

    NSString *desc = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:json options:0 error:&error]
                                           encoding:NSUTF8StringEncoding];
    ASSERT(error == nil);

    //[_my_channel forwardIceCandidate:desc];
}


- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState
{
    CHECKPOINT;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState
{
    CHECKPOINT;
    DUMP(newState);
}

#pragma mark - RTCDataChannelDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream
{
    CHECKPOINT;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel
{
    CHECKPOINT;
}

- (void)channelDidChangeState:(RTCDataChannel *)channel
{
    CHECKPOINT;
    DUMP(channel.state);
}

- (void)channel:(RTCDataChannel*)channel
didReceiveMessageWithBuffer:(RTCDataBuffer*)buffer
{
    CHECKPOINT;

    if (buffer.isBinary) {
        INFO(@"binary message arrived");
        DUMP(buffer.data.length);
    } else {
        NSString *str_message = [[NSString alloc] initWithData:buffer.data encoding:NSUTF8StringEncoding];
        DUMP([str_message UTF8String]);
        [channel sendData:[[RTCDataBuffer alloc] initWithData:[@"Hello iOS!" dataUsingEncoding:NSUTF8StringEncoding] isBinary:NO]];
    }
}

@end
