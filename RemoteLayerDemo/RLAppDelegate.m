//
//  RLAppDelegate.m
//  RemoteLayerDemo
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 Kurt Revis. All rights reserved.
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
    
    _view.layer = layer;
    [_view setWantsLayer:YES];
}

- (IBAction)getRemoteLayer:(id)sender
{   
    // Send a message to the service, asking for a remote layer's client ID.
    // When it replies, make a CALayer with that client ID and add it to our view.
    
    if (!self.serviceConnection)
        return;
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(message, "command", 1);
    
    xpc_connection_send_message_with_reply(self.serviceConnection, message, dispatch_get_main_queue(), ^(xpc_object_t reply) {        
#if 0
        char* s = xpc_copy_description(reply);
        NSLog(@"Got a reply: %s", s);
        free(s);
#endif
        
        if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY) {
            uint32_t clientID = xpc_dictionary_get_uint64(reply, "clientID");
            if (clientID != 0) {
                // Make our CALayer to represent the remote CALayer
                CALayer* remoteLayer = [CALayer layerWithRemoteClientId:clientID];
                if (remoteLayer) {
                    // And put it in our layer tree, making sure it doesn't animate
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    
                    _view.layer.sublayers = [NSArray arrayWithObject:remoteLayer];
                    
                    // Center it in our bounds
                    CGRect b = _view.layer.bounds;
                    remoteLayer.position = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));;

                    [CATransaction commit];
                } else {
                    NSLog(@"Couldn't create remote CALayer");
                }
            } else {
                NSLog(@"Reply dictionary either didn't have a client ID, or it was zero (unlikely)");
            }
        } else {
            NSLog(@"Got non-dictionary reply (probably an error)");
        }
    });

    xpc_release(message);
}

- (IBAction)changeColor:(id)sender
{   
    // Send a message to the service, asking it to change the remote layer's color.
    // We do not expect a reply.
    
    if (!self.serviceConnection)
        return;
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(message, "command", 2);
        
    xpc_connection_send_message(self.serviceConnection, message);
    
    xpc_release(message);
}

- (IBAction)removeRemoteLayer:(id)sender
{
    // Remove the remote layer.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];    
    _view.layer.sublayers = [NSArray array];
    [CATransaction commit];
    
    // And tell the service that it should tear itself down.
    if (self.serviceConnection)
    {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_uint64(message, "command", 3);
        
        xpc_connection_send_message(self.serviceConnection, message);
        
        xpc_release(message);
    }
}

@end
