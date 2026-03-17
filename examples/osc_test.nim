import ofApp
import nimline
import ofx_addons

{.emit: """
#include "ofMain.h"
#include "ofxOsc.h"
""" .}

proc setup() {.cdecl.} =
    discard

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