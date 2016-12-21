//
//  cleanHUD.m
//  cleanHUD
//
//  Created by Wolfgang Baird on 8/15/16.
//  Copyright © 2016 Wolfgang Baird. All rights reserved.
//

// Imports & Includes
@import AppKit;
@import QuartzCore;
@import CoreAudio;
@import IOKit;

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

+ (cleanHUD*) sharedInstance
{
    static cleanHUD* plugin = nil;
    if (plugin == nil)
        plugin = [[cleanHUD alloc] init];
    return plugin;
}

+ (void)load
{
    osx_ver = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    
    plugin = [cleanHUD sharedInstance];
    [plugin initializeWindow];
    
    /* A basic swizzle */
    ZKSwizzle(wb_VolumeStateMachine, VolumeStateMachine);
    ZKSwizzle(wb_DisplayStateMachine, DisplayStateMachine);
    ZKSwizzle(wb_KeyboardStateMachine, KeyboardStateMachine);
    
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], (long)osx_ver);
}

- (void)initializeWindow
{
    // Use some system images for the volume indicator
    NSArray *volImgPaths = [NSArray arrayWithObjects:@"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume1.pdf",
                            @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume2.pdf",
                            @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume3.pdf",
                            @"/System/Library/CoreServices/Menu Extras/Volume.menu/Contents/Resources/Volume4.pdf",
                            nil];
    
    NSMutableArray *grabImages = [[NSMutableArray alloc] init];
    for (NSString *path in volImgPaths)
        [grabImages addObject:[self getIMG:path :false]];
    NSArray *blackVolumeImages = [[NSArray alloc] initWithArray:grabImages];
    
    [grabImages removeAllObjects];
    for (NSString *path in volImgPaths)
        [grabImages addObject:[self getIMG:path :true]];
    NSArray *whiteVolumeImages = [[NSArray alloc] initWithArray:grabImages];
    
    NSString *filePath = @"/tmp";
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] bundlePath];
    
    if ([bundlePath length]) filePath = [bundlePath stringByAppendingString:@"/Contents/Resources/display_icon.png"];
    NSImage *blackScreen = [self getIMG:filePath :false];
    
    if ([bundlePath length]) filePath = [bundlePath stringByAppendingString:@"/Contents/Resources/display_icon.png"];
    NSImage *whiteScreen  = [self getIMG:filePath :true];
    
    if ([bundlePath length]) filePath = [bundlePath stringByAppendingString:@"/Contents/Resources/keyboard_icon.png"];
    NSImage *blackKeyboard = [self getIMG:filePath :false];
    
    if ([bundlePath length]) filePath = [bundlePath stringByAppendingString:@"/Contents/Resources/keyboard_icon.png"];
    NSImage *whiteKeyboard = [self getIMG:filePath :true];
    
    NSArray *volumeIMG = [[NSArray alloc] initWithObjects:blackVolumeImages, whiteVolumeImages, nil];
    NSArray *screenIMG = [[NSArray alloc] initWithObjects:blackScreen, whiteScreen, nil];
    NSArray *keyboardIMG = [[NSArray alloc] initWithObjects:blackKeyboard, whiteKeyboard, nil];
    
    imageStorage = [[NSArray alloc] initWithObjects:volumeIMG, screenIMG, keyboardIMG, nil];
    
    animateHUD = 0;
    
    // Set up window to float above menubar
    myWin = [[my_NSWindow alloc] initWithContentRect:NSMakeRect([NSScreen mainScreen].frame.size.width / 2 - 117, [NSScreen mainScreen].frame.size.height - 22, 234, 22) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    [myWin makeKeyAndOrderFront:nil];
    [myWin setLevel:NSMainMenuWindowLevel + 2];
    [myWin setMovableByWindowBackground:YES];
    [myWin makeKeyAndOrderFront:nil];
    
    // Set up indicator to show volume percentage
    indi = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(30, 9, 200, 4)
                                         progressColor:[NSColor redColor]
                                            emptyColor:[NSColor lightGrayColor]
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

- (NSImage*)getIMG :(NSString*)imagePath :(BOOL)whiteColor
{
    NSImage *result = [[NSImage alloc] initWithContentsOfFile:imagePath];
    
    if (whiteColor)
    {
        CIImage* ciImage = [[CIImage alloc] initWithData:[result TIFFRepresentation]];
        CIFilter* filter = [CIFilter filterWithName:@"CIColorInvert"];
        [filter setDefaults];
        [filter setValue:ciImage forKey:@"inputImage"];
        CIImage *output = [filter valueForKey:@"outputImage"];
        NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:output];
        NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
        [nsImage addRepresentation:rep];
        result = nsImage;
    }
    
    return result;
}

- (void)showHUD :(int)hudType :(double)hudValue
{
    // Check for Dark mode
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSImage *displayImage;
    
    // Set progressbar
    [indi setDoubleValue:100];
    [indi setDoubleValue:hudValue];
    
    // Dark mode / Light mode
    if (osxMode == nil)
    {
        [myWin setBackgroundColor:[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25]];
        [indi setProgressColor:[NSColor whiteColor]];
    }
    else
    {
        [myWin setBackgroundColor:[NSColor colorWithWhite:1.0 alpha:0.75]];
        [indi setProgressColor:[NSColor blackColor]];
    }
    
    // Set icon
    int darkMode;
    if (osxMode == nil) darkMode = 1; else darkMode = 0;
    
    NSArray *imagesArray = [imageStorage objectAtIndex:hudType];
    if (hudType != 0)
    {
        displayImage = [imagesArray objectAtIndex:darkMode];
    }
    else
    {
        NSArray *imgList = [[NSArray alloc] initWithArray:[imagesArray objectAtIndex:darkMode]];
        if ([self getMuteState])
        {
            [indi setDoubleValue:0];
            displayImage = [imgList objectAtIndex:0];
        }
        else
            displayImage = [imgList objectAtIndex:ceil(hudValue / 33.34)];
    }
    
    [indi updateLayer];
    [vol setImage:displayImage];
    
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

@end

@implementation wb_VolumeStateMachine

- (void)displayOSD
{
    [plugin showHUD:0 :(double)[NSSound systemVolume] * 100];
}

@end

@interface wb_DisplayStateMachine : NSObject

- (void)displayOSD;

@end

@implementation wb_DisplayStateMachine

- (void)displayOSD
{
    [plugin showHUD:1 :(double)ZKHookIvar(self, float, "_brightness") * 100];
}

@end

@interface wb_KeyboardStateMachine : NSObject
{
    io_connect_t dataPort;
}

enum {
    kGetSensorReadingID   = 0,  // getSensorReading(int *, int *)
    kGetLEDBrightnessID   = 1,  // getLEDBrightness(int, int *)
    kSetLEDBrightnessID   = 2,  // setLEDBrightness(int, int, int *)
    kSetLEDFadeID         = 3,  // setLEDFade(int, int, int, int *)
    kverifyFirmwareID     = 4,  // verifyFirmware(int *)
    kGetFirmwareVersionID = 5,  // getFirmwareVersion(int *)
};

- (void)displayOSD;

@end

@implementation wb_KeyboardStateMachine

- (io_connect_t)getDataPort
{
    if (dataPort) return dataPort;
    
    io_service_t serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"));
    
    if (!serviceObject) return 0;
    
    kern_return_t kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &dataPort);
    IOObjectRelease(serviceObject);
    
    if (kr != KERN_SUCCESS) return 0;
    
    return dataPort;
}

- (float)getBrightness
{
    dataPort = [self getDataPort];
    
    if (!dataPort) return 0.0;
    
    uint32_t inputCount = 1;
    uint64_t inputValues[1] = { 0 };
    
    uint32_t outputCount = 1;
    uint64_t outputValues[1];
    
    kern_return_t kr = IOConnectCallScalarMethod(dataPort,
                                                 kGetLEDBrightnessID,
                                                 inputValues,
                                                 inputCount,
                                                 outputValues,
                                                 &outputCount);
    
    float brightness = -1.0;
    if (kr == KERN_SUCCESS) {
        brightness = (float)outputValues[0] / 0xfff;
    }
    
    return brightness;
}

- (void)displayOSD
{
    float bright = ceil([self getBrightness] * 100);
    if (bright >= 0)
        [plugin showHUD:2 :(double)bright];
    NSLog(@"%f", ceil([self getBrightness] * 100));
//    ZKOrig(void);
}

@end
