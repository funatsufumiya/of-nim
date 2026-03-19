import ofApp
import nimline
import ofx_addons

{.emit: """
#include "ofMain.h"
#include "ofxOsc.h"
""" .}

defineCppType(ofxOscSender, "ofxOscSender", "ofxOsc.h")
defineCppType(ofxOscMessage, "ofxOscMessage", "ofxOsc.h")

var osc_sender: ofxOscSender
var osc_msg: ofxOscMessage

proc setup() {.cdecl.} =
    # discard
    discard osc_sender.setup("127.0.0.1", 12345)
    discard osc_msg.setAddress("/test")
    discard osc_sender.sendMessage(osc_msg)
    discard osc_msg.clear()

proc update() {.cdecl.} =
    discard

proc draw() {.cdecl.} =
    discard

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey

when isMainModule:
    var app = makeOfApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
    app.run(800, 600)
