with open('d:/Projcet/my_web/H109HUD.h', 'rb') as f:
    text = f.read().decode('utf-8')

text = text.replace('\r\r\n', '\n').replace('\r\n', '\n')

# 1. Set double tap to quickSnapshot instead of toggleFull
old_tap = 'UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(toggleFull)];doubleTap.numberOfTapsRequired=2;[self.picture addGestureRecognizer:doubleTap];'
new_tap = 'UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(quickSnapshot)];doubleTap.numberOfTapsRequired=2;[self.picture addGestureRecognizer:doubleTap];'
assert old_tap in text, 'old_tap not found'
text = text.replace(old_tap, new_tap)

# 2. Make fullscreen default to YES
old_full = 'self.exitFull=[self hudButton:@"✕ EXIT" action:@selector(toggleFull)];'
new_full = 'self.exitFull=[self hudButton:@"≡ MENU" action:@selector(toggleFull)];self.fullscreen=YES;'
assert old_full in text, 'old_full not found'
text = text.replace(old_full, new_full)

with open('d:/Projcet/my_web/H109HUD.h', 'wb') as f:
    f.write(text.encode('utf-8'))

print('Patched H109HUD.h successfully')
