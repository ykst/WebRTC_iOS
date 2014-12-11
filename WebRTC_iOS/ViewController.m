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

@implementation ViewController {
    RTCMediaStream    *_local_media_stream;
    RTCPeerConnection *_peer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    RTCPeerConnectionFactory *pc_factory = [RTCPeerConnectionFactory new];

    _peer = [pc_factory peerConnectionWithICEServers:nil constraints:nil delegate:nil];

    RTCEAGLVideoView * local_view = [[RTCEAGLVideoView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:local_view];

    _local_media_stream = [pc_factory mediaStreamWithLabel:@"ARDAMS"];

    NSString *camera_id = nil;

    for (AVCaptureDevice *dev in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] ) {
        if (dev.position == AVCaptureDevicePositionFront) {
            camera_id = [dev localizedName];
            break;
        }
    }

    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:camera_id];
    RTCVideoSource *source     = [pc_factory videoSourceWithCapturer:capturer constraints:nil];
    RTCVideoTrack *video_track = [pc_factory videoTrackWithID:@"ARDAMSv0" source:source];

    [_local_media_stream addVideoTrack:video_track];
    [video_track addRenderer:local_view];
}

@end
