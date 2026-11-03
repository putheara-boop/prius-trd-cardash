#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        NSLog(@"Testing radio streams on iOS 9...");
        
        NSArray *urls = @[
            @{@"name": @"JS100", @"url": @"http://sv4.hostpleng.com:8184/;stream.mp3"},
            @{@"name": @"FM91", @"url": @"https://www.fm91bkk.com:8900/;stream.mp3"},
            @{@"name": @"COOL", @"url": @"https://coolism-web.cdn.byteark.com/;stream/1"},
            @{@"name": @"EFM", @"url": @"http://real4.atimemedia.com/efm"},
            @{@"name": @"GreenWave", @"url": @"http://real4.atimemedia.com/green"}
        ];
        
        for (NSDictionary *d in urls) {
            NSString *name = d[@"name"];
            NSString *urlStr = d[@"url"];
            NSURL *u = [NSURL URLWithString:urlStr];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:4.0];
            [req setHTTPMethod:@"GET"];
            [req setValue:@"bytes=0-1024" forHTTPHeaderField:@"Range"];
            [req setValue:@"Mozilla/5.0 (iPad; CPU OS 9_3_6 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
            
            NSHTTPURLResponse *resp = nil;
            NSError *err = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
            
            if (err) {
                printf("%-10s -> ERROR: %s\n", [name UTF8String], [[err localizedDescription] UTF8String]);
            } else {
                printf("%-10s -> STATUS %ld, Type: %s, Bytes: %lu\n", 
                    [name UTF8String], 
                    (long)resp.statusCode, 
                    [[resp MIMEType] UTF8String] ?: "none",
                    (unsigned long)data.length);
            }
        }
        
        // Also check AVAudioSession
        AVAudioSession *session = [AVAudioSession sharedInstance];
        printf("\nAVAudioSession category: %s\n", [[session category] UTF8String]);
        printf("Current route: %s\n", [[[session currentRoute] description] UTF8String]);
    }
    return 0;
}
