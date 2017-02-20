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
    
    /* A basic swizzle */
    ZKSwizzle(wb_VolumeStateMachine, VolumeStateMachine);
    ZKSwizzle(wb_DisplayStateMachine, DisplayStateMachine);
    ZKSwizzle(wb_KeyboardStateMachine, KeyboardStateMachine);
        
    if (NSClassFromString(@"KeyboardALSAlgorithmHID")) {
        ZKSwizzle(wb_KeyboardALSAlgorithmHID, KeyboardALSAlgorithmHID);
        ZKSwizzle(wb_KeyboardALSAlgorithmLegacy, KeyboardALSAlgorithmLegacy);
    } else {
        ZKSwizzle(wb_KeyboardALSAlgorithm, KeyboardALSAlgorithm);
    }
    
    NSLog(@"OS X 10.%ld, %@ loaded...", (long)osx_ver, [self class]);
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
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect([NSScreen mainScreen].frame.size.width / 2 - 117, [NSScreen mainScreen].frame.size.height - 22, 234, 22) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setMovableByWindowBackground:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setIgnoresMouseEvents:YES];
    
    // Set up indicator to show volume percentage
    indi = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(30, 9, 200, 4)
                                        progressColor:[NSColor whiteColor]
                                           emptyColor:[NSColor blackColor]
                                             minValue:0
                                             maxValue:100
                                         currentValue:0];
    [indi setHidden:NO];
    [indi setWantsLayer:YES];
    [indi.layer setCornerRadius:2];
    
    // Set up imageview for showing volume indicator
    vol = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 0, 22, 22)];
    
    // Add subviews to window HUD
    [myWin.contentView addSubview:vol];
    [myWin.contentView addSubview:indi];
    
    // Hide HUD
    [myWin setAlphaValue:0.0];
}

- (void)showHUD :(int)hudType :(float)hudValue {
    // Check for Dark mode
    int darkMode;
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    if (osxMode == nil) darkMode = 1; else darkMode = 0;
    NSImage *displayImage = [NSImage new];
    
    // Set progressbar
    [indi setDoubleValue:100];
    [indi setDoubleValue:hudValue];
    
    // Dark mode / Light mode
    if (darkMode == 1) {
        [myWin setBackgroundColor:[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25]];
        [indi setProgressColor:[NSColor whiteColor]];
    } else {
        [myWin setBackgroundColor:[NSColor colorWithWhite:1.0 alpha:0.75]];
        [indi setProgressColor:[NSColor blackColor]];
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
    int maxHeight = 0;
    for (NSScreen *scr in [NSScreen screens])
        if (scr.frame.size.height > maxHeight) maxHeight = scr.frame.size.height;
    [myWin setFrameOrigin:CGPointMake([NSScreen mainScreen].frame.size.width / 2 - 117 + [NSScreen mainScreen].frame.origin.x, maxHeight - 22)];
    
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
    [plugin showHUD:2 :mybrightness * 100];
}

@end

/* wb_KeyboardALSAlgorithm */

@interface wb_KeyboardALSAlgorithm : NSObject

- (void)prefChanged:(id)arg1;

@end

@implementation wb_KeyboardALSAlgorithm

- (void)prefChanged:(id)arg1 {
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
    if (possibleFloats == nil)
        possibleFloats = @[@"0.000000",@"0.062500",@"0.073194",@"0.085717",@"0.100383",@"0.117559",@"0.137673",@"0.161228",@"0.188814",
                           @"0.221119",@"0.258952",@"0.303259",@"0.355145",@"0.415910",@"0.487071",@"0.570408",@"0.668003"];
    
    BOOL hasSet = false;
    float bright = ZKHookIvar(self, float, "_brightness");
    NSString* numberA = [NSString stringWithFormat:@"%.6f", bright];
    for (int i = 0; i < possibleFloats.count; i++) {
        NSString* numberB = possibleFloats[i];
        if ([numberA isEqualToString:numberB]) {
            mybrightness = (float)((i * 6.25) / 100.0);
            hasSet = true;
            break;
        }
    }

    if (!hasSet)
        mybrightness = arg1 / .668;

    ZKOrig(void, arg1, arg2);
}

@end

/* wb_KeyboardALSAlgorithmLegacy */

@interface wb_KeyboardALSAlgorithmLegacy : NSObject

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2;

@end

@implementation wb_KeyboardALSAlgorithmLegacy

- (void)setHardwareBrightness:(float)arg1 UsingFadeSpeed:(int)arg2 {
    mybrightness = arg1;
    ZKOrig(void, arg1, arg2);
}

@end
