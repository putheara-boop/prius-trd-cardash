#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreGraphics/CoreGraphics.h>
#include <spawn.h>

FOUNDATION_EXPORT NSString *H109En0IPv4(void);
FOUNDATION_EXPORT NSString *H109CameraGatewayHost(void);
FOUNDATION_EXPORT NSString *H109ResolvedCameraSSID(void);

@interface H109RTSP : NSObject
@property(nonatomic) NSInteger targetChannel;
@property(nonatomic,copy) void (^status)(NSString *text);
@property(nonatomic,copy) void (^sample)(CMSampleBufferRef sample);
@property(nonatomic,copy) void (^finished)(void);
@property(nonatomic,copy) void (^channelUpdated)(NSInteger channel, BOOL switched);
@property(nonatomic,readonly) NSUInteger frameCount;
-(void)start:(NSURL *)url;
-(void)stop;
-(void)stopWithCompletion:(void (^)(void))completion;
-(void)requestKeyframeWait;
-(void)clearGOP;
-(void)captureFrame:(void (^)(CGImageRef image, NSString *error))completion;
+(NSString *)readMetadata:(NSString *)host path:(NSString *)path;
+(NSDictionary *)cameraProfile:(NSString *)host;
+(NSDictionary *)cameraDeviceInfo:(NSString *)host;
+(BOOL)fastSwitchCamera:(NSString *)host index:(NSInteger)index;
+(BOOL)switchCamera:(NSString *)host index:(NSInteger)index;
+(BOOL)openCameraSession:(NSString *)host;
+(NSArray *)cameraStreamURLs:(NSString *)host;
+(NSDictionary *)describe:(NSURL *)url;
@end
