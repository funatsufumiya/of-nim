import ofApp
import nimline
import ofx_addons
import system

{.emit: """
#include "ofMain.h"
#include "ofxImGui.h"
""" .}

defineCppType(ofxImGui_Gui, "ofxImGui::Gui", "ofxImGui.h")

var gui: ofxImGui_Gui

proc setup() {.cdecl.} =
    discard global.ofSetWindowTitle("imgui test")
    discard gui.setup()

proc update() {.cdecl.} =
    discard

var float_val: cfloat = 1.0

proc draw() {.cdecl.} =
    discard gui.begin()
    discard invokeFunction("ImGui::Begin","test")
    discard invokeFunction("ImGui::Text", "this is test!!")
    discard invokeFunction("ImGui::SliderFloat", "slider", float_val.addr, 0, 1)
    discard invokeFunction("ImGui::End")
    discard gui.end()

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    # echo "key: ", $ckey
    if ckey == 'f':
        discard global.ofToggleFullscreen()
    elif ckey == 'm':
        echo "total mem: ", getTotalMem()

when isMainModule:
    var app = makeOfApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
    app.run(800, 600)
