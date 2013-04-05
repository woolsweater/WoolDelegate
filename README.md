WoolDelegate
============

Generic delegate class for Cocoa and Cocoa Touch; uses Blocks to respond to delegate methods.

This requires libffi: https://github.com/atgreen/libffi

It uses libffi to interface between an NSInvocation and a Block, pulling the argument values from the invocation object and calling the Block's invoke pointer.
