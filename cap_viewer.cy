var surface = [[UIApp keyWindow] rootViewController].view;
UIGraphicsBeginImageContextWithOptions(surface.bounds.size, YES, 1);
[surface drawViewHierarchyInRect:surface.bounds afterScreenUpdates:YES];
var img = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
[UIImagePNGRepresentation(img) writeToFile:@"/var/mobile/h109-build/viewer_capture.png" atomically:YES];
