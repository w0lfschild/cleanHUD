//
//  cleanHUD.m
//  cleanHUD
//
//  Created by Wolfgang Baird on 8/15/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

// Imports & Includes
@import AppKit;
@import CoreAudio;

#include "ZKSwizzle.h"
#include "ISSoundAdditions.h"
#include "AYProgressIndicator.h"
#include <IOKit/graphics/IOGraphicsLib.h>

// Interfaces

@interface cleanHUD : NSObject
@end

@interface my_NSWindow : NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen;
@end

// Variables

cleanHUD *plugin;
my_NSWindow *myWin;
NSView *myView;
AYProgressIndicator *indi;
NSView *indiBackground;
NSVisualEffectView *indiBlur;
int isControlStripDrawing;
int animateHUD;
float mybrightness;
NSInteger osx_ver;
NSImageView *vol;
NSArray *imageStorage;

// Implementations

@implementation my_NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen {
    return frameRect;
}
@end

@implementation cleanHUD

const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

+ (cleanHUD*) sharedInstance {
    static cleanHUD* plugin = nil;
    if (plugin == nil)
        plugin = [[cleanHUD alloc] init];
    return plugin;
}

+ (void)load {
    osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
    plugin = [cleanHUD sharedInstance];
    
    [plugin initializeWindow];
    
//    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.OSDUIHelper"]) {
//    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.systemuiserver"]) {
//    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.coreservices.uiagent"]) {
//    [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.notificationcenterui"]
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.notificationcenterui"]) {
        [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"com.w0lf.cleanHUDUpdate"
                                                                     object:nil
                                                                      queue:nil
                                                                 usingBlock:^(NSNotification *notification) {
                                                                     if (isControlStripDrawing == 0) {
                                                                         NSArray *chunks = [notification.object componentsSeparatedByString: @":"];
                                                                         int type = [chunks[0] intValue];
                                                                         float num = [chunks[1] floatValue];
                                                                         [[cleanHUD sharedInstance] showHUD:type :num];
                                                                     }
        }];
    }
    
    // NSLog(@"wb_ test0 : %@", NSClassFromString(@"KeyboardALSAlgorithm"));
    // NSLog(@"wb_ test1 : %@", NSClassFromString(@"KeyboardALSAlgorithmHID"));
    // NSLog(@"wb_ test2 : %@", NSClassFromString(@"KeyboardALSAlgorithmLegacy"));
    
    /* Swizzle */
//    ZKSwizzle(wb_VolumeStateMachine, VolumeStateMachine);
//    ZKSwizzle(wb_DisplayStateMachine, DisplayStateMachine);
//    ZKSwizzle(wb_KeyboardStateMachine, KeyboardStateMachine);
//
//    if (NSClassFromString(@"KeyboardALSAlgorithmHID")) {
//        ZKSwizzle(wb_KeyboardALSAlgorithmHID, KeyboardALSAlgorithmHID);
//        ZKSwizzle(wb_KeyboardALSAlgorithmLegacy, KeyboardALSAlgorithmLegacy);
//    } else {
//        ZKSwizzle(wb_KeyboardALSAlgorithm, KeyboardALSAlgorithm);
//    }
//
    
    ZKSwizzle(wb_ControlStripVolumeButton, ControlStrip.VolumeButton);
    ZKSwizzle(wb_ControlStripBrightnessButton, ControlStrip.BrightnessButton);
    
    ZKSwizzle(wb_OSDRoundWindow, OSDUIHelper.OSDRoundWindow);
    ZKSwizzle(wb_OSDUIHelperOSDUIHelper, OSDUIHelper.OSDUIHelper);

    NSLog(@"macOS %@, %@ loaded %@...", [[NSProcessInfo processInfo] operatingSystemVersionString], [[NSProcessInfo processInfo] processName], [self class]);
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
    isControlStripDrawing = 0;
    
    // Set up window to float above menubar
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect(scr.origin.x + (scr.size.width / 2) - 117, scr.origin.y + scr.size.height, 234, 22)
                                           styleMask:0
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
//    [myWin setLevel:NSMainMenuWindowLevel + 99999];
    [myWin setMovableByWindowBackground:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setIgnoresMouseEvents:YES];
    [myWin setOpaque:false];
    [myWin setBackgroundColor:[NSColor clearColor]];
    
    // Set up indicator to show volume percentage
    NSRect indiFrame = NSMakeRect(30, 8, 200, 4);
    if (osx_ver > 13) indiFrame = NSMakeRect(28, 9, 204, 4);
    indi = [[AYProgressIndicator alloc] initWithFrame:indiFrame
                                        progressColor:[NSColor whiteColor]
                                           emptyColor:[NSColor clearColor]
                                             minValue:0
                                             maxValue:100
                                         currentValue:0];
    [indi setHidden:NO];
    [indi setWantsLayer:YES];
    [indi.layer setCornerRadius:2];
    
    // Set up indicator border
    indiBackground = [[NSView alloc] init];
    [indiBackground setFrame:NSMakeRect(28, 8, 204, 6)];
    [indiBackground setHidden:NO];
    [indiBackground setWantsLayer:YES];
    [indiBackground.layer setCornerRadius:3];
    [indiBackground.layer setBackgroundColor:[NSColor clearColor].CGColor];
    [indiBackground.layer setBorderColor:[NSColor whiteColor].CGColor];
    [indiBackground.layer setBorderWidth:1];
    
    // Set up indicator background blur
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
    [myWin.contentView addSubview:vol];
    [myWin.contentView addSubview:indiBackground];
    [myWin.contentView addSubview:indi];
    
    // Round conrners
    [myWin.contentView.layer setCornerRadius:4];
    
    // Hide HUD
    [myWin setAlphaValue:0.0];
    
    // Init myView
    myView = [[NSView alloc] initWithFrame:myWin.frame];
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
        if (osx_ver > 10)
            [indiBlur setMaterial:NSVisualEffectMaterialSelection];
        else
            [indiBlur setMaterial:NSVisualEffectMaterialLight];
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
    
    // Menubar hidden check
     if ([NSApp presentationOptions] == NSApplicationPresentationAutoHideMenuBar ||
         [NSApp presentationOptions] == NSApplicationPresentationHideMenuBar) {
         if (NSEvent.mouseLocation.y < scr.size.height - 22)
             yPos -= 22;
     }
    
    // Adjust for fullscreen
    if (yPos == scr.size.height || yPos == scr.size.height + scr.origin.y)
        yPos -= 22;
    
    // Set origin
    CGPoint frmLoc = CGPointMake(xPos, yPos);
    [myWin setFrameOrigin:frmLoc];
    
    // Set window level to be above everything
//    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setLevel:NSMainMenuWindowLevel + 999];
    [myWin setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    
    // Hide the window in 1 second
    animateHUD ++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self hideHUD];
    });
    
    // Cancel any existing animation and show the window
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [[myWin animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}

- (void)hideHUD {
    if (animateHUD <= 1) {
        // Fade out the HUD
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 1;
            myWin.animator.alphaValue = 0;
        }
        completionHandler:^{ }];
    }
    if (animateHUD > 0)
        animateHUD--;
    if (isControlStripDrawing > 0)
        isControlStripDrawing--;
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

- (float)get_brightness
{
    float brightness = 1.0f;
    io_iterator_t iterator;
    kern_return_t result =
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 IOServiceMatching("IODisplayConnect"),
                                 &iterator);
    
    // If we were successful
    if (result == kIOReturnSuccess) {
        io_object_t service;
        
        while ((service = IOIteratorNext(iterator))) {
            IODisplayGetFloatParameter(service,
                                       kNilOptions,
                                       CFSTR(kIODisplayBrightnessKey),
                                       &brightness);
            
            // Let the object go
            IOObjectRelease(service);
        }
    }
    
    return brightness;
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
    
//    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
//    CGImageRef screenShot = CGWindowListCreateImage(trueFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
    
    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
    NSArray *blockedWindows = @[@"OSDUIHelper", @"Control Strip", @"loginwindow"];
    NSMutableArray *blockedIDs = [[NSMutableArray alloc] init];
    [blockedIDs addObject:[NSString stringWithFormat:@"%ld", (long)[myWin windowNumber]]];
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    for (long i = CFArrayGetCount(windowList) - 1; i >= 0; i--) {
        CFDictionaryRef windowinfo = (CFDictionaryRef)(uintptr_t)CFArrayGetValueAtIndex(windowList, i);
        CFStringRef owner = CFDictionaryGetValue(windowinfo, (id)kCGWindowOwnerName);
        if ([blockedWindows containsObject:[NSString stringWithFormat:@"%@", owner]])
            [blockedIDs addObject:[NSString stringWithFormat:@"%@", CFDictionaryGetValue(windowinfo, (id)kCGWindowNumber)]];
    }
    
    CFArrayRef onScreenWindows = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    CFMutableArrayRef finalList = CFArrayCreateMutableCopy(NULL, 0, onScreenWindows);
    for (long i = CFArrayGetCount(finalList) - 1; i >= 0; i--) {
        CGWindowID window = (CGWindowID)(uintptr_t)CFArrayGetValueAtIndex(finalList, i);
        if ([blockedIDs containsObject:[NSString stringWithFormat:@"%u", window]])
            CFArrayRemoveValueAtIndex(finalList, i);
    }
    
    CGImageRef screenShot = CGWindowListCreateImageFromArray(trueFrame, finalList, kCGWindowImageDefault);
    CFRelease(windowList);
    CFRelease(onScreenWindows);
    CFRelease(finalList);
    
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

/* wb_VolumeStateMachine */

@interface wb_VolumeStateMachine : NSObject

- (void)displayOSD;

@end

@implementation wb_VolumeStateMachine

- (void)displayOSD {
    [plugin showHUD:0 :[NSSound systemVolume] * 100];
}

@end

/* wb_DisplayStateMachine */

@interface wb_DisplayStateMachine : NSObject

- (void)displayOSD;

@end

@implementation wb_DisplayStateMachine

- (void)displayOSD {
    [plugin showHUD:1 :ZKHookIvar(self, float, "_brightness") * 100];
}

@end

/* wb_KeyboardStateMachine */

@interface wb_KeyboardStateMachine : NSObject

- (void)displayOSD;

@end

@implementation wb_KeyboardStateMachine

- (void)displayOSD {
    // NSLog(@"wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
    [plugin showHUD:2 :mybrightness * 100];
}

@end

/* wb_KeyboardALSAlgorithm */

@interface wb_KeyboardALSAlgorithm : NSObject

- (void)prefChanged:(id)arg1;

@end

@implementation wb_KeyboardALSAlgorithm

- (void)prefChanged:(id)arg1 {
    // NSLog(@"wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
    ZKOrig(void, arg1);
    mybrightness = ZKHookIvar(self, float, "_brightness");
}

@end

/* wb_KeyboardALSAlgorithmHID */

@interface wb_KeyboardALSAlgorithmHID : NSObject
{
    NSArray *possibleFloats;
}

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2;

@end

@implementation wb_KeyboardALSAlgorithmHID

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2 {
    /* Hard coded work around unless I can figure out some algorithm this follows */

//    possibleFloats = @[@"0.000000",@"0.062500",@"0.073194",@"0.085717",@"0.100383",@"0.117559",@"0.137673",@"0.161228",@"0.188814",
//                       @"0.221119",@"0.258952",@"0.303259",@"0.355145",@"0.415910",@"0.487071",@"0.570408",@"0.668003"];
    
//    BOOL hasSet = false;
//    float bright = ZKHookIvar(self, float, "_brightness");
//    NSString* numberA = [NSString stringWithFormat:@"%.6f", bright];
//    for (int i = 0; i < possibleFloats.count; i++) {
//        NSString* numberB = possibleFloats[i];
//        if ([numberA isEqualToString:numberB]) {
//            mybrightness = (float)((i * 6.25) / 100.0);
//            hasSet = true;
//            break;
//        }
//    }
//
//    if (!hasSet)
//        mybrightness = arg1 / .668;
    
    // NSLog(@"wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
    mybrightness = arg1 / 0.668;
    ZKOrig(void, arg1, arg2);
}

@end

/* wb_KeyboardALSAlgorithmLegacy */

@interface wb_KeyboardALSAlgorithmLegacy : NSObject

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2;

@end

@implementation wb_KeyboardALSAlgorithmLegacy

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2 {
    // NSLog(@"wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
    mybrightness = arg1;
    ZKOrig(void, arg1, arg2);
}

@end

/* wb_ControlStrip.BrightnessButton */

@interface wb_ControlStripBrightnessButton : NSObject

- (void)brightnessDidChange:(id)arg1;

@end

@implementation wb_ControlStripBrightnessButton

- (void)brightnessDidChange:(id)arg1 {
    isControlStripDrawing++;
    float screenBright = [plugin get_brightness] * 100;
    if (screenBright > 96.00)
        screenBright = 100.00;
    [plugin showHUD:1 :screenBright];
    ZKOrig(void, arg1);
}

@end

/* wb_ControlStrip.VolumeButton */

@interface wb_ControlStripVolumeButton : NSObject

- (void)audioDidChange:(id)arg1;

@end

@implementation wb_ControlStripVolumeButton

- (void)audioDidChange:(id)arg1 {
    isControlStripDrawing++;
    [plugin showHUD:0 :[NSSound systemVolume] * 100];
    ZKOrig(void, arg1);
}

@end

/* wb_OSDUIHelper.OSDRoundWindow */

@interface wb_OSDRoundWindow : NSWindow
- (void)hackWindow:(int)hudType :(float)hudValue;
@end

@implementation wb_OSDRoundWindow

- (void)hackWindow:(int)hudType :(float)hudValue {
    // Set our location
    [self setFrame:myWin.frame display:true];

    // Update progress indicator value
    [indi setDoubleValue:100];
    [indi setDoubleValue:hudValue];

    // Check for Dark mode
    int darkMode = 0;
    NSImageView *dankness = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 0, 22, 22)];;
    NSImage *displayImage = [NSImage new];
    Boolean useDark = [plugin useDarkColors];
    darkMode = useDark;

    // Dark mode / Light mode
    if (useDark) {
        [indi setProgressColor:[NSColor whiteColor]];
        [indiBackground.layer setBorderColor:[NSColor whiteColor].CGColor];
        [indiBlur setMaterial:NSVisualEffectMaterialDark];
    } else {
        [indi setProgressColor:[NSColor blackColor]];
        [indiBackground.layer setBorderColor:[NSColor blackColor].CGColor];
        if (osx_ver > 10)
            [indiBlur setMaterial:NSVisualEffectMaterialSelection];
        else
            [indiBlur setMaterial:NSVisualEffectMaterialLight];
    }

    // Set icon
    NSArray *imagesArray = [imageStorage objectAtIndex:hudType];
    if (hudType != 0) {
        displayImage = [imagesArray objectAtIndex:darkMode];
    } else {
        imagesArray = [imagesArray objectAtIndex:darkMode];
        if (hudValue == 0) {
            displayImage = [imagesArray objectAtIndex:0];
        } else {
            displayImage = [imagesArray objectAtIndex:ceil(hudValue / 33.34)];
        }
    }

    // Update layers
    [indi updateLayer];
    [dankness setImage:displayImage];

    // Round conrners
    [self.contentView.layer setCornerRadius:4];
    
    // Set up indicator to show volume percentage
    NSView *aView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 234, 22)];

    // Add subviews to window HUD
    [aView setSubviews:@[indiBlur, dankness, indiBackground, indi]];
    [self setContentView:aView];
    [aView setNeedsDisplay:true];
    
    // Position the HUD in the middle of the menubar on the active screen
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    float xPos = scr.origin.x + (scr.size.width / 2) - 117;
    float yPos = scr.origin.y + scr.size.height;
    
    // Adjust for fullscreen
    if (yPos == [NSScreen mainScreen].frame.size.height || yPos == [NSScreen mainScreen].frame.size.height + [NSScreen mainScreen].frame.origin.y)
        yPos -= 22;
    
    // Set origin
    CGPoint frmLoc = CGPointMake(xPos, yPos);
    [self setFrameOrigin:frmLoc];
}

@end

/* wb_OSDUIHelper.OSDUIHelper */

@interface wb_OSDUIHelperOSDUIHelper : NSObject
{
}

//- (id)init;
- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 filledChiclets:(unsigned int)arg5 totalChiclets:(unsigned int)arg6 locked:(BOOL)arg7;
//- (void)showImageAtPath:(id)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(id)arg5;
//- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 withText:(id)arg5;
//- (void)showFullScreenImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecToAnimate:(unsigned int)arg4;
//- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4;
//- (void)fadeClassicImageOnDisplay:(unsigned int)arg1;

@end

@implementation wb_OSDUIHelperOSDUIHelper

- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 filledChiclets:(unsigned int)arg5 totalChiclets:(unsigned int)arg6 locked:(BOOL)arg7 {
//    NSLog(@"Testing : wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
    
    // If we're drawing our own window do nothing
    if (myWin.alphaValue == 0) {
        // Brightness 1
        // Birghtness slider 7
        
        // Keyboard 25
        // Keyboard 26
        // Keyboard 27
        
        // Volume 23
        // Mute 4 / Unmute 5
        // Volume slider 3
        
        // HUDS
        // 0 - Volume
        // 1 - Screen Brightness
        // 2 - Keyboard Brightness
        
        int HUDType = 0;
        float a = arg5;
        float b = arg6;
        float percentageFull = (a / b) * 100.0;
        
        if (arg1 == 1 || arg1 == 7) {
            HUDType = 1;
        }
        
        if (arg1 == 25 || arg1 == 26 || arg1 == 27) {
            HUDType = 2;
        }
        
//        ZKOrig(void, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.w0lf.cleanHUDUpdate" object:[NSString stringWithFormat:@"%d:%f", HUDType, percentageFull] userInfo:nil deliverImmediately:true];
//        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.w0lf.cleanHUDUpdate" object:[NSString stringWithFormat:@"%d:%f", HUDType, percentageFull]];
//        wb_OSDRoundWindow *p = (wb_OSDRoundWindow*)[NSApp windows].firstObject;
//        NSLog(@"xyz %@", NSApp.windows);
//        [p hackWindow:HUDType :percentageFull];
    }
}

@end
