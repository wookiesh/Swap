# Swap

This is a port of lagarto-swap from [PanStamps](http://www.panstamp.com) author to nodejs.

There's two reasons for this:
* I wanted to try nodejs for some time now
* I love the approach of a web interface for a serial gateway but missed some functions

This is also based on a modification of the gateway interface:
* data and command modes do not exist anymore
* data sent to stamps network starting with 'S' (for send)

This projects uses socketstream as a communication framework.

## Dependencies
* libzmq
* libzmq-dev

Zmq easier for connections and so on than mqtt