//
//  RLAppDelegate.h
//  RemoteLayerDemo
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RLAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (IBAction)useService:(id)sender;

@end
