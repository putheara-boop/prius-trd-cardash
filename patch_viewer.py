with open('d:/Projcet/my_web/viewer_main.m', 'rb') as f:
    text = f.read().decode('utf-8')

text = text.replace('\r\r\n', '\n').replace('\r\n', '\n')

old_check = ''' BOOL ready=[network[@"SSID"]isEqual:self.cameraSSID]&&[state[@"mode"]isEqual:@"camera"]&&[state[@"phase"]isEqual:@"ready"]&&[state[@"actualSSID"]isEqual:self.cameraSSID];
 if(ready){[self.networkWait invalidate];self.networkWait=nil;NSString *cached=[[NSUserDefaults standardUserDefaults]stringForKey:@"lastWorkingStream"];if(cached.length&&[cached hasPrefix:@"rtsp://"]){self.status.text=@"Fast-connecting to camera stream...";self.address.text=cached;[self connect];return;}[self discover];return;}'''

new_check = ''' BOOL ready=[network[@"SSID"]isEqual:self.cameraSSID] || ([state[@"phase"]isEqual:@"ready"]&&[state[@"actualSSID"]isEqual:self.cameraSSID]);
 if(ready){[self.networkWait invalidate];self.networkWait=nil;NSString *cached=[[NSUserDefaults standardUserDefaults]stringForKey:@"lastWorkingStream"];if(!cached.length||![cached hasPrefix:@"rtsp://"]){cached=@"rtsp://192.168.169.1/xxxx.mov";[[NSUserDefaults standardUserDefaults]setObject:cached forKey:@"lastWorkingStream"];[[NSUserDefaults standardUserDefaults]synchronize];}self.status.text=@"Fast-connecting to camera stream...";self.address.text=cached;[self connect];return;}'''

assert old_check in text, 'old_check not found'
text = text.replace(old_check, new_check)

with open('d:/Projcet/my_web/viewer_main.m', 'wb') as f:
    f.write(text.encode('utf-8'))

print('Patched viewer_main.m successfully')
