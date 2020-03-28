//
//  cleanHUD.m
//  cleanHUD
//
//  Created by Wolfgang Baird on 8/15/16.
//  Copyright © 2016 - 2020 Wolfgang Baird. All rights reserved.
//

// Imports & Includes
@import AppKit;
@import CoreAudio;
#include "ZKSwizzle.h"
#include "AYProgressIndicator.h"

// Interfaces
@interface cleanHUD : NSObject
@end

@interface mech_NSWindow : NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen;
@end

// Variables
mech_NSWindow *w;
cleanHUD *plugin;
AYProgressIndicator *indi;
NSVisualEffectView *indiBlur;
NSImageView *vol;
NSArray *imageStorage;
static CGFloat windowHeight = 30;
static CGFloat windowWidth = 300;
static int animateHUD = 0;
float mybrightness;
NSInteger osx_ver;

// Customization
Boolean macOSStyle;
Boolean useCustomColor;
NSColor *iconColor;
NSColor *sliderColor;


// Implementations
@implementation mech_NSWindow
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen {
    return frameRect;
}
@end

@implementation NSImage (PresidentialTint)

- (NSImage *)imageTintedWithColor:(NSColor *)tint {
    NSImage *image = [self copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositeSourceIn);
        [image unlockFocus];
    }
    return image;
}

@end

@implementation NSUserDefaults (BoolMate)

- (Boolean)boolForKey:(NSString *)aKey {
    Boolean theBool = false;
    NSObject *theData = [self valueForKey:aKey];
    if (theData != nil)
        theBool = [[self valueForKey:aKey] boolValue];
    return theBool;
}
 
@end


@implementation cleanHUD

+ (cleanHUD*) sharedInstance {
    static cleanHUD* plugin = nil;
    if (plugin == nil)
        plugin = [[cleanHUD alloc] init];
    return plugin;
}

+ (void)load {
    osx_ver = NSProcessInfo.processInfo.operatingSystemVersion.minorVersion;
    plugin = [cleanHUD sharedInstance];
    iconColor = NSColor.whiteColor;
    
    // Option to show in iOS style
    [plugin readPreferences];

    // Initialize images
    [plugin setupIconImages];
    
    // Setup our window
    [plugin initializeWindow];
    [plugin adjustWindow];
    
    // Log
    NSLog(@"macOS %@, %@ loaded %@...", NSProcessInfo.processInfo.operatingSystemVersionString, NSProcessInfo.processInfo.processName, [self class]);
}

- (NSColor*)colorWithHexColorString:(NSString*)inColorString {
    NSColor* result = nil;
    unsigned colorCode = 0;
    unsigned char redByte, greenByte, blueByte;

    if (nil != inColorString) {
         NSScanner* scanner = [NSScanner scannerWithString:inColorString];
         (void) [scanner scanHexInt:&colorCode]; // ignore error
    }
    redByte = (unsigned char)(colorCode >> 16);
    greenByte = (unsigned char)(colorCode >> 8);
    blueByte = (unsigned char)(colorCode); // masks off high bits

    result = [NSColor
    colorWithCalibratedRed:(CGFloat)redByte / 0xff
    green:(CGFloat)greenByte / 0xff
    blue:(CGFloat)blueByte / 0xff
    alpha:1.0];
    return result;
}

- (void)readPreferences {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    
    // macOSStyle
    macOSStyle = [d boolForKey:@"macOSStyle"];
    
    // Custom colors
    useCustomColor = [d boolForKey:@"useCustomColor"];
    NSString *ico = [d stringForKey:@"iconColor"];
    if (ico != nil) {
        NSColor *hexColor = [plugin colorWithHexColorString:ico];
        if (![iconColor isEqualTo:hexColor]) {
            iconColor = hexColor;
            [plugin setupIconImages];
        }
    }
    NSString *sld = [d stringForKey:@"sliderColor"];
    if (sld != nil) sliderColor = [plugin colorWithHexColorString:sld];
}

- (void)setupIconImages {
    // Use some system images for the volume indicator
    NSMutableArray *blackVolumeImages = [NSMutableArray new];
    NSMutableArray *whiteVolumeImages = [NSMutableArray new];
    
    NSMutableDictionary *store = @{@"mute" : [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Mute" ofType:@"pdf"]],
                                @"volume" : [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Volume" ofType:@"pdf"]],
                                @"kon" : [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"kBright" ofType:@"pdf"]],
                                @"koff" : [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"kBrightOff" ofType:@"pdf"]],
                                @"screen" : [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Brightness" ofType:@"pdf"]],
    }.mutableCopy;
    
    // Crop off some extra blank space at the bottom of the images
    for (NSString *key in store.allKeys) {
        NSImage *image = [store valueForKey:key];
        CGFloat imgWidth = image.size.width;
        CGFloat imgheight = image.size.height * 0.86;
        CGRect leftImgFrame = CGRectMake(0, 0, imgWidth, imgheight);
        CGImageSourceRef source;
        source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
        CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CGImageRef left = CGImageCreateWithImageInRect(maskRef, leftImgFrame);
        NSImage *leftImage = [NSImage.alloc initWithCGImage:left size:CGSizeMake(imgWidth, imgheight)];
        CGImageRelease(left);
        [store setValue:leftImage forKey:key];
    }
    
    // Mute
    [blackVolumeImages addObject:[store valueForKey:@"mute"]];
    [whiteVolumeImages addObject:[[store valueForKey:@"mute"] imageTintedWithColor:iconColor]];
    
    // Slice up the volume indicator for 1x and 2x volume
    NSImage *image = [store valueForKey:@"volume"];
    NSArray *percentages = @[[NSNumber numberWithFloat:0.6], [NSNumber numberWithFloat:0.7]];
    for (NSNumber *numb in percentages) {
        CGFloat imgWidth = image.size.width * numb.floatValue;
        CGFloat imgheight = image.size.height;
        CGRect leftImgFrame = CGRectMake(0, 0, imgWidth, imgheight);
        CGImageSourceRef source;
        source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
        CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CGImageRef left = CGImageCreateWithImageInRect(maskRef, leftImgFrame);
        NSImage *leftImage = [NSImage.alloc initWithCGImage:left size:CGSizeMake(imgWidth, imgheight)];
        CGImageRelease(left);
        [blackVolumeImages addObject:leftImage];
        [whiteVolumeImages addObject:[leftImage imageTintedWithColor:iconColor]];
    }
    
    // 3x volume
    [blackVolumeImages addObject:[store valueForKey:@"volume"]];
    [whiteVolumeImages addObject:[[store valueForKey:@"volume"] imageTintedWithColor:iconColor]];
    
    // Keybaord
    NSArray *blackKBImages = @[[store valueForKey:@"kon"] , [store valueForKey:@"koff"]];
    NSArray *whiteKBImages = @[[[store valueForKey:@"kon"] imageTintedWithColor:iconColor], [[store valueForKey:@"koff"] imageTintedWithColor:iconColor]];
    
    // Add all the images to the imageStore array
    NSArray *volumeIMG      = [[NSArray alloc] initWithObjects:[blackVolumeImages copy], [whiteVolumeImages copy], nil];
    NSArray *screenIMG      = [self createSetWithImage:[store valueForKey:@"screen"]];
    NSArray *keyboardIMG    = [[NSArray alloc] initWithObjects:blackKBImages, whiteKBImages, nil];
    imageStorage = [[NSArray alloc] initWithObjects:volumeIMG, screenIMG, keyboardIMG, nil];
}

- (void)initializeWindow {
    // Main window
    CGRect scr = [NSScreen mainScreen].visibleFrame;
    int adjust = 0; if (macOSStyle) adjust = 50;
    w = [[mech_NSWindow alloc] initWithContentRect:NSMakeRect(scr.origin.x + (scr.size.width / 2) - (windowWidth / 2), scr.origin.y + scr.size.height - adjust, windowWidth, windowHeight)
                                    styleMask:0
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    
    // Background blur view
    indiBlur = [[NSVisualEffectView alloc] initWithFrame:CGRectMake(0, 0, windowWidth, windowHeight)];
    [indiBlur setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [indiBlur setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [indiBlur setMaterial:NSVisualEffectMaterialDark];
    [indiBlur setState:NSVisualEffectStateActive];
    
    // Icon view
    vol = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 0, windowHeight + 10, windowHeight)];
    [vol setImageAlignment:NSImageAlignLeft];
    
    // Indicator view
    indi = [[AYProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, windowWidth, windowHeight)
                                        progressColor:[NSColor whiteColor]
                                           emptyColor:[NSColor clearColor]
                                             minValue:0
                                             maxValue:100
                                         currentValue:0];
    [indi setWantsLayer:YES];

    // Set some properties for the window
    [w setLevel:NSMainMenuWindowLevel + 999]; // Yeet
    [w setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [w makeKeyAndOrderFront:nil];
    [w setMovableByWindowBackground:NO];
    [w makeKeyAndOrderFront:nil];
    [w setIgnoresMouseEvents:YES];
    [w setOpaque:NO];
    [w setBackgroundColor:[NSColor clearColor]];
    [w.contentView setWantsLayer:YES];
    [w.contentView.layer setCornerRadius:10.0];
    
    [plugin adjustWindow];
    
    // Set our subviews, being mindful of order
    [w.contentView setSubviews:@[indiBlur, indi, vol]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.25;
            w.animator.alphaValue = 0;
        }
        completionHandler:^{ }];
    });
}

- (void)adjustWindow {
    if (macOSStyle) {
        windowHeight = 22;
        windowWidth = 240;
    } else {
        windowHeight = 30;
        windowWidth = 300;
    }
    
    // Adjust views if iOS style is enabled
    if (macOSStyle) {
        vol.frame = NSMakeRect(4, 0, windowHeight + 10, windowHeight);
        indi.layer.cornerRadius = 3;
        indi.frame = NSMakeRect(28, 9, 204, 6);
        indi.layer.borderWidth = 1;
        w.contentView.layer.cornerRadius = 4;
    } else {
        vol.frame = NSMakeRect(10, 0, windowHeight + 10, windowHeight);
        indi.layer.cornerRadius = 0;
        indi.frame = NSMakeRect(0, 0, windowWidth, windowHeight);
        indi.layer.borderWidth = 0;
        w.contentView.layer.cornerRadius = 10;
    }
}

- (NSArray *)createSetWithImage:(NSImage *)image {
    NSImage *whiteImage = [image imageTintedWithColor:iconColor];
    return @[image, whiteImage];
}

- (void)showHUD :(int)hudType :(float)hudValue {
    if (animateHUD == 0) [plugin readPreferences];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Dark mode / Light mode
        int darkMode = 0;
    
        // Position the HUD in the middle of the menubar on the active screen
        CGRect scr = [NSScreen mainScreen].visibleFrame;
        float xPos = scr.origin.x + (scr.size.width / 2) - (windowWidth / 2);
        float yPos = scr.origin.y + scr.size.height + 1;
    
        // Menubar hidden check
        if ([NSApp presentationOptions] == NSApplicationPresentationAutoHideMenuBar ||
            [NSApp presentationOptions] == NSApplicationPresentationHideMenuBar) {
            if (NSEvent.mouseLocation.y < scr.size.height - windowHeight)
                yPos -= windowHeight;
        }
    
        // Adjust for fullscreen
        if (yPos == scr.size.height || yPos == scr.size.height + scr.origin.y)
            yPos -= windowHeight;
        
        // Adjust... some more
        [plugin adjustWindow];
        
        // Adjust based on style
        if (macOSStyle) {
            NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            darkMode = [osxMode isEqualToString:@"Dark"];
            if (darkMode) {
                [indi setProgressColor:NSColor.whiteColor];
                [indi.layer setBorderColor:NSColor.whiteColor.CGColor];
                [indiBlur setMaterial:NSVisualEffectMaterialDark];
            } else {
                [indi setProgressColor:NSColor.blackColor];
                [indi.layer setBorderColor:NSColor.blackColor.CGColor];
                [indiBlur setMaterial:NSVisualEffectMaterialSelection];
            }
        } else {
            darkMode = 0;
            yPos -= 50;
            [indi setProgressColor:NSColor.whiteColor];
            [indi.layer setBorderColor:NSColor.whiteColor.CGColor];
            [indiBlur setMaterial:NSVisualEffectMaterialDark];
        }
        
        // Custom colors
        if (useCustomColor && sliderColor != nil) {
            darkMode = 1;
            [indi setProgressColor:sliderColor];
            [indi.layer setBorderColor:sliderColor.CGColor];
            [indiBlur setMaterial:NSVisualEffectMaterialSelection];
        }
        
        // Get icon
        NSImage *displayImage = [NSImage new];
        NSArray *imagesArray = [imageStorage objectAtIndex:hudType];
        float newHUDValue = hudValue;
        // 0 = Volume, 1 = Screen, 2 = Keyboard
        if (hudType == 0) {
            NSArray *imgList = [[NSArray alloc] initWithArray:[imagesArray objectAtIndex:darkMode]];
            if ([self getMuteState]) {
                newHUDValue = 0;
                displayImage = imgList.firstObject;
            } else {
                displayImage = [imgList objectAtIndex:ceil(hudValue / 33.34)];
            }
        } else if (hudType == 2) {
            NSArray *imgList = [[NSArray alloc] initWithArray:[imagesArray objectAtIndex:darkMode]];
            if (hudValue == 0) {
                newHUDValue = 0;
                displayImage = imgList.lastObject;
            } else {
                displayImage = imgList.firstObject;
            }
        } else {
            displayImage = [imagesArray objectAtIndex:darkMode];
        }

        [indiBlur setFrame:CGRectMake(0, 0, windowWidth, windowHeight)];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.2;
            [indi.animator setDoubleValue:newHUDValue];
            if (hudType == 0 && [self getMuteState]) {
                [indi.animator setDoubleValue:0];
            }
        }
        completionHandler:^{ }];
        [vol setImage:displayImage];
        [w setFrame:CGRectMake(xPos, yPos, windowWidth, windowHeight) display:NO];
        [w setAlphaValue:100.0];
    });
    
    // Hide the window in 1 second
    animateHUD ++;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self hideHUD];
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        // Cancel any existing animation and show the window
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.01];
        [[w animator] setAlphaValue:1.0];
        [NSAnimationContext endGrouping];
    });
}

- (void)hideHUD {
    if (animateHUD <= 1) {
        // Fade out the HUD
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 2;
            w.animator.alphaValue = 0;
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

ZKSwizzleInterface(mech_OSDUIHelperOSDUIHelper, OSDUIHelper.OSDUIHelper, NSObject)
@implementation mech_OSDUIHelperOSDUIHelper

- (void)showImage:(long long)arg1 onDisplayID:(unsigned int)arg2 priority:(unsigned int)arg3 msecUntilFade:(unsigned int)arg4 filledChiclets:(unsigned int)arg5 totalChiclets:(unsigned int)arg6 locked:(BOOL)arg7 {
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
    
    [plugin showHUD:HUDType :percentageFull];
//    ZKOrig(void, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}

@end
