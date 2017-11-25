//
//  cleanHUD.m
//  cleanHUD
//
//  Created by Wolfgang Baird on 8/15/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

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
AYProgressIndicator *indi;
NSView *indiBackground;
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

/*
 
 Options to add:
 
 - hide delay
 - fade speed
 - custom colors
 - no HUD at all
 
 */

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
    
    // NSLog(@"wb_ test0 : %@", NSClassFromString(@"KeyboardALSAlgorithm"));
    // NSLog(@"wb_ test1 : %@", NSClassFromString(@"KeyboardALSAlgorithmHID"));
    // NSLog(@"wb_ test2 : %@", NSClassFromString(@"KeyboardALSAlgorithmLegacy"));
    
    /* Swizzle */
    ZKSwizzle(wb_VolumeStateMachine, VolumeStateMachine);
    ZKSwizzle(wb_DisplayStateMachine, DisplayStateMachine);
    ZKSwizzle(wb_KeyboardStateMachine, KeyboardStateMachine);
    
    if (NSClassFromString(@"KeyboardALSAlgorithmHID")) {
        ZKSwizzle(wb_KeyboardALSAlgorithmHID, KeyboardALSAlgorithmHID);
        ZKSwizzle(wb_KeyboardALSAlgorithmLegacy, KeyboardALSAlgorithmLegacy);
    } else {
        ZKSwizzle(wb_KeyboardALSAlgorithm, KeyboardALSAlgorithm);
    }
    
    ZKSwizzle(wb_ControlStripVolumeButton, ControlStrip.VolumeButton);
    ZKSwizzle(wb_ControlStripBrightnessButton, ControlStrip.BrightnessButton);
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
    
    // Set up window to float above menubar
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect(scr.origin.x + (scr.size.width / 2) - 117, scr.origin.y + scr.size.height, 234, 22)
                                           styleMask:0
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setMovableByWindowBackground:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setIgnoresMouseEvents:YES];
    [myWin setOpaque:false];
    
    // Set up indicator to show volume percentage
    indi = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(30, 9, 200, 4)
                                        progressColor:[NSColor whiteColor]
                                           emptyColor:[NSColor grayColor]
                                             minValue:0
                                             maxValue:100
                                         currentValue:0];
    [indi setHidden:NO];
    [indi setWantsLayer:YES];
    [indi.layer setCornerRadius:2];
    
    indiBackground = [[NSView alloc] init];
    [indiBackground setFrame:NSMakeRect(30, 8, 200, 6)];
    [indiBackground setHidden:NO];
    [indiBackground setWantsLayer:YES];
    [indiBackground.layer setCornerRadius:3];
    [indiBackground.layer setBackgroundColor:[NSColor clearColor].CGColor];
    [indiBackground.layer setBorderWidth:1];
    
    // Set up imageview for showing volume indicator
    vol = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 0, 22, 22)];
    
    // Add subviews to window HUD
    [myWin.contentView addSubview:vol];
    [myWin.contentView addSubview:indiBackground];
    [myWin.contentView addSubview:indi];
    
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
    
    Boolean useDark = [self useDarkColors];
    darkMode = useDark;
    
//    NSLog(@"cleanHUD: Darkmode : %d", darkMode);
    
    // Dark mode / Light mode
    if (useDark) {
        [myWin setBackgroundColor:[NSColor clearColor]];
        [indi setProgressColor:[NSColor whiteColor]];
        [indi setEmptyColor:[NSColor colorWithWhite:0.0 alpha:1.0]];
        [indiBackground.layer setBorderColor:[NSColor whiteColor].CGColor];
    } else {
        [myWin setBackgroundColor:[NSColor clearColor]];
        [indi setProgressColor:[NSColor blackColor]];
        [indi setEmptyColor:[NSColor colorWithWhite:1.0 alpha:1.0]];
        [indiBackground.layer setBorderColor:[NSColor blackColor].CGColor];
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
    float yPos = scr.origin.y + scr.size.height;
    
    // Adjust for fullscreen
    if (yPos == [NSScreen mainScreen].frame.size.height || yPos == [NSScreen mainScreen].frame.size.height + [NSScreen mainScreen].frame.origin.y)
        yPos -= 22;
    
    // Set origin
    CGPoint frmLoc = CGPointMake(xPos, yPos);
    [myWin setFrameOrigin:frmLoc];
    
    // Set window level to be above everything
    [myWin setLevel:NSMainMenuWindowLevel + 2];
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
    if (animateHUD == 1) {
        // Fade out the HUD
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 1;
            myWin.animator.alphaValue = 0;
        }
        completionHandler:^{ }];
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

- (float)get_brightness
{
    float brightness = 1.0f;
    io_iterator_t iterator;
    kern_return_t result =
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 IOServiceMatching("IODisplayConnect"),
                                 &iterator);
    
    // If we were successful
    if (result == kIOReturnSuccess)
    {
        io_object_t service;
        
        while ((service = IOIteratorNext(iterator)))
        {
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
    NSColor *backGround = [self averageColor:[self contextColors]];
    double a = 1 - ( 0.299 * backGround.redComponent * 255 + 0.587 * backGround.greenComponent * 255 + 0.114 * backGround.blueComponent * 255)/255;
    if (a < 0.5)
        result = false; // bright colors - black font
    else
        result = true; // dark colors - white font
    return result;
}

- (CGImageRef)contextColors {
//    NSDate *methodStart = [NSDate date];
    
    CGWindowID windowID = (CGWindowID)[myWin windowNumber];
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
    
    NSRect trueFrame = CGRectMake(mf.origin.x, y, w, h);
    CGImageRef screenShot = CGWindowListCreateImage(trueFrame, kCGWindowListOptionOnScreenBelowWindow, windowID, kCGWindowImageDefault);
//    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:screenShot];
//    NSImage *image = [[NSImage alloc] init];
//    [image addRepresentation:bitmapRep];
//    bitmapRep = nil;
    
//    NSLog(@"cleanHUD: Screenshot : %zu, %zu", CGImageGetWidth(screenShot), CGImageGetHeight(screenShot));
//    NSLog(@"cleanHUD: My Frame : %@", NSStringFromRect(mf));
//    NSLog(@"cleanHUD: Screen Frame : %@", NSStringFromRect(sf));
//    NSLog(@"cleanHUD: True Frame : %@", NSStringFromRect(trueFrame));
    
//    NSDate *methodFinish = [NSDate date];
//    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
//    NSLog(@"cleanHUD: executionTime = %f", executionTime);
    
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
    [plugin showHUD:0 :[NSSound systemVolume] * 100];
    ZKOrig(void, arg1);
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
//    // NSLog(@"wb_ %@ : %@", self.className, NSStringFromSelector(_cmd));
//  Do Nothing
}

@end
