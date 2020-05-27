//
//  cleanHUDPrefs.m
//  cleanHUDPrefs
//
//  Created by Jeremy on 5/25/20.
//  Copyright © 2020 Jeremy Legendre. All rights reserved.
//

#import "cleanHUDPrefs.h"

@interface customView : NSView

@property IBOutlet NSButton    *pluginIcon;
@property IBOutlet NSTextField *pluginName;
@property IBOutlet NSTextField *pluginVersion;
@property IBOutlet NSTextField *pluginCopyright;

@property IBOutlet NSButton *macStyleButton;
@property IBOutlet NSButton *colorButton;
@property IBOutlet NSTextField *sliderColor;
@property IBOutlet NSTextField *iconColor;

@end

@implementation customView

- (void)viewWillDraw {
    [super viewWillDraw];
    
    NSString *ape = [@"~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist" stringByExpandingTildeInPath];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:ape];
    
    // Setup header
    self.pluginIcon.image = [[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GroupIcon.icns"];
    self.pluginName.stringValue = @"cleanHUD";
    self.pluginVersion.stringValue = @"Version 0.11.1 (421)";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    NSString * currentYEAR = [formatter stringFromDate:[NSDate date]];
    [self.pluginCopyright setStringValue:[NSString stringWithFormat:@"Copyright © 2015 - %@ macEnhance", currentYEAR]];
    
    if ([d valueForKey:@"macOSStyle"]) {
        if ([[d valueForKey:@"macOSStyle"] boolValue])
            [self.macStyleButton setState:NSControlStateValueOn];
        else
            [self.macStyleButton setState:NSControlStateValueOff];
    }

    if ([d valueForKey:@"useCustomColor"]) {
        if ([[d valueForKey:@"useCustomColor"] boolValue])
            [self.colorButton setState:NSControlStateValueOn];
        else
            [self.colorButton setState:NSControlStateValueOff];
    }
    
    // Setup slider color
    if ([d valueForKey:@"sliderColor"])
        self.sliderColor.stringValue = (NSString*)[d valueForKey:@"sliderColor"];
    [self.sliderColor setTarget:self];
    [self.sliderColor setAction:@selector(adjustSliderColor:)];

    // Setup icon color
    if ([d valueForKey:@"iconColor"])
        self.iconColor.stringValue = (NSString*)[d valueForKey:@"iconColor"];
    [self.iconColor setTarget:self];
    [self.iconColor setAction:@selector(adjustIconColor:)];
}

- (IBAction)adjustSliderColor:(NSTextField*)sender {
    NSString *res = [@"defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist sliderColor -string " stringByAppendingString:sender.stringValue];
    system(res.stringByExpandingTildeInPath.UTF8String);
}

- (IBAction)adjustIconColor:(NSTextField*)sender {
    NSString *res = [@"defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist iconColor -string " stringByAppendingString:sender.stringValue];
    system(res.stringByExpandingTildeInPath.UTF8String);
}



@end

@interface cleanHUDPrefs ()

@end

@implementation cleanHUDPrefs

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)macOSStyle:(NSButton*)sender {
    if (sender.state)
        system("defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist macOSStyle -bool true");
    else
        system("defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist macOSStyle -bool false");
}

- (IBAction)useColor:(NSButton*)sender {
    if (sender.state)
        system("defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist useCustomColor -bool true");
    else
        system("defaults write ~/Library/Containers/com.apple.OSDUIHelper/Data/Library/Preferences/com.apple.OSDUIHelper.plist useCustomColor -bool false");
}

- (IBAction)visitWebsite:(NSButton*)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://htmlcolorcodes.com/"]];
}

@end
