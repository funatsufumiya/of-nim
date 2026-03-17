import ofApp
import std/strformat
import nimline

{.emit: """
#include "ofMain.h"
""" .}

var frameCount = 0

proc nimUpdate(user: pointer) {.cdecl.} =
    inc frameCount
    let r: float = global.ofGetFrameRate()
    let s = fmt"{r:.2f}"
    discard global.ofSetWindowTitle(s)

proc red {.importcpp: "ofColor::red" .}

proc nimDraw(user: pointer) {.cdecl.} =
    discard global.ofSetColor(red)
    discard global.ofDrawRectangle(
        global.ofGetMouseX() - 50,
        global.ofGetMouseY() - 50,
        100, 100)

proc nimKey(user: pointer, key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey, " (", $key, "), frameCount: ", $frameCount

when isMainModule:
    var app = makeOfApp(update=nimUpdate, draw=nimDraw, key=nimKey, user=nil)
    app.run(800, 600)