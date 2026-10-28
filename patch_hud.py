with open('d:/Projcet/my_web/H109HUD.h', 'rb') as f:
    text = f.read().decode('utf-8')

text = text.replace('\r\r\n', '\n').replace('\r\n', '\n')

old_hud = '''-(void)selectReportedCamera{
 NSInteger selected=self.channels.selectedSegmentIndex;if(self.parkingGuideView)self.parkingGuideView.hidden=!(self.showGuide&&selected==1);if(selected==1&&!self.mirrored)[self toggleMirror];else if(selected==0&&self.mirrored)[self toggleMirror];[self updateFullHUD];
 NSString *host=[NSURL URLWithString:self.address.text].host;if(!host.length)return;
 self.retryScheduled=NO;self.status.text=@"⚡ Fast switching...";self.stateLabel.text=@"SWITCHING";
 NSUInteger generation=self.discoveryGeneration;__weak Viewer *weak=self;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
  BOOL switched=[H109RTSP fastSwitchCamera:host index:selected];
  if(!switched)switched=[H109RTSP switchCamera:host index:selected];
  dispatch_async(dispatch_get_main_queue(),^{
   Viewer *v=weak;if(!v||v.discoveryGeneration!=generation)return;
   if(!switched){
    v.status.text=@"Camera switch was not confirmed. Tap FIND to reconnect.";
    v.stateLabel.text=@"OFFLINE";
    return;
   }
   v.channels.selectedSegmentIndex=selected;
   v.retryCount=0;
   [v updateFullHUD];
   [v connect];
  });
 });
}'''

new_hud = '''-(void)selectReportedCamera{
 NSInteger selected=self.channels.selectedSegmentIndex;if(self.parkingGuideView)self.parkingGuideView.hidden=!(self.showGuide&&selected==1);if(selected==1&&!self.mirrored)[self toggleMirror];else if(selected==0&&self.mirrored)[self toggleMirror];[self updateFullHUD];
 NSString *host=[NSURL URLWithString:self.address.text].host;if(!host.length)host=@"192.168.169.1";
 [self stopTransport];
 self.retryScheduled=NO;self.status.text=@"⚡ Fast switching...";self.stateLabel.text=@"SWITCHING";
 __weak Viewer *weak=self;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
  BOOL switched=[H109RTSP fastSwitchCamera:host index:selected];
  if(!switched)switched=[H109RTSP switchCamera:host index:selected];
  [NSThread sleepForTimeInterval:0.25];
  dispatch_async(dispatch_get_main_queue(),^{
   Viewer *v=weak;if(!v)return;
   v.channels.selectedSegmentIndex=selected;
   v.retryCount=0;
   [v updateFullHUD];
   [v connect];
  });
 });
}'''

assert old_hud in text, 'old_hud not found'
text = text.replace(old_hud, new_hud)

with open('d:/Projcet/my_web/H109HUD.h', 'wb') as f:
    f.write(text.encode('utf-8'))

print('Patched H109HUD.h successfully')
