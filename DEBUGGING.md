# Debugging Notes

## Issue: Bidirectional Streaming Deadlock

### Observed Behavior
- Server receives ComputeFunction call
- Server successfully enters the for loop over request_iterator
- Server only receives the FIRST input message (x)
- Server never receives the SECOND input message (y)
- Server hangs waiting for more messages
- Client also hangs waiting for response

### Root Cause
The issue appears to be that grpc is not delivering all messages from the iterator to the server. Only the first message from iter(messages) is being received.

This could be due to:
1. Buffering issue in grpc
2. Stream not being properly flushed
3. Compatibility issue between generated code versions

### Next Steps
- Investigate grpc stream handling
- Check if messages need explicit flush
- Consider alternative streaming approaches

