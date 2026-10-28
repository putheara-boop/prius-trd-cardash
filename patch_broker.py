with open('d:/Projcet/my_web/TRDNetworkBroker.m', 'rb') as f:
    text = f.read().decode('utf-8')

text = text.replace('\r\r\n', '\n').replace('\r\n', '\n')

text = text.replace('self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:12];', 'self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:25];')
text = text.replace('if(self.attempt>=3){[self failed:', 'if(self.attempt>=12){[self failed:')

old_failed = '-(void)failed:(NSString *)error{[self.timer invalidate];self.timer=nil;if([self.mode isEqual:@"camera"]&&!self.restoring){'
new_failed = '-(void)failed:(NSString *)error{[self.timer invalidate];self.timer=nil;if(NO && [self.mode isEqual:@"camera"]&&!self.restoring){'
assert old_failed in text, 'old_failed not found'
text = text.replace(old_failed, new_failed)

with open('d:/Projcet/my_web/TRDNetworkBroker.m', 'wb') as f:
    f.write(text.encode('utf-8'))

print('Patched TRDNetworkBroker.m successfully')
