import ofApp
import std/strformat
import nimline

{.emit: """
#include "ofMain.h"
""" .}

proc red {.importcpp: "ofColor::red" .}

proc setup() {.cdecl.} =
    discard global.ofSetFrameRate(60)

proc update() {.cdecl.} =
    let r: float = global.ofGetFrameRate()
    let s = fmt"{r:.2f}"
    discard global.ofSetWindowTitle(s)

proc draw() {.cdecl.} =
    discard global.ofSetColor(red)
    discard global.ofDrawRectangle(
        global.ofGetMouseX() - 50,
        global.ofGetMouseY() - 50,
        100, 100)

when isMainModule:
    var app = makeOfApp(setup=setup, update=update, draw=draw)
    app.run(800, 600)