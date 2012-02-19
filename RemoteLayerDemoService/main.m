//
//  main.m
//  RemoteLayerDemoService
//
//  Created by Kurt Revis on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>

static void RemoteLayerDemoService_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
{
#if 1
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
        
        xpc_connection_t conn = xpc_dictionary_get_remote_connection(event);
        if (conn)
        {
            xpc_object_t reply = xpc_dictionary_create_reply(event);
            if (reply)
            {
                xpc_dictionary_set_string(reply, "hello", "world");
                xpc_connection_send_message(conn, reply);
            }
        }
	}
}

static void RemoteLayerDemoService_event_handler(xpc_connection_t peer) 
{
	// By defaults, new connections will target the default dispatch
	// concurrent queue.
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		RemoteLayerDemoService_peer_event_handler(peer, event);
	});
	
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
