//
//  cleanHUD.m
//  cleanHUD
//
//  Created by Wolfgang Baird on 8/15/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

// Imports & Includes
@import AppKit;
@import CoreImage;
@import CoreAudio;

#include "ZKSwizzle.h"
#include "ISSoundAdditions.h"

// Interfaces

@interface cleanHUD : NSObject
@end

@interface my_NSWindow : NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen;
@end

// Variables

cleanHUD *plugin;
my_NSWindow *myWin;
int animateHUD;
NSInteger osx_ver;
NSProgressIndicator *indi;
NSImageView *vol;
NSArray *volImages;

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

+ (cleanHUD*) sharedInstance
{
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
    
    NSLog(@"OS X 10.%ld, %@ loaded...", (long)osx_ver, [self class]);
}

- (void)initializeWindow
{
    // Use some system images for the volume indicator
    volImages = [NSArray arrayWithObjects:@"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume1.pdf",
                  @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume2.pdf",
                  @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume3.pdf",
                  @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume4.pdf",
                  nil];
    
    animateHUD = 0;
    
    // Set up window to float above menubar
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect([NSScreen mainScreen].frame.size.width / 2 - 117, [NSScreen mainScreen].frame.size.height - 22, 234, 22) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setMovableByWindowBackground:YES];
    [myWin makeKeyAndOrderFront:nil];
    
    // Set up indicator to show volume percentage
    indi = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(30, 0, 200, 22)];
    [indi setMinValue:0.0];
    [indi setMaxValue:100.0];
    [indi setDoubleValue:0.0];
    [indi setHidden:NO];
    [indi setUsesThreadedAnimation:YES];
    [indi setStyle:NSProgressIndicatorBarStyle];
    [indi setIndeterminate:NO];
    
    // Set up imageview for showing volume indicator
    vol = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 0, 22, 22)];
    
    // Add subviews to window HUD
    [myWin.contentView addSubview:vol];
    [myWin.contentView addSubview:indi];
    
    // Hide HUD
    [myWin setAlphaValue:0.0];
}

- (void)showHUD
{
    // Check for Dark mode
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSImage *test;
    
    // Muting
    if ([self getMuteState])
    {
        // Muted so we want show 0 volume even though it's probably not actually 0
        [indi setDoubleValue:0];
        test = [[NSImage alloc] initWithContentsOfFile:[volImages objectAtIndex:0]];
    }
    else
    {
        // Not muted so show actual volume
        [indi setDoubleValue:(double)[NSSound systemVolume] * 100];
        test = [[NSImage alloc] initWithContentsOfFile:[volImages objectAtIndex:ceil((double)[NSSound systemVolume] * 100 / 33.34)]];
    }
    
    // Dark mode / Light mode
    if (osxMode == nil)
    {
        // Invert speaker image color
        CIImage* ciImage = [[CIImage alloc] initWithData:[test TIFFRepresentation]];
        CIFilter* filter = [CIFilter filterWithName:@"CIColorInvert"];
        [filter setDefaults];
        [filter setValue:ciImage forKey:@"inputImage"];
        CIImage *output = [filter valueForKey:@"outputImage"];
        //[output drawAtPoint:NSZeroPoint fromRect:NSRectFromCGRect([output extent]) operation:NSCompositeSourceOver fraction:1.0];
        [output drawAtPoint:NSZeroPoint fromRect:NSRectFromCGRect([output extent]) operation:NSCompositingOperationSourceOver fraction:1.0];
        NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:output];
        NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
        [nsImage addRepresentation:rep];
        test = nsImage;
        
        // Set background color
        [myWin setBackgroundColor:[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25]];
    }
    else
    {
        // Set background color
        [myWin setBackgroundColor:[NSColor colorWithWhite:1.0 alpha:0.75]];
    }
    [vol setImage:test];
    
    // Position the HUD in the middle of the menubar on the active screen
    int maxHeight = 0;
    for (NSScreen *scr in [NSScreen screens])
        if (scr.frame.size.height > maxHeight) maxHeight = scr.frame.size.height;
    [myWin setFrameOrigin:CGPointMake([NSScreen mainScreen].frame.size.width / 2 - 117 + [NSScreen mainScreen].frame.origin.x, maxHeight - 22)];

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

- (void)hideHUD
{
    if (animateHUD == 1)
    {
        // Fade out the HUD
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 1;
            myWin.animator.alphaValue = 0;
        }
        completionHandler:^{
//            myWin.animator.alphaValue = 1;
        }];
    }
    
    if (animateHUD > 0)
        animateHUD--;
}

- (BOOL)getMuteState
{
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

//    NSLog(@"Muted: %u", (unsigned int)isMuted);
    return (BOOL)isMuted;
}

@end

@interface wb_VolumeStateMachine : NSObject

- (void)displayOSD;
- (void)toggleMute;

@end

@implementation wb_VolumeStateMachine

- (void)displayOSD
{
    [plugin showHUD];
//    NSLog(@"Don't display system OSD, lets draw our own...");
//    ZKOrig(void);
}

- (void)toggleMute
{
    // THought I might use this but accessing _muted from VolumeStateMachine was causing a crash so meh...
    ZKOrig(void);
}

@end

