import ofApp
import ofx_addons

import std/strformat
import std/strutils
import nimline
import cppstl
import system

{.emit: """
#include "ofMain.h"
#include "ofxHapPlayer.h"
""" .}

defineCppType(ofxHapPlayer, "ofxHapPlayer", "ofxHapPlayer.h")

var is_loaded = false
var player: ofxHapPlayer

proc setup() {.cdecl.} =
    discard

proc update() {.cdecl.} =
    let r: float = global.ofGetFrameRate()
    let s = fmt"{r:.2f}"
    discard global.ofSetWindowTitle(s)

    if is_loaded and player.isLoaded().to(bool):
        discard player.update()
        # echo $player.getPosition().to(float)

proc draw() {.cdecl.} =
    discard global.ofSetColor(255)

    if not is_loaded:
        discard global.ofDrawBitmapString("drop hap file here", 30, 30)
    else:
        if player.isLoaded().to(bool):
            discard player.draw(0, 0, global.ofGetWidth(), global.ofGetHeight())

            discard global.ofSetColor(76, 128)
            discard global.ofDrawRectangle(0, 10, 200, 40)

            discard global.ofSetColor(255)
            let t = player.getPosition().to(float)
            discard global.ofDrawBitmapString(fmt"{t:0.2f}", 30, 30)

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey
    if key == global.OF_KEY_ESC or ckey == 'q' or ckey == 'Q':
        discard global.ofExit()
        quit(0)

proc filesDropped(info: pointer) {.cdecl.} =
    let raw_files = cast[ptr CppVector[CppString]](info)[]

    var files: seq[string] = @[]
    for i in 0 ..< raw_files.len:
        let f = raw_files[i]
        files.add($f)

    echo "dropped files: ", $(files)

    if files.len > 0 and 
        (files[0].endsWith(".mov")):
        discard player.load(files[0])
        discard player.play()
        discard player.setLoopState(global.OF_LOOP_NORMAL);

        is_loaded = true
    else:
        echo "[Warning] files dropped, but only .mov is supported!"

when isMainModule:
    var app = makeOfApp(
        setup=setup, update=update, draw=draw,
        keyPressed=keyPressed,
        dragEvent=filesDropped)
    app.run(800, 600)