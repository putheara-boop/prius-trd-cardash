#import "H109RTSP.h"
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreImage/CoreImage.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/select.h>
#include <netinet/tcp.h>

static BOOL readExact(int fd,void *p,size_t n){while(n){ssize_t k=recv(fd,p,n,0);if(k<=0){if(k<0&&errno==EINTR)continue;return NO;}p=(char *)p+k;n-=k;}return YES;}
static BOOL sendAll(int fd,NSData *d){const char *p=d.bytes;size_t n=d.length;while(n){ssize_t k=send(fd,p,n,0);if(k<=0){if(k<0&&errno==EINTR)continue;return NO;}p+=k;n-=k;}return YES;}
static int openTCP(NSString *host,int port){struct addrinfo hints={0},*addresses=NULL;hints.ai_family=AF_INET;hints.ai_socktype=SOCK_STREAM;char service[16];snprintf(service,sizeof(service),"%d",port);if(getaddrinfo(host.UTF8String,service,&hints,&addresses))return -1;int result=-1;for(struct addrinfo *a=addresses;a;a=a->ai_next){int fd=socket(a->ai_family,a->ai_socktype,0);if(fd<0)continue;int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));fcntl(fd,F_SETFL,O_NONBLOCK);int err=connect(fd,a->ai_addr,a->ai_addrlen);if(err<0&&errno==EINPROGRESS){fd_set out;FD_ZERO(&out);FD_SET(fd,&out);struct timeval timeout={3,0};err=select(fd+1,NULL,&out,NULL,&timeout);if(err>0){int e=0;socklen_t len=sizeof(e);getsockopt(fd,SOL_SOCKET,SO_ERROR,&e,&len);err=e?-1:0;}else err=-1;}if(err==0){fcntl(fd,F_SETFL,0);struct timeval timeout={4,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));int rcvbuf=1048576;setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&rcvbuf,sizeof(rcvbuf));int nodelay=1;setsockopt(fd,IPPROTO_TCP,TCP_NODELAY,&nodelay,sizeof(nodelay));result=fd;break;}close(fd);}freeaddrinfo(addresses);return result;}
static NSDictionary *response(int fd,int first){NSMutableData *header=[NSMutableData data];if(first>=0){uint8_t c=first;[header appendBytes:&c length:1];}CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+6;while(header.length<32768){if(CFAbsoluteTimeGetCurrent()>deadline)return nil;uint8_t c;if(!readExact(fd,&c,1))return nil;[header appendBytes:&c length:1];if(header.length>=4&&!memcmp((char *)header.bytes+header.length-4,"\r\n\r\n",4))break;}NSString *text=[[NSString alloc]initWithData:header encoding:NSUTF8StringEncoding];if(!text||![text hasPrefix:@"RTSP/"])return nil;NSArray *lines=[text componentsSeparatedByString:@"\r\n"];NSArray *status=[lines[0] componentsSeparatedByString:@" "];if(status.count<2)return nil;NSMutableDictionary *r=[NSMutableDictionary dictionary];r[@"code"]=@([status[1] integerValue]);for(NSString *line in lines){NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound)continue;r[[[line substringToIndex:colon.location]lowercaseString]]=[[line substringFromIndex:colon.location+1]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];}NSInteger size=[r[@"content-length"]integerValue];if(size<0||size>1048576)return nil;NSMutableData *body=[NSMutableData dataWithLength:size];if(size&&!readExact(fd,body.mutableBytes,size))return nil;r[@"body"]=[[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding]?:@"";return r;}
static BOOL request(int fd,NSString *method,NSString *url,int cseq,NSDictionary *headers){NSMutableString *s=[NSMutableString stringWithFormat:@"%@ %@ RTSP/1.0\r\nCSeq: %d\r\nUser-Agent: H109Viewer/0.2\r\n",method,url,cseq];for(NSString *key in headers)[s appendFormat:@"%@: %@\r\n",key,headers[key]];[s appendString:@"\r\n"];return sendAll(fd,[s dataUsingEncoding:NSUTF8StringEncoding]);}

static NSData *H109ParameterSet(NSData *data){const uint8_t *p=data.bytes;NSUInteger n=data.length;if(n>=4&&p[0]==0&&p[1]==0&&p[2]==0&&p[3]==1)return [data subdataWithRange:NSMakeRange(4,n-4)];if(n>=3&&p[0]==0&&p[1]==0&&p[2]==1)return [data subdataWithRange:NSMakeRange(3,n-3)];return data;}
@interface H109RTSP(){int _fd,_videoPayload;NSUInteger _frameCount;NSMutableData *_fragment,*_unit;uint16_t _nextSequence;uint32_t _fragmentTS,_unitTS;BOOL _assembling,_hasUnitTS;NSData *_sps,*_pps;CMVideoFormatDescriptionRef _format;NSMutableArray *_gop;NSUInteger _gopBytes;BOOL _unitIDR;CFAbsoluteTime _lastFrameAt;}
@property(atomic) BOOL stopped;
@end
@implementation H109RTSP
-(instancetype)init{if((self=[super init])){_fd=-1;_videoPayload=-1;self.stopped=YES;_fragment=[NSMutableData data];_unit=[NSMutableData data];_gop=[NSMutableArray array];}return self;}
-(NSUInteger)frameCount{@synchronized(self){return _frameCount;}}
-(void)notify:(NSString *)text{dispatch_async(dispatch_get_main_queue(),^{if(!self.stopped&&self.status)self.status(text);});}
-(void)stop{@synchronized(self){self.stopped=YES;if(_fd>=0)shutdown(_fd,SHUT_RD);}}
-(void)dealloc{[self clearGOP];if(_format)CFRelease(_format);}
-(void)start:(NSURL *)url{self.stopped=NO;dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool{[self run:url];}});}
// Respect Content-Length: this camera may keep HTTP/1.0 sockets open.
+(NSString *)readMetadata:(NSString *)host path:(NSString *)path{
 int fd=openTCP(host,80);if(fd<0)return nil;NSMutableData *bytes=[NSMutableData data];NSString *result=nil;
 @try{
  NSString *req=[NSString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\nConnection: close\r\nUser-Agent: H109Viewer/0.7\r\n\r\n",path,host];
  if(!sendAll(fd,[req dataUsingEncoding:NSUTF8StringEncoding]))return nil;
  NSData *separator=[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];NSUInteger bodyStart=NSNotFound;long long expected=-1;uint8_t buf[2048];CFAbsoluteTime deadline=CFAbsoluteTimeGetCurrent()+6;
  while(bytes.length<65536&&CFAbsoluteTimeGetCurrent()<deadline){
   ssize_t n=recv(fd,buf,MIN(sizeof(buf),65536-bytes.length),0);if(n<=0)break;[bytes appendBytes:buf length:n];
   if(bodyStart==NSNotFound){NSRange end=[bytes rangeOfData:separator options:0 range:NSMakeRange(0,bytes.length)];if(end.location!=NSNotFound){bodyStart=NSMaxRange(end);NSString *header=[[NSString alloc]initWithData:[bytes subdataWithRange:NSMakeRange(0,end.location)] encoding:NSUTF8StringEncoding];for(NSString *line in [header componentsSeparatedByString:@"\r\n"]){if([line.lowercaseString hasPrefix:@"content-length:"]){NSScanner *scanner=[NSScanner scannerWithString:[line substringFromIndex:15]];if(![scanner scanLongLong:&expected]||expected<0||expected>65536)return nil;}}}}
   if(bodyStart!=NSNotFound&&expected>=0&&bytes.length-bodyStart>=(NSUInteger)expected)break;
  }
  if(bodyStart!=NSNotFound&&(expected<0||bytes.length-bodyStart>=(NSUInteger)expected)){NSString *header=[[NSString alloc]initWithData:[bytes subdataWithRange:NSMakeRange(0,bodyStart)] encoding:NSUTF8StringEncoding];NSArray *status=[[[header componentsSeparatedByString:@"\r\n"]firstObject]componentsSeparatedByString:@" "];if(status.count>1&&[status[1]intValue]==200){NSUInteger size=expected>=0?(NSUInteger)expected:bytes.length-bodyStart;result=[[NSString alloc]initWithData:[bytes subdataWithRange:NSMakeRange(bodyStart,size)] encoding:NSUTF8StringEncoding];}}
 }@finally{close(fd);}return result;
}
+(NSDictionary *)jsonMetadata:(NSString *)host path:(NSString *)path{NSString *text=[self readMetadata:host path:path];if(!text.length)return nil;id value=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];return [value isKindOfClass:[NSDictionary class]]?value:nil;}
static NSMutableDictionary *s_profileCache = nil;
static NSMutableSet *s_sessionOpenedHosts = nil;
+(NSDictionary *)cameraProfile:(NSString *)host{if(!host.length)return nil;if(!s_profileCache)s_profileCache=[NSMutableDictionary dictionary];if(s_profileCache[host])return s_profileCache[host];NSDictionary *r=[self jsonMetadata:host path:@"/app/getproductinfo"];NSDictionary *info=r[@"info"];if(!r||![r[@"result"]isKindOfClass:[NSNumber class]]||[r[@"result"]intValue]!=0||![info isKindOfClass:[NSDictionary class]])return nil;NSString *soc=[info[@"soc"]isKindOfClass:[NSString class]]?[info[@"soc"]lowercaseString]:nil;if(soc.length&&[@[@"eeasytech",@"lombotech"]containsObject:soc]){s_profileCache[host]=info;return info;}return nil;}
+(NSDictionary *)cameraDeviceInfo:(NSString *)host{NSDictionary *r=[self jsonMetadata:host path:@"/app/getdeviceattr"];id info=r[@"info"];return [r[@"result"]isKindOfClass:[NSNumber class]]&&[r[@"result"]intValue]==0&&[info isKindOfClass:[NSDictionary class]]?info:nil;}
+(BOOL)fastSwitchCamera:(NSString *)host index:(NSInteger)index{if(!host.length)return NO;NSDictionary *r=[self jsonMetadata:host path:[NSString stringWithFormat:@"/app/setparamvalue?param=switchcam&value=%ld",(long)index]];return [r[@"result"]isKindOfClass:[NSNumber class]]&&[r[@"result"]intValue]==0;}
+(BOOL)switchCamera:(NSString *)host index:(NSInteger)index{if(![self cameraProfile:host])return NO;NSDictionary *info=[self cameraDeviceInfo:host];if(![info[@"camnum"]isKindOfClass:[NSNumber class]]||![info[@"curcamid"]isKindOfClass:[NSNumber class]]||index<0||index>=[info[@"camnum"]integerValue])return NO;if([info[@"curcamid"]integerValue]!=index){NSDictionary *r=[self jsonMetadata:host path:[NSString stringWithFormat:@"/app/setparamvalue?param=switchcam&value=%ld",(long)index]];if(![r[@"result"]isKindOfClass:[NSNumber class]]||[r[@"result"]intValue]!=0)return NO;}NSDictionary *after=[self cameraDeviceInfo:host];return [after[@"curcamid"]isKindOfClass:[NSNumber class]]&&[after[@"curcamid"]integerValue]==index;}
+(BOOL)openCameraSession:(NSString *)host{if(!host.length)return NO;NSDictionary *r=[self jsonMetadata:host path:@"/app/enterrecorder"];BOOL ok=[r[@"result"]isKindOfClass:[NSNumber class]]&&[r[@"result"]intValue]==0;return ok;}
+(NSArray *)cameraStreamURLs:(NSString *)host{NSDictionary *r=[self jsonMetadata:host path:@"/app/getmediainfo"];id info=r[@"info"];if(![r[@"result"]isKindOfClass:[NSNumber class]]||[r[@"result"]intValue]!=0||![info isKindOfClass:[NSDictionary class]])return @[];id list=info[@"rtsps"];if(![list isKindOfClass:[NSArray class]])list=[info[@"rtsp"]isKindOfClass:[NSString class]]?@[info[@"rtsp"]]:@[];NSMutableArray *urls=[NSMutableArray array];for(id text in list){if(![text isKindOfClass:[NSString class]])continue;NSURL *u=[NSURL URLWithString:text];if(![u.scheme.lowercaseString isEqual:@"rtsp"]||![u.host isEqual:host]||u.user.length||u.password.length)continue;if(!u.path.length)u=[NSURL URLWithString:[text stringByAppendingString:@"/"]];[urls addObject:u];}return urls;}
+(NSDictionary *)describe:(NSURL *)url{int fd=openTCP(url.host,url.port?url.port.intValue:554);if(fd<0)return nil;NSDictionary *r=nil;@try{if(request(fd,@"OPTIONS",url.absoluteString,1,@{}))response(fd,-1);if(request(fd,@"DESCRIBE",url.absoluteString,2,@{@"Accept":@"application/sdp"}))r=response(fd,-1);}@finally{close(fd);}return r;}
-(void)run:(NSURL *)url{
 int fd=-1,udp=-1,rtcp=-1,sequence=1,channel=0;NSString *session=nil;BOOL playing=NO;NSString *uri=url.absoluteString;
 @try{
  if(url.user.length||![url.scheme.lowercaseString isEqual:@"rtsp"]){[self notify:@"URL RTSP ไม่ถูกต้อง หรือมีข้อมูลเข้าสู่ระบบที่ยังไม่รองรับ"];return;}
  if((!url.path.length||[url.path isEqual:@"/"])&&[H109RTSP cameraProfile:url.host]){[self notify:@"Opening camera preview session..."];if(![H109RTSP openCameraSession:url.host]){[self notify:@"Camera preview session could not be opened."];return;}}
  [self notify:@"Connecting to RTSP..."];fd=openTCP(url.host,url.port?url.port.intValue:554);if(fd<0){[self notify:@"เชื่อมต่อ RTSP ไม่ได้ — ตรวจ Wi-Fi และ IP กล้อง"];return;}
  @synchronized(self){if(self.stopped)return;_fd=fd;}
  if(request(fd,@"OPTIONS",uri,sequence++,@{}))response(fd,-1);
  if(!request(fd,@"DESCRIBE",uri,sequence++,@{@"Accept":@"application/sdp"}))return;NSDictionary *r=response(fd,-1);
  if([r[@"code"]intValue]!=200){[self notify:[NSString stringWithFormat:@"RTSP DESCRIBE: %@ — URL ผิด หรือกล้องต้องเข้าสู่ระบบ",r[@"code"]?:@"ไม่ตอบกลับ"]];return;}
  NSString *sdp=r[@"body"],*control=nil;BOOL video=NO,found=NO,h264=NO;NSString *fmtp=nil;
  for(NSString *raw in [sdp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]){NSString *line=[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if([line hasPrefix:@"m="]){if(video&&found)break;video=[line hasPrefix:@"m=video "];if(video)found=YES;}if(!video)continue;if([line hasPrefix:@"a=rtpmap:"]&&[line rangeOfString:@"H264/" options:NSCaseInsensitiveSearch].location!=NSNotFound){h264=YES;_videoPayload=[[line substringFromIndex:9]intValue];}if([line hasPrefix:@"a=control:"])control=[line substringFromIndex:10];if([line containsString:@"sprop-parameter-sets="])fmtp=line;}
  if(!h264){[self notify:@"Stream codec is not H.264. H.265 and other codecs are not supported."];return;}
  if(fmtp){NSString *p=[[fmtp componentsSeparatedByString:@"sprop-parameter-sets="]lastObject];p=[[p componentsSeparatedByString:@";"]firstObject];NSArray *sets=[p componentsSeparatedByString:@","];if(sets.count>=2){_sps=H109ParameterSet([[NSData alloc]initWithBase64EncodedString:sets[0] options:NSDataBase64DecodingIgnoreUnknownCharacters]);_pps=H109ParameterSet([[NSData alloc]initWithBase64EncodedString:sets[1] options:NSDataBase64DecodingIgnoreUnknownCharacters]);}}
  NSString *base=r[@"content-base"]?:uri;NSString *track=uri;if(control.length&&![control isEqual:@"*"]){if([control hasPrefix:@"rtsp://"])track=control;else{if(![base hasSuffix:@"/"])base=[base stringByAppendingString:@"/"];track=[[NSURL URLWithString:control relativeToURL:[NSURL URLWithString:base]]absoluteString];}}
  request(fd,@"SETUP",track,sequence++,@{@"Transport":@"RTP/AVP/TCP;unicast;interleaved=0-1"});r=response(fd,-1);
  if([r[@"code"]intValue]==461){
   int port=0;for(int i=0;i<12;i++){int p=50000+(arc4random_uniform(5000)*2);udp=socket(AF_INET,SOCK_DGRAM,0);rtcp=socket(AF_INET,SOCK_DGRAM,0);struct sockaddr_in addr={0};addr.sin_family=AF_INET;addr.sin_addr.s_addr=htonl(INADDR_ANY);addr.sin_port=htons(p);if(bind(udp,(struct sockaddr *)&addr,sizeof(addr))==0){addr.sin_port=htons(p+1);if(bind(rtcp,(struct sockaddr *)&addr,sizeof(addr))==0){port=p;break;}}if(udp>=0)close(udp);if(rtcp>=0)close(rtcp);udp=rtcp=-1;}
   if(!port){[self notify:@"Could not open UDP receiver"];return;}
   request(fd,@"SETUP",track,sequence++,@{@"Transport":[NSString stringWithFormat:@"RTP/AVP;unicast;client_port=%d-%d",port,port+1]});r=response(fd,-1);
  }
  if([r[@"code"]intValue]!=200){[self notify:[NSString stringWithFormat:@"RTSP SETUP failed: %@",r[@"code"]?:@"ไม่ตอบกลับ"]];return;}
  session=[[r[@"session"]componentsSeparatedByString:@";"]firstObject];if(!session.length){[self notify:@"Camera returned no RTSP session"];return;}
  NSString *transport=r[@"transport"];NSRange inter=[transport rangeOfString:@"interleaved="];if(inter.location!=NSNotFound)channel=[[transport substringFromIndex:inter.location+12]intValue];
  request(fd,@"PLAY",uri,sequence++,@{@"Session":session});r=response(fd,-1);if([r[@"code"]intValue]!=200){[self notify:[NSString stringWithFormat:@"RTSP PLAY failed: %@",r[@"code"]?:@"ไม่ตอบกลับ"]];return;}playing=YES;
  [self notify:udp<0?@"RTSP H.264 over TCP - waiting for video":@"RTSP H.264 over UDP - waiting for video"];
  CFAbsoluteTime started=CFAbsoluteTimeGetCurrent(),lastPacket=started,keepalive=started;
  while(!self.stopped){@autoreleasepool{
   fd_set reads;FD_ZERO(&reads);FD_SET(fd,&reads);int maxfd=fd;if(udp>=0){FD_SET(udp,&reads);maxfd=MAX(maxfd,udp);}if(rtcp>=0){FD_SET(rtcp,&reads);maxfd=MAX(maxfd,rtcp);}struct timeval wait={1,0};int ready=select(maxfd+1,&reads,NULL,NULL,&wait);if(ready<0){if(errno==EINTR)continue;break;}
   if(ready>0&&FD_ISSET(fd,&reads)){uint8_t first;if(!readExact(fd,&first,1))break;if(first=='$'){uint8_t header[3];if(!readExact(fd,header,3))break;size_t length=((size_t)header[1]<<8)|header[2];NSMutableData *packet=[NSMutableData dataWithLength:length];if(!readExact(fd,packet.mutableBytes,length))break;const uint8_t *p=packet.bytes;if(packet.length>=12&&(p[0]>>6)==2&&(p[1]&127)==_videoPayload){[self rtp:packet];lastPacket=CFAbsoluteTimeGetCurrent();}}else if(!response(fd,first))break;}
   if(udp>=0&&ready>0&&FD_ISSET(udp,&reads)){uint8_t packet[65536];ssize_t n=recv(udp,packet,sizeof(packet),0);if(n>0){[self rtp:[NSData dataWithBytes:packet length:n]];lastPacket=CFAbsoluteTimeGetCurrent();}}
   if(rtcp>=0&&ready>0&&FD_ISSET(rtcp,&reads)){uint8_t drop[2048];recv(rtcp,drop,sizeof(drop),0);}
   CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(now-keepalive>12){request(fd,@"OPTIONS",uri,sequence++,@{@"Session":session});keepalive=now;}
   if((!self.frameCount&&now-started>18)||now-lastPacket>15){[self notify:@"No fresh H.264 video received. Check the codec and stream channel."];break;}
  }}
 }@catch(NSException *e){[self notify:[NSString stringWithFormat:@"Invalid RTSP data: %@",e.name]];}
 @finally{if(playing&&fd>=0)request(fd,@"TEARDOWN",uri,sequence++,@{@"Session":session?:@""});@synchronized(self){_fd=-1;}if(fd>=0)close(fd);if(udp>=0)close(udp);if(rtcp>=0)close(rtcp);if(!self.stopped&&self.frameCount)[self notify:@"Live stream connection ended"];dispatch_async(dispatch_get_main_queue(),^{if(self.finished)self.finished();});}
}
-(void)clearGOP{@synchronized(self){for(NSValue *value in _gop)CFRelease([value pointerValue]);[_gop removeAllObjects];_gopBytes=0;_lastFrameAt=0;}}
static void snapshotDecoded(void *context,void *source,OSStatus error,VTDecodeInfoFlags flags,CVImageBufferRef image,CMTime pts,CMTime duration){if(error||!image)return;CVPixelBufferRef *last=(CVPixelBufferRef *)context;if(*last)CVPixelBufferRelease(*last);*last=CVPixelBufferRetain(image);}
-(void)captureFrame:(void (^)(CGImageRef image, NSString *error))completion{
 NSMutableArray *samples=[NSMutableArray array];@synchronized(self){if(!self.stopped&&CFAbsoluteTimeGetCurrent()-_lastFrameAt<2){for(NSValue *value in _gop){CFRetain([value pointerValue]);[samples addObject:value];}}}
 if(!samples.count){dispatch_async(dispatch_get_main_queue(),^{completion(NULL,@"No recent complete video frame. Wait for a keyframe and retry.");});return;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool{
  CVPixelBufferRef last=NULL;VTDecompressionSessionRef decoder=NULL;VTDecompressionOutputCallbackRecord cb={snapshotDecoded,&last};NSDictionary *attrs=@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};CMSampleBufferRef first=[samples[0]pointerValue];OSStatus err=VTDecompressionSessionCreate(NULL,CMSampleBufferGetFormatDescription(first),NULL,(__bridge CFDictionaryRef)attrs,&cb,&decoder);
  if(!err){for(NSValue *value in samples){VTDecodeInfoFlags flags=0;err=VTDecompressionSessionDecodeFrame(decoder,[value pointerValue],0,NULL,&flags);if(err)break;}VTDecompressionSessionWaitForAsynchronousFrames(decoder);VTDecompressionSessionInvalidate(decoder);CFRelease(decoder);}
  for(NSValue *value in samples)CFRelease([value pointerValue]);
  CGImageRef image=NULL;if(!err&&last){CIContext *context=[CIContext contextWithOptions:nil];CIImage *source=[CIImage imageWithCVPixelBuffer:last];image=[context createCGImage:source fromRect:source.extent];}if(last)CVPixelBufferRelease(last);
  dispatch_async(dispatch_get_main_queue(),^{completion(image,image?nil:@"Could not decode this snapshot. Wait for a new keyframe.");if(image)CGImageRelease(image);});
 }});
}
-(void)rtp:(NSData *)data{
 const uint8_t *p=data.bytes;size_t n=data.length;if(n<12||(p[0]>>6)!=2||(_videoPayload>=0&&(p[1]&127)!=_videoPayload))return;size_t off=12+4*(p[0]&15);if(off>n)return;if(p[0]&16){if(off+4>n)return;size_t ext=4+4*(((size_t)p[off+2]<<8)|p[off+3]);if(ext>n-off)return;off+=ext;}if(p[0]&32){unsigned pad=p[n-1];if(!pad||pad>n-off)return;n-=pad;}if(off>=n)return;
 uint16_t seq=((uint16_t)p[2]<<8)|p[3];uint32_t ts=((uint32_t)p[4]<<24)|((uint32_t)p[5]<<16)|((uint32_t)p[6]<<8)|p[7];BOOL marker=(p[1]&128)!=0;p+=off;n-=off;unsigned type=p[0]&31;
 if(type>=1&&type<=23){_assembling=NO;[self nal:p length:n timestamp:ts marker:marker];return;}
 if(type==24){_assembling=NO;size_t at=1;while(at<n){if(at+2>n)return;size_t size=((size_t)p[at]<<8)|p[at+1];at+=2;if(!size||size>n-at)return;at+=size;}at=1;while(at<n){size_t size=((size_t)p[at]<<8)|p[at+1];at+=2;[self nal:p+at length:size timestamp:ts marker:marker&&at+size==n];at+=size;}return;}
 if(type!=28||n<3){_assembling=NO;return;}BOOL start=(p[1]&128)!=0,end=(p[1]&64)!=0;if(start&&end){_assembling=NO;return;}
 if(start){[_fragment setLength:0];uint8_t header=(p[0]&224)|(p[1]&31);[_fragment appendBytes:&header length:1];_assembling=YES;_fragmentTS=ts;}else if(!_assembling||_fragmentTS!=ts||seq!=_nextSequence){_assembling=NO;return;}
 if(_fragment.length+n-2>2097152){_assembling=NO;return;}[_fragment appendBytes:p+2 length:n-2];_nextSequence=seq+1;if(end){[self nal:_fragment.bytes length:_fragment.length timestamp:ts marker:marker];_assembling=NO;}
}
// Lombotech places Annex B SPS/PPS/IDR together inside one FU-A unit.
// Split only actual start codes, retaining the frame marker on the final NAL.
-(void)nal:(const uint8_t *)p length:(size_t)n timestamp:(uint32_t)ts marker:(BOOL)marker{
 size_t start=0,scan=0;BOOL split=NO;
 while(scan+3<=n){size_t prefix=0;if(p[scan]==0&&p[scan+1]==0){if(scan+4<=n&&p[scan+2]==0&&p[scan+3]==1)prefix=4;else if(p[scan+2]==1)prefix=3;}if(!prefix){scan++;continue;}if(scan>start)[self nalUnit:p+start length:scan-start timestamp:ts marker:NO];start=scan+prefix;scan=start;split=YES;}
 if(split){if(start<n)[self nalUnit:p+start length:n-start timestamp:ts marker:marker];}else [self nalUnit:p length:n timestamp:ts marker:marker];
}
-(void)nalUnit:(const uint8_t *)p length:(size_t)n timestamp:(uint32_t)ts marker:(BOOL)marker{
 if(!n)return;unsigned type=p[0]&31;if(type==7||type==8){NSData *new=[NSData dataWithBytes:p length:n];NSData *old=type==7?_sps:_pps;if(![new isEqualToData:old]&&_format){[self clearGOP];CFRelease(_format);_format=NULL;}if(type==7)_sps=new;else _pps=new;return;}
 if(!_hasUnitTS||_unitTS!=ts){[_unit setLength:0];_unitTS=ts;_hasUnitTS=YES;_unitIDR=NO;}
 if(type==5)_unitIDR=YES;
 if(type==1||type==5||type==6||type==9){if(_unit.length+n+4>4194304){[_unit setLength:0];return;}uint32_t size=htonl((uint32_t)n);[_unit appendBytes:&size length:4];[_unit appendBytes:p length:n];}
 if(!marker||!_unit.length||!_sps.length||!_pps.length)return;
 if(!_format){const uint8_t *sets[]={_sps.bytes,_pps.bytes};size_t sizes[]={_sps.length,_pps.length};if(CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,2,sets,sizes,4,&_format)!=noErr){[_unit setLength:0];return;}}
 CMBlockBufferRef block=NULL;CMSampleBufferRef sample=NULL;size_t size=_unit.length;OSStatus err=CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,NULL,size,kCFAllocatorDefault,NULL,0,size,0,&block);if(err==noErr)err=CMBlockBufferReplaceDataBytes(_unit.bytes,block,0,size);CMSampleTimingInfo timing={kCMTimeInvalid,kCMTimeInvalid,kCMTimeInvalid};if(err==noErr)err=CMSampleBufferCreateReady(kCFAllocatorDefault,block,_format,1,1,&timing,1,&size,&sample);if(sample){CFArrayRef attachments=CMSampleBufferGetSampleAttachmentsArray(sample,YES);if(attachments&&CFArrayGetCount(attachments))CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments,0),kCMSampleAttachmentKey_DisplayImmediately,kCFBooleanTrue);@synchronized(self){_frameCount++;if(_unitIDR)[self clearGOP];if(_unitIDR||_gop.count){if(_gopBytes+size>8388608||_gop.count>=180)[self clearGOP];else{CFRetain(sample);[_gop addObject:[NSValue valueWithPointer:sample]];_gopBytes+=size;_lastFrameAt=CFAbsoluteTimeGetCurrent();}}}if(self.sample&&!self.stopped)self.sample(sample);CFRelease(sample);}if(block)CFRelease(block);[_unit setLength:0];
}
@end
