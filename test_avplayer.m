#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface TestPlayer : NSObject
@property (strong) AVPlayer *player;
@property BOOL done;
@end

@implementation TestPlayer
- (void)playStream:(NSString *)urlString {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    if (err) printf("setCategory error: %s\n", err.localizedDescription.UTF8String);
    [session setActive:YES error:&err];
    if (err) printf("setActive error: %s\n", err.localizedDescription.UTF8String);
    
    printf("AudioSession Category: %s\n", session.category.UTF8String);
    printf("AudioSession Output Volume: %.2f\n", session.outputVolume);
    for (AVAudioSessionPortDescription *port in session.currentRoute.outputs) {
        printf("Output Port: %s (%s)\n", port.portName.UTF8String, port.portType.UTF8String);
    }

    NSURL *url = [NSURL URLWithString:urlString];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemFailedToPlayToEndTimeNotification object:item queue:nil usingBlock:^(NSNotification *note) {
        printf("NOTIFICATION: FailedToPlayToEndTime: %s\n", [note.userInfo description].UTF8String);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemPlaybackStalledNotification object:item queue:nil usingBlock:^(NSNotification *note) {
        printf("NOTIFICATION: PlaybackStalled\n");
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemNewErrorLogEntryNotification object:item queue:nil usingBlock:^(NSNotification *note) {
        printf("NOTIFICATION: ErrorLogEntry\n");
    }];

    self.player = [AVPlayer playerWithPlayerItem:item];
    
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
    printf("Starting playback for %s ...\n", urlString.UTF8String);
    [self.player play];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item.status == AVPlayerItemStatusReadyToPlay) {
            printf("AVPlayerItemStatus: READY TO PLAY! Rate: %.2f\n", self.player.rate);
        } else if (item.status == AVPlayerItemStatusFailed) {
            printf("AVPlayerItemStatus: FAILED! Error: %s\n", item.error.localizedDescription.UTF8String);
        } else {
            printf("AVPlayerItemStatus: UNKNOWN (%ld)\n", (long)item.status);
        }
    }
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *url = @"https://coolism-web.cdn.byteark.com/;stream/1";
        if (argc > 1) {
            url = [NSString stringWithUTF8String:argv[1]];
        }
        TestPlayer *tp = [TestPlayer new];
        [tp playStream:url];
        
        // Run loop for 5 seconds to listen to audio and check status
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:5.0];
        while ([end timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            printf("Current rate: %.2f, time: %.1fs\n", tp.player.rate, CMTimeGetSeconds(tp.player.currentTime));
        }
        printf("Done test.\n");
    }
    return 0;
}
