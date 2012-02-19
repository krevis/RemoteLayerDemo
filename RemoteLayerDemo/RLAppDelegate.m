//
//  RLAppDelegate.m
//  RemoteLayerDemo
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RLAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <servers/bootstrap.h>


@interface RLAppDelegate ()

@property (nonatomic, assign) xpc_connection_t serviceConnection;
@property (nonatomic, retain) CALayer* remoteLayer;

@end


@implementation RLAppDelegate

@synthesize window = _window;
@synthesize view = _view;
@synthesize serviceConnection = _serviceConnection;
@synthesize remoteLayer = _remoteLayer;

- (void)dealloc
{
    if (_serviceConnection)
        xpc_release(_serviceConnection);
    
    [_remoteLayer release];
    
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Set up our connection to our XPC service
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _serviceConnection = xpc_connection_create("com.snoize.RemoteLayerDemoService", queue);
    if (_serviceConnection) {
        xpc_connection_set_event_handler(_serviceConnection, ^(xpc_object_t object) {
            if (object == XPC_ERROR_CONNECTION_INVALID) {
                xpc_release(_serviceConnection);
                _serviceConnection = NULL;
            }
        });
        
        xpc_connection_resume(_serviceConnection);
    }

    // Get the CARemoteLayerServer and publish its port in the bootstrap namespace, so the XPC service can find it.
    // Ideally we would just send this port to the service over XPC,
    // but (currently) XPC can't send or receive Mach ports.
    // This is a insecure, deprecated, but convenient way to do it.
    CARemoteLayerServer* layerServer = [CARemoteLayerServer sharedServer];
    kern_return_t err = bootstrap_register(bootstrap_port, "com.snoize.RemoteLayerDemo.layerServerPort", layerServer.serverPort);
    if (err != KERN_SUCCESS) {
        NSLog(@"bootstrap_register failed: %d", err);
    } else {
        NSLog(@"port published: %d", layerServer.serverPort);
    }
    
    // Set up a view with a layer in it. We'll add the remote layer to it
    // as a sublayer.
    
    CALayer* layer = [CALayer layer];
    layer.backgroundColor = CGColorCreateGenericRGB(0.f, 0.f, 1.f, 1.f);
    layer.bounds = _view.bounds;
    
    _view.layer = layer;
    [_view setWantsLayer:YES];
}

- (IBAction)useService:(id)sender
{   
    if (!self.serviceConnection)
        return;
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "hi", "mom");
    
    
    xpc_connection_send_message_with_reply(self.serviceConnection, message, dispatch_get_main_queue(), ^(xpc_object_t reply) {
#if 1
        char* s = xpc_copy_description(reply);
        NSLog(@"Got a reply: %s", s);
        free(s);
#endif
        
        uint32_t clientID = xpc_dictionary_get_uint64(reply, "clientID");
        if (clientID != 0) {
            CALayer* remoteLayer = [CALayer layerWithRemoteClientId:clientID];
            if (remoteLayer) {
                [_view.layer addSublayer:remoteLayer];
            } else {
                NSLog(@"Couldn't create remote CALayer");
            }
        }
    });

    xpc_release(message);
}

@end
