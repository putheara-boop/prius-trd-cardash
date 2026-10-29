#import "H109RTSP.h"

@interface H109RTSP (Stopping)
// Runs on the main queue after the transport has closed, including RTSP TEARDOWN.
- (void)stopWithCompletion:(void (^)(void))completion;
@end
