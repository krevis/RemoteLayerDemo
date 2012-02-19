//
//  RLAppDelegate.h
//  RemoteLayerDemo
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 Kurt Revis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RLAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSView *view;

- (IBAction)getRemoteLayer:(id)sender;
- (IBAction)changeColor:(id)sender;
- (IBAction)removeRemoteLayer:(id)sender;

@end
