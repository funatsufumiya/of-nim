import ofApp
import std/strformat
import nimline

{.emit: """
#include "ofMain.h"
""" .}

proc nimUpdate(user: pointer) {.cdecl.} =
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

when isMainModule:
    var app = makeOfApp(update=nimUpdate, draw=nimDraw)
    app.run(800, 600)