//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Jun 14 2016 15:02:16).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <objc/NSObject.h>

#import "NSMachPortDelegate-Protocol.h"

@class NSMachPort, NSString;

@interface BezelServicesTask : NSObject <NSMachPortDelegate>
{
    unsigned int _cgsConnectionID;
    NSMachPort *_cgsMachPort;
    BOOL _userLoggedIn;
    int _builtinDisplayID;
    BOOL _screenIsLocked;
}

+ (id)alloc;
+ (void)releaseSingleton;
+ (id)getSingleton;
@property(readonly) unsigned int cgsConnectionID; // @synthesize cgsConnectionID=_cgsConnectionID;
- (void)synchronizeBSPrefsForUserName:(struct __CFString *)arg1 hostName:(struct __CFString *)arg2;
- (void)resetBSPrefsToDefaultsForUserName:(struct __CFString *)arg1 hostName:(struct __CFString *)arg2;
- (void)setBSPrefs:(id)arg1 userName:(struct __CFString *)arg2 hostName:(struct __CFString *)arg3;
- (id)defaultBSPrefValues;
- (void)screenIsUnlocked:(id)arg1;
- (void)screenIsLocked:(id)arg1;
- (void)displayIdleTimerFired:(id)arg1;
- (void)handleRemoteEventWithPage:(unsigned short)arg1 usage:(unsigned short)arg2 flags:(unsigned short)arg3 value:(int)arg4;
- (int)remoteControlFeatureAvailable;
- (int)remoteControlPropertyAvailable:(id)arg1;
- (void)kernelPreferenceSetPreferences:(id)arg1 capabilityID:(unsigned int)arg2 values:(id)arg3;
- (id)kernelPreferenceGetPreferences:(id)arg1 capabilityID:(unsigned int)arg2;
- (id)kernelPreferenceGetPreference:(id)arg1 capabilityID:(unsigned int)arg2 forKey:(id)arg3;
- (void)kernelPreferenceCreate:(id)arg1 ResetToDefaults:(BOOL)arg2;
- (void)kernelPreferenceChanged:(id)arg1;
- (void)setDisplayValue:(float)arg1;
- (void)setKeyboardValue:(float)arg1;
- (int)isKeyboardSaturated:(int *)arg1;
- (int)ambientFeatureAvailable:(int)arg1;
- (int)setObject:(id)arg1 forPrefKey:(id)arg2;
- (id)objectForPrefKey:(id)arg1;
- (void)setPreference:(id)arg1;
- (id)preference;
- (BOOL)isSimpleFinder;
- (BOOL)isScreenCaptured;
- (void)launchSystemPreferences:(id)arg1;
- (void)movedOnConsole:(id)arg1;
- (void)handleCGSEvent:(struct _CGSEventRecord *)arg1;
- (void)handlePortMessage:(id)arg1;
- (void)setupCoreGraphics;
- (void)facetimeCallRingStop;
- (void)facetimeCallRingStart:(id)arg1;
- (BOOL)userLoggedIn;
- (void)willLogout;
- (void)didLogin;
- (void)didStartup;
@property int builtinDisplayID;
- (void)dealloc;
- (void)sensorPluginDepartureHandler;
- (void)sensorPluginArrivalHandler;
- (id)init;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

