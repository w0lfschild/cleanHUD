//
//  MDCFullScreenDetectorWindow.h
//  FullScreenDetector
//
//  Created by Mark Christian on 1/19/13.
//  Copyright (c) 2013 Mark Christian. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#pragma mark Notifications
extern NSString * kMDCFullScreenDetectorSwitchedToFullScreenApp;
extern NSString * kMDCFullScreenDetectorSwitchedToRegularSpace;

@interface MDCFullScreenDetector : NSObject

@property (readonly) BOOL fullScreenAppIsActive;

@end
