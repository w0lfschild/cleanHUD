//
//  AppDelegate.m
//  testAPP
//
//  Created by Wolfgang Baird on 11/24/17.
//  Copyright © 2017 Wolfgang Baird. All rights reserved.
//

@import AppKit;
@import ImageIO;
@import CoreAudio;

#import "MDCFullScreenDetector.h"
#import "AYProgressIndicator.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *img;
@property (weak) IBOutlet NSView *custom;
- (IBAction)showHUD :(id)sender;
- (void)showHUD :(int)hudType :(float)hudValue;
@end

@interface my_NSWindow : NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen;
@end

@implementation my_NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen {
    return frameRect;
}
@end

// Variables

my_NSWindow *myWin;
AYProgressIndicator *indi;
NSView *indiBackground;
NSVisualEffectView *indiBlur;
int animateHUD;
float mybrightness;
NSInteger osx_ver;
NSImageView *vol;
NSArray *imageStorage;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchedToFullScreenApp:) name:kMDCFullScreenDetectorSwitchedToFullScreenApp object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchedToRegularSpace:) name:kMDCFullScreenDetectorSwitchedToRegularSpace object:nil];
    
    // Insert code here to initialize your application
//    [self.window setOpaque:false];
//    [self.window setBackgroundColor:[NSColor clearColor]];
//    NSLog(@"%@", [self averageColor:[self windowImageShot:self.window]]);
//    [self.window setBackgroundColor:[self averageColor:[self windowImageShot:self.window]]];

//    self.window.restorable = YES;
//    self.window.restorationClass = [self class];
//    self.window.identifier = @"Win";
    
    [self.window makeKeyAndOrderFront:nil];
    [self.window setLevel:NSMainMenuWindowLevel + 2];
    [self.window setMovableByWindowBackground:true];
    [self.window makeKeyAndOrderFront:nil];
    [self.window setIgnoresMouseEvents:NO];
    [self.window setOpaque:false];
    [self.custom setHidden:true];
//    [self.window setFrame:NSMakeRect(0, [NSScreen mainScreen].frame.size.height, 600, 200) display:true];
    
    NSVisualEffectView *vibrance = [[NSVisualEffectView alloc] initWithFrame:[[self.window contentView] bounds]];
    [vibrance setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [vibrance setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [vibrance setMaterial:NSVisualEffectMaterialPopover];
    [[self.window contentView] addSubview:vibrance positioned:NSWindowBelow relativeTo:nil];
    
    
    [self initializeWindow];
    [self showHUD:0 :100.0];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
//        [self contextXolors];
//        [self.custom setHidden:false];
//    });
}

- (void)showNotification:(NSString *)message {
    NSLog(@"%@", message);
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Full Screen Status Changed";
    notification.informativeText = message;
    notification.soundName = nil;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)switchedToFullScreenApp:(NSNotification *)n {
    [self showNotification:@"On a full screen app"];
}

- (void)switchedToRegularSpace:(NSNotification *)n {
    [self showNotification:@"On a regular space"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
//    [self.window saveFrameUsingName:@"Win"];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)contextXolors {
    NSDate *methodStart = [NSDate date];
    
    CGWindowID windowID = (CGWindowID)[self.window windowNumber];
    int multiplier = 1;
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)])
        multiplier = [[NSScreen mainScreen] backingScaleFactor];
    
    NSRect mf = self.window.frame;
    NSRect sf = [NSScreen mainScreen].frame;
    int w = mf.size.width;
    int h = mf.size.height;
    
    int y = mf.origin.y;
    if (y >= 0)
        y = (sf.size.height - mf.origin.y - mf.size.height - fabs(sf.origin.y));
    else
        y = (sf.size.height + mf.origin.y + mf.size.height + sf.origin.y);
    
    if (y > sf.size.height) {
        h = y - sf.size.height;
        y = sf.size.height - h;
    }
    
    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
    CGImageRef screenShot = CGWindowListCreateImage(trueFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:screenShot];
    NSImage *image = [[NSImage alloc] init];
    [image addRepresentation:bitmapRep];
    bitmapRep = nil;
    
    NSLog(@"Screenshot : %zu, %zu", CGImageGetWidth(screenShot), CGImageGetHeight(screenShot));
    NSLog(@"My Frame : %@", NSStringFromRect(mf));
    NSLog(@"Screen Frame : %@", NSStringFromRect(sf));
    NSLog(@"True Frame : %@", NSStringFromRect(trueFrame));

    Boolean result = true;
    NSColor *backGround = [self averageColor:screenShot];
    NSLog(@"True Frame : %@", backGround);
    double a = 1 - ( 0.299 * backGround.redComponent * 255 + 0.587 * backGround.greenComponent * 255 + 0.114 * backGround.blueComponent * 255)/255;
    if (a < 0.5)
        result = true; // bright colors - black font
    else
        result = false; // dark colors - white font
    
    NSLog(@"%f", a);
    
    [self.img setImage:image];
    [self.custom.layer setBackgroundColor:[self averageColor:screenShot].CGColor];
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime = %f", executionTime);
}

- (void)contextXolor {
    NSDate *methodStart = [NSDate date];

    CGWindowID windowID = (CGWindowID)[self.window windowNumber];
    NSRect limiter = [[NSScreen mainScreen] frame];
    CGImageRef screenShot = CGWindowListCreateImage(limiter, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
//    CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenBelowWindow, kCGNullWindowID, kCGWindowImageDefault);
//    CGImageRef screenShot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
    NSRect mf = self.window.frame;
    NSRect sf = [NSScreen mainScreen].frame;
    int multiplyer = CGImageGetWidth(screenShot) / sf.size.width;
//    mf.size.height = self.window.contentView.frame.size.height;
//    mf.origin.y -= 22;
    
    int x = mf.origin.x;
    if (x >= 0)
        x = mf.origin.x * multiplyer;
    else
        x = (sf.size.width + mf.origin.x) * multiplyer;
    
    int y = mf.origin.y;
    if (y >= 0)
        y = (sf.size.height - mf.origin.y - mf.size.height) * multiplyer;
    else
        y = (sf.size.height + mf.origin.y + mf.size.height) * multiplyer;
    
    NSRect trueFrame = CGRectMake(x, y, mf.size.width * multiplyer, mf.size.height * multiplyer);

    NSLog(@"Screen Frame : %@", NSStringFromRect(sf));
    NSLog(@"Screenshot : %zu, %zu", CGImageGetWidth(screenShot), CGImageGetHeight(screenShot));
    NSLog(@"My Frame : %@", NSStringFromRect(mf));
    NSLog(@"Crop Rect : %@", NSStringFromRect(trueFrame));
    NSLog(@"%d : %d", x, y);
    
    CGRect cropRect = trueFrame;
    CGImageRef imageRef = CGImageCreateWithImageInRect(screenShot, cropRect);
    
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
    NSImage *image = [[NSImage alloc] init];
    [image addRepresentation:bitmapRep];
    bitmapRep = nil;
    
    [self.img setImage:image];
    [self.custom.layer setBackgroundColor:[self averageColor:imageRef].CGColor];
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime = %f", executionTime);
}

- (CGImageRef)windowImageShot:(NSWindow *)win
{
    CGWindowID windowID = (CGWindowID)[win windowNumber];
    CGWindowImageOption imageOptions = kCGWindowImageDefault;
    CGWindowListOption singleWindowListOptions = kCGWindowListOptionIncludingWindow;
    CGRect imageBounds = CGRectNull;
    CGImageRef windowImage = CGWindowListCreateImage(imageBounds, singleWindowListOptions, windowID, imageOptions);
    return windowImage;
}

- (IBAction)showHUD :(id)sender {
    [self showHUD:0 :arc4random() % (101)];
}

- (void)initializeWindow {
    // Use some system images for the volume indicator
    NSMutableArray *blackVolumeImages = [NSMutableArray new];
    NSMutableArray *whiteVolumeImages = [NSMutableArray new];
    
    NSString *bundlePath    = [[NSBundle bundleForClass:[self class]] bundlePath];
    for (int numb = 1; numb <= 4; numb++) {
        [blackVolumeImages addObject:[[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/Volume%d_blk.png", bundlePath, numb]]];
        [whiteVolumeImages addObject:[[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/Volume%d.png", bundlePath, numb]]];
    }
    NSImage *blackScreen    = [[NSImage alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Contents/Resources/display_icon_blk.png"]];
    NSImage *whiteScreen    = [[NSImage alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Contents/Resources/display_icon.png"]];
    NSImage *blackKeyboard  = [[NSImage alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Contents/Resources/keyboard_icon_blk.png"]];
    NSImage *whiteKeyboard  = [[NSImage alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Contents/Resources/keyboard_icon.png"]];
    NSArray *volumeIMG      = [[NSArray alloc] initWithObjects:[blackVolumeImages copy], [whiteVolumeImages copy], nil];
    NSArray *screenIMG      = [[NSArray alloc] initWithObjects:blackScreen, whiteScreen, nil];
    NSArray *keyboardIMG    = [[NSArray alloc] initWithObjects:blackKeyboard, whiteKeyboard, nil];
    
    imageStorage = [[NSArray alloc] initWithObjects:volumeIMG, screenIMG, keyboardIMG, nil];
    animateHUD = 0;
    
    // Set up window to float above menubar
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect(scr.origin.x + (scr.size.width / 2) - 117, scr.origin.y + scr.size.height, 234, 22)
                                           styleMask:0
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setMovableByWindowBackground:YES];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setIgnoresMouseEvents:NO];
    [myWin setOpaque:false];
    [myWin setBackgroundColor:[NSColor clearColor]];
    
    // Set up indicator to show volume percentage
    indi = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(28, 9, 204, 4)
                                        progressColor:[NSColor whiteColor]
                                           emptyColor:[NSColor clearColor]
                                             minValue:0
                                             maxValue:100
                                         currentValue:0];
    [indi setHidden:NO];
    [indi setWantsLayer:YES];
    [indi.layer setCornerRadius:2];
    
    indiBackground = [[NSView alloc] init];
    [indiBackground setFrame:NSMakeRect(29, 8, 202, 6)];
    [indiBackground setHidden:NO];
    [indiBackground setWantsLayer:YES];
    [indiBackground.layer setCornerRadius:3];
    [indiBackground.layer setBackgroundColor:[NSColor clearColor].CGColor];
    [indiBackground.layer setBorderColor:[NSColor whiteColor].CGColor];
    [indiBackground.layer setBorderWidth:1];
    
    indiBlur = [[NSVisualEffectView alloc] initWithFrame:[myWin.contentView bounds]];
    [indiBlur setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [indiBlur setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [indiBlur setMaterial:NSVisualEffectMaterialDark];
    [indiBlur setState:NSVisualEffectStateActive];
    
    // Set up imageview for showing volume indicator
    vol = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 0, 22, 22)];
    
    // Add subviews to window HUD
    [myWin.contentView setWantsLayer:true];
    [myWin.contentView addSubview:indiBlur];
    [myWin.contentView addSubview:indiBackground];
    [myWin.contentView addSubview:indi];
    [myWin.contentView addSubview:vol];
    
    // Round conrners
    [myWin.contentView.layer setCornerRadius:4];
    
    // Hide HUD
    [myWin setAlphaValue:0.0];
}

- (void)showHUD :(int)hudType :(float)hudValue {
    // Set progressbar
    [indi setDoubleValue:100];
    [indi setDoubleValue:hudValue];
    
    // Check for Dark mode
    int darkMode = 0;
    //    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    //    if ([osxMode isEqualToString:@"Dark"]) darkMode = 1; else darkMode = 0;
    NSImage *displayImage = [NSImage new];
    
//    myWin
    Boolean useDark = [self useDarkColors];
    darkMode = useDark;
        
    //    NSLog(@"cleanHUD: Darkmode : %d", darkMode);
    
    // Dark mode / Light mode
    if (useDark) {
        [indi setProgressColor:[NSColor whiteColor]];
        [indiBackground.layer setBorderColor:[NSColor whiteColor].CGColor];
        [indiBlur setMaterial:NSVisualEffectMaterialDark];
    } else {
        [indi setProgressColor:[NSColor blackColor]];
        [indiBackground.layer setBorderColor:[NSColor blackColor].CGColor];
        [indiBlur setMaterial:NSVisualEffectMaterialSelection];
    }
    
    // Set icon
    NSArray *imagesArray = [imageStorage objectAtIndex:hudType];
    if (hudType != 0) {
        displayImage = [imagesArray objectAtIndex:darkMode];
    } else {
        NSArray *imgList = [[NSArray alloc] initWithArray:[imagesArray objectAtIndex:darkMode]];
        if ([self getMuteState]) {
            [indi setDoubleValue:0];
            displayImage = [imgList objectAtIndex:0];
        } else {
            displayImage = [imgList objectAtIndex:ceil(hudValue / 33.34)];
        }
    }
    
    [indi updateLayer];
    [vol setImage:displayImage];
    
    // Position the HUD in the middle of the menubar on the active screen
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    float xPos = scr.origin.x + (scr.size.width / 2) - 117;
    float yPos = scr.origin.y + scr.size.height + 1;
    
    // Adjust for fullscreen
    if ([NSApp presentationOptions] == NSApplicationPresentationAutoHideMenuBar ||
        [NSApp presentationOptions] == NSApplicationPresentationHideMenuBar) {
        if (NSEvent.mouseLocation.y < scr.size.height - 22)
            yPos -= 22;
    }
        
    // Adjust for fullscreen
    if (yPos == scr.size.height || yPos == scr.size.height + scr.origin.y)
        yPos -= 22;
    
    // Set origin
//    CGPoint frmLoc = CGPointMake(xPos, yPos);
//    [myWin setFrameOrigin:frmLoc];
    
    NSDate *methodStart = [NSDate date];
    Boolean iOSStyle;
    CFPreferencesGetAppBooleanValue( CFSTR("iOSStyle"), CFSTR("org.w0lf.cleanHUD"), &iOSStyle);
    NSLog(@"%hhu", iOSStyle);
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime = %f", executionTime);
    
    // iOS style
    yPos -= 58;
    xPos -= 32;
    [indi setHidden:true];
    [indiBackground.layer setBorderColor:indi.emptyColor.CGColor];
    [indiBackground.layer setBackgroundColor:NSColor.whiteColor.CGColor];
    [indiBackground.layer setCornerRadius:0];
    [indiBackground setFrame:CGRectMake(0, 0, 300 * (indi.doubleValue / 100), 30)]; // 300 * (indi.doubleValue / 100)
    [myWin.contentView.layer setCornerRadius:10];
    [myWin setFrame:CGRectMake(xPos, yPos, 300, 30) display:true];
    if (hudType == 0) {
        NSArray *imgList = [[NSArray alloc] initWithArray:[imagesArray objectAtIndex:0]];
        if ([self getMuteState]) {
            [indi setDoubleValue:0];
            displayImage = [imgList objectAtIndex:0];
        } else {
            displayImage = [imgList objectAtIndex:ceil(hudValue / 33.34)];
        }
    }
    [vol setImage:displayImage];
    [vol setFrame:CGRectMake(10, 0, 30, 30)];
    
    // Set window level to be above everything
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    
    // Hide the window in 1 second
    animateHUD ++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self hideHUD];
    });
    
    // Cancel any existing animation and show the window
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [[myWin animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}

- (void)hideHUD {
    if (animateHUD == 1) {
        // Fade out the HUD
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 1;
            myWin.animator.alphaValue = 0;
        } completionHandler:^{ }];
    }
    if (animateHUD > 0)
        animateHUD--;
}

- (BOOL)getMuteState {
    AudioObjectPropertyAddress outputDeviceAOPA;
    outputDeviceAOPA.mSelector= kAudioHardwarePropertyDefaultOutputDevice;
    outputDeviceAOPA.mScope= kAudioObjectPropertyScopeGlobal;
    outputDeviceAOPA.mElement= kAudioObjectPropertyElementMaster;
    
    AudioObjectID outputDeviceID = kAudioObjectUnknown;
    UInt32 propertySize = sizeof(AudioDeviceID);
    
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &outputDeviceAOPA,
                               0, nil, &propertySize, &outputDeviceID);
    
    AudioObjectPropertyAddress volumeAOPA;
    volumeAOPA.mSelector= kAudioDevicePropertyMute;
    volumeAOPA.mScope= kAudioObjectPropertyScopeOutput;
    volumeAOPA.mElement= kAudioObjectPropertyElementMaster;
    
    UInt32 isMuted = 0;
    UInt32 propSize = sizeof(UInt32);
    
    AudioObjectGetPropertyData(outputDeviceID, &volumeAOPA, 0, nil, &propSize, &isMuted);
    
    return (BOOL)isMuted;
}

- (Boolean)useDarkColors {
    Boolean result = true;
    CGImageRef screenGrab = [self contextColors];
    NSColor *backGround = [self averageColor:screenGrab];
    CFRelease(screenGrab);
    double a = 1 - ( 0.299 * backGround.redComponent * 255 + 0.587 * backGround.greenComponent * 255 + 0.114 * backGround.blueComponent * 255)/255;
    if (a < 0.5)
        result = false; // bright colors - black font
    else
        result = true; // dark colors - white font
    return result;
}

- (CGImageRef)contextColors {
    int multiplier = 1;
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)])
        multiplier = [[NSScreen mainScreen] backingScaleFactor];
    
    NSRect mf = myWin.frame;
    NSRect sf = [NSScreen mainScreen].frame;
    int w = mf.size.width;
    int h = mf.size.height;
    
    int y = mf.origin.y;
    if (y >= 0)
        y = (sf.size.height - mf.origin.y - mf.size.height - fabs(sf.origin.y));
    else
        y = (sf.size.height + mf.origin.y + mf.size.height + sf.origin.y);
    
    if (y > sf.size.height) {
        h = y - sf.size.height;
        y = sf.size.height - h;
    }
    
    NSDate *methodStart = [NSDate date];
    
    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
    NSArray *blockWindows = @[@"OSDUIHelper", @"Control Strip", @"loginwindow"];
    NSMutableArray *banIDs = [[NSMutableArray alloc] init];
    [banIDs addObject:[NSString stringWithFormat:@"%ld", (long)[myWin windowNumber]]];
        
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    for (long i = CFArrayGetCount(windowList) - 1; i >= 0; i--) {
        CFDictionaryRef windowinfo = (CFDictionaryRef)(uintptr_t)CFArrayGetValueAtIndex(windowList, i);
        CFStringRef owner = CFDictionaryGetValue(windowinfo, (id)kCGWindowOwnerName);
        if ([blockWindows containsObject:[NSString stringWithFormat:@"%@", owner]])
            [banIDs addObject:[NSString stringWithFormat:@"%@", CFDictionaryGetValue(windowinfo, (id)kCGWindowNumber)]];
    }

    CFArrayRef onScreenWindows = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    CFMutableArrayRef finalList = CFArrayCreateMutableCopy(NULL, 0, onScreenWindows);
    for (long i = CFArrayGetCount(finalList) - 1; i >= 0; i--) {
        CGWindowID window = (CGWindowID)(uintptr_t)CFArrayGetValueAtIndex(finalList, i);
        if ([banIDs containsObject:[NSString stringWithFormat:@"%u", window]])
            CFArrayRemoveValueAtIndex(finalList, i);
    }

    CGImageRef screenShot = CGWindowListCreateImageFromArray(trueFrame, finalList, kCGWindowImageDefault);
    CFRelease(windowList);
    CFRelease(onScreenWindows);
    CFRelease(finalList);
    
    /* ... Do whatever you need to do ... */
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"executionTime = %f", executionTime);
    
//    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:screenShot];
//    NSData* data1 = [rep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
//    [data1 writeToFile:@"/Users/w0lf/Desktop/cleanHUD_png_test.png" atomically:YES];
    
//    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
//    CGImageRef screenShot = CGWindowListCreateImage(trueFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
    
//    /* Ugly hack to get around issue where some old frame gets into the screenshot */
//    NSRect aFrame = CGRectMake(mf.origin.x, y, w, 7);
//    CGImageRef aShot = CGWindowListCreateImage(aFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
//
//    NSRect bFrame = CGRectMake(mf.origin.x, y + 15, w, 7);
//    CGImageRef bShot = CGWindowListCreateImage(bFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
//
//    NSRect imageRect = NSMakeRect(0.0, 0.0, w, 14);
//
//    NSBitmapImageRep *savedImageBitmapRep = [[NSBitmapImageRep alloc]
//                                             initWithBitmapDataPlanes:nil
//                                             pixelsWide:imageRect.size.width
//                                             pixelsHigh:imageRect.size.height
//                                             bitsPerSample:8
//                                             samplesPerPixel:4
//                                             hasAlpha:YES
//                                             isPlanar:NO
//                                             colorSpaceName:NSCalibratedRGBColorSpace
//                                             bitmapFormat:0
//                                             bytesPerRow:(4 * imageRect.size.width)
//                                             bitsPerPixel:32];
//
//    [NSGraphicsContext saveGraphicsState];
//    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:savedImageBitmapRep]];
//    CGContextDrawImage(NSGraphicsContext.currentContext.CGContext, CGRectMake(0, 7, w, 7), aShot);
//    CGContextDrawImage(NSGraphicsContext.currentContext.CGContext, CGRectMake(0, 0, w, 7), bShot);
//    CGImageRef screenShot = CGBitmapContextCreateImage(NSGraphicsContext.currentContext.CGContext);
//    [NSGraphicsContext restoreGraphicsState];
    
//    NSString *path = @"/Users/w0lf/Desktop/cleanHUD_png_test.png";
//
//    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
//    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
//    if (!destination) {
//        NSLog(@"cleanHUD : Failed to create CGImageDestination for %@", path);
//    }
//
//    CGImageDestinationAddImage(destination, screenShot, nil);
//
//    if (!CGImageDestinationFinalize(destination)) {
//        NSLog(@"cleanHUD : Failed to write image to %@", path);
//    }
//
//    CFRelease(destination);

    return screenShot;
}

- (NSColor *)averageColor:(CGImageRef)test {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char rgba[4];
    CGContextRef context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), test);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    if(rgba[3] > 0) {
        CGFloat alpha = ((CGFloat)rgba[3])/255.0;
        CGFloat multiplier = alpha/255.0;
        return [NSColor colorWithRed:((CGFloat)rgba[0])*multiplier
                               green:((CGFloat)rgba[1])*multiplier
                                blue:((CGFloat)rgba[2])*multiplier
                               alpha:alpha];
    }
    else {
        return [NSColor colorWithRed:((CGFloat)rgba[0])/255.0
                               green:((CGFloat)rgba[1])/255.0
                                blue:((CGFloat)rgba[2])/255.0
                               alpha:((CGFloat)rgba[3])/255.0];
    }
}

@end
