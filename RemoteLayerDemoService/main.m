//
//  main.m
//  RemoteLayerDemoService
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 Kurt Revis. All rights reserved.
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>
#include <QuartzCore/QuartzCore.h>
#include <servers/bootstrap.h>


static CARemoteLayerClient* sRemoteLayerClient = nil;
static BOOL sIsTransactionOpen = NO;


static void RemoteLayerDemoService_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
{
#if 0
    char* s = xpc_copy_description(event);
    NSLog(@"Got a message: %s", s);
    free(s);
#endif

	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
		}
	} else {
		assert(type == XPC_TYPE_DICTIONARY);
		// Handle the message.
        
        switch (xpc_dictionary_get_uint64(event, "command"))
        {
            case 0:
                // We can't tell if the value was really 0, or if there was no value 
                // for this key in the dictionary. So:
            default:
                // Do nothing.
                break;
                
            case 1:
            {
                // Open a transaction, so the service support code doesn't
                // terminate us automatically.
                if (!sIsTransactionOpen) {
                    xpc_transaction_begin();
                    sIsTransactionOpen = YES;
                }

                // Reply with the client ID of the remote layer.
                xpc_connection_t conn = xpc_dictionary_get_remote_connection(event);
                if (conn) {
                    xpc_object_t reply = xpc_dictionary_create_reply(event);
                    if (reply) {
                        xpc_dictionary_set_uint64(reply, "clientID", sRemoteLayerClient.clientId);
                        xpc_connection_send_message(conn, reply);
                        xpc_release(reply);
                    }
                }

                break;
            }
                
            case 2:
            {
                // Change the color of the layer, in an animated way. No reply.

                [CATransaction begin];
                [CATransaction setAnimationDuration:0.5];

                CGFloat r = drand48();
                CGFloat g = drand48();
                CGFloat b = drand48();
                CGColorRef c = CGColorCreateGenericRGB(r, g, b, 1.f);
                sRemoteLayerClient.layer.backgroundColor = c;
                CGColorRelease(c);
                
                [CATransaction commit];

                break;
            }
                
            case 3:
            {
                // The app says we can stop now. No reply.
                if (sIsTransactionOpen) {
                    xpc_transaction_end();
                    sIsTransactionOpen = NO;
                }
                break;
            }
        }        
	}
}

static void RemoteLayerDemoService_event_handler(xpc_connection_t peer) 
{
	// By default, new connections will target the default dispatch
	// concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		RemoteLayerDemoService_peer_event_handler(peer, event);
	});
    
    // Look up the Mach port of the CARemoteLayerServer in the application.
    // Ideally the app would send us this port over XPC, but XPC can't send Mach ports...
    // So, for now, this is an insecure but straightforward way to get the port.
    mach_port_t layerServerPort = MACH_PORT_NULL;
    kern_return_t err = bootstrap_look_up(bootstrap_port, "com.snoize.RemoteLayerDemo.layerServerPort", &layerServerPort);
    if (err != KERN_SUCCESS) {
        NSLog(@"bootstrap_look_up failed: %d", err);
    } else {        
        // Create a CARemoteLayerClient, and stuff a layer into it.
        sRemoteLayerClient = [[CARemoteLayerClient alloc] initWithServerPort:layerServerPort];
        if (!sRemoteLayerClient) {
            NSLog(@"Couldn't create CARemoteLayerClient");
        } else {
            CALayer* layer = sRemoteLayerClient.layer;
            if (!layer) {
                layer = [CALayer layer];
                layer.bounds = CGRectMake(0.f, 0.f, 100.f, 100.f);
                
                CGColorRef c = CGColorCreateGenericRGB(0.f, 1.f, 0.f, 1.f);
                layer.backgroundColor = c;
                CGColorRelease(c);
                
                sRemoteLayerClient.layer = layer;
            }
        }
    }
    
    srand48(time(NULL));
	
	// This will tell the connection to begin listening for events. If you
	// have some other initialization that must be done asynchronously, then
	// you can defer this call until after that initialization is done.
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_main(RemoteLayerDemoService_event_handler);
	return 0;
}
