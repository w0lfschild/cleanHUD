//
//  MDCFullScreenDetectorWindow.m
//  FullScreenDetector
//
//  Created by Mark Christian on 1/19/13.
//  Copyright (c) 2013 Mark Christian. All rights reserved.
//

#import "MDCFullScreenDetector.h"

#pragma mark Notifications
NSString * kMDCFullScreenDetectorSwitchedToFullScreenApp = @"com.whimsicalifornia.fullscreendetector.switchedToFullScreenApp";
NSString * kMDCFullScreenDetectorSwitchedToRegularSpace = @"com.whimsicalifornia.fullscreendetector.switchedToRegularSpace";

@interface MDCFullScreenDetectorWindow : NSWindow


#pragma mark - Notification handlers
- (void)activeSpaceDidChange:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;

#pragma mark - Detecting full screen state
- (void)updateFullScreenStatus;

@property (nonatomic) BOOL fullScreenAppIsActive;

@end

@implementation MDCFullScreenDetectorWindow

- (id)init
{
    
    //  Make sure the application doesn't have LSUIElement set to YES; if so, full screen detection won't work, and we should log a warning.
    NSNumber *uiElement = [NSBundle mainBundle].infoDictionary[@"LSUIElement"];
    if (uiElement.boolValue)
    {
        NSLog(@"Warning to developer of %@: full screen detection does not work when LSUIElement is set to YES in Info.plist.", [NSBundle mainBundle].infoDictionary[@"CFBundleName"]);
    }
    
    NSInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    
    self = [super initWithContentRect:NSZeroRect styleMask:styleMask backing:NSBackingStoreBuffered defer:NO];
    if (self)
    {
        _fullScreenAppIsActive = NO;
        
        //  Register for notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(activeSpaceDidChange:) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
    }
    
    return self;
}

#pragma mark - Notification handlers
- (void)activeSpaceDidChange:(NSNotification *)notification
{
    [self updateFullScreenStatus];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self activeSpaceDidChange:notification];
}

#pragma mark - Detecting full screen state
- (void)updateFullScreenStatus {
    //  We're moved to ordinary spaces automatically, but not fullscreen apps
    BOOL newFullScreenAppIsActive = !self.isOnActiveSpace;
    
    if (newFullScreenAppIsActive == _fullScreenAppIsActive)
    {
        //  No change
        return;
    }
    
    //  Update state
    _fullScreenAppIsActive = newFullScreenAppIsActive;
    
    //  Post notification
    NSString *notificationName;
    if (_fullScreenAppIsActive)
    {
        notificationName = kMDCFullScreenDetectorSwitchedToFullScreenApp;
    } else {
        notificationName = kMDCFullScreenDetectorSwitchedToRegularSpace;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
}

#pragma mark - NSWindow overrides
- (CGFloat)alphaValue {
    return 0.5;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (NSWindowCollectionBehavior)collectionBehavior
{
    return NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorCanJoinAllSpaces;
}

- (BOOL)ignoresMouseEvents {
    return YES;
}

- (NSInteger)level {
    return kCGScreenSaverWindowLevel;
}



@end

@interface MDCFullScreenDetector ()
@property (nonatomic) MDCFullScreenDetectorWindow* window;
@property (nonatomic) BOOL isInited;
@end

@implementation MDCFullScreenDetector
-(void)setup
{
    if (!_isInited)
    {
        _window = [[MDCFullScreenDetectorWindow alloc] init];
        _isInited = YES;
    }
    
}
-(instancetype)init
{
    self = [super init];
    if (self)
    {
        [self setup];
    }
    return self;
}
- (void)awakeFromNib
{
    [self setup];
}

- (BOOL)fullScreenAppIsActive {
    return [_window fullScreenAppIsActive];
}
@end
