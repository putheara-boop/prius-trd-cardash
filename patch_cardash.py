with open('d:/Projcet/my_web/cardash_main.m', 'rb') as f:
    content = f.read().decode('utf-8')

old_part1 = 'dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);[self update];\n}'

new_part1 = 'dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);[self update];if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}\n}'

old_part2 = '-(void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self applyTheme];[self applyDisplaySchedule];if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}[self.audioBars start];'

new_part2 = '-(void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self applyTheme];[self applyDisplaySchedule];if(self.welcome){[self.view bringSubviewToFront:self.welcome];}else if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}[self.audioBars start];'

old_part3 = '-(void)viewDidLayoutSubviews{\n [super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width'

new_part3 = '-(void)viewDidLayoutSubviews{\n [super viewDidLayoutSubviews];if(self.welcome){self.welcome.frame=self.view.bounds;[self.view bringSubviewToFront:self.welcome];}CGFloat w=self.view.bounds.size.width'

old_part4 = '-(void)applicationDidBecomeActive:(UIApplication *)app{Dashboard *v=(Dashboard *)self.window.rootViewController;[v cancelBrowseReturn];[v applyDisplaySchedule];[v restoreDisplayBrightness];[v.view setNeedsLayout];'

new_part4 = '-(void)applicationDidBecomeActive:(UIApplication *)app{Dashboard *v=(Dashboard *)self.window.rootViewController;[v cancelBrowseReturn];[v applyDisplaySchedule];[v restoreDisplayBrightness];BOOL welcomePending=[[NSFileManager defaultManager]fileExistsAtPath:@"/var/mobile/codex-car/welcome-pending"];if(welcomePending){[[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/codex-car/welcome-pending" error:nil];[v showWelcome];}[v.view setNeedsLayout];'

assert old_part1 in content, 'part1 not found'
content = content.replace(old_part1, new_part1)
assert old_part2 in content, 'part2 not found'
content = content.replace(old_part2, new_part2)
assert old_part3 in content, 'part3 not found'
content = content.replace(old_part3, new_part3)
assert old_part4 in content, 'part4 not found'
content = content.replace(old_part4, new_part4)

with open('d:/Projcet/my_web/cardash_main.m', 'wb') as f:
    f.write(content.encode('utf-8'))

print('Successfully patched cardash_main.m')
