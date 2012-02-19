//
//  RLAppDelegate.m
//  RemoteLayerDemo
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RLAppDelegate.h"

@interface RLAppDelegate ()

@property (nonatomic, assign) xpc_connection_t serviceConnection;

@end


@implementation RLAppDelegate

@synthesize window = _window;
@synthesize serviceConnection = _serviceConnection;

- (void)dealloc
{
    if (_serviceConnection)
        xpc_release(_serviceConnection);
    
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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
}

- (IBAction)useService:(id)sender
{   
    if (!self.serviceConnection)
        return;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "hi", "mom");
    
    xpc_connection_send_message_with_reply(self.serviceConnection, message, queue, ^(xpc_object_t reply) {
#if 1
        char* s = xpc_copy_description(reply);
        NSLog(@"Got a reply: %s", s);
        free(s);
#endif        
    });

    xpc_release(message);
}

@end
