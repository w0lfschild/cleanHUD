//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Jun  9 2015 22:53:21).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2014 by Steve Nygard.
//

#import "ControlStrip.SliderButton.h"

@class NSString;

@interface ControlStrip.BrightnessButton : ControlStrip.SliderButton
{
    // Error parsing type: , name: display
    // Error parsing type: , name: lastUpdate
    // Error parsing type: , name: addedObserver
}

- (CDUnknownBlockType).cxx_destruct;
- (id)initWithCoder:(id)arg1;
- (id)initWithFrame:(struct CGRect)arg1;
- (void)brightnessDidChange:(id)arg1;
- (void)dealloc;
@property(nonatomic, copy) NSString *preferencePanePath;
- (void)initObserver;
- (void)willPresentPopover;

@end
