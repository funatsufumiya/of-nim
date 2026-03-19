import ofApp
import nimline
import ofx_addons
import system

{.emit: """
#include "ofMain.h"
#include "ofxImGui.h"
""" .}

defineCppType(ofxImGui_Gui, "ofxImGui::Gui", "ofxImGui.h")

proc ImGui_Begin(s: cstring) {.importcpp: "ImGui::Begin(@)", header: "ofxImGui.h" .}
proc ImGui_End() {.importcpp: "ImGui::End()", header: "ofxImGui.h" .}
proc ImGui_Text(s: cstring) {.importcpp: "ImGui::Text(@)", header: "ofxImGui.h" .}
proc ImGui_SliderFloat(s: cstring, f: ptr[cfloat], min: float, max: float) {.importcpp: "ImGui::SliderFloat(@)", header: "ofxImGui.h" .}

var gui: ofxImGui_Gui

proc setup() {.cdecl.} =
    discard global.ofSetWindowTitle("imgui test")
    discard gui.setup()

proc update() {.cdecl.} =
    discard

var float_val: cfloat = 1.0

proc draw() {.cdecl.} =
    discard gui.begin()
    ImGui_Begin("test")
    ImGui_Text("this is test!!")
    ImGui_SliderFloat("slider", float_val.addr, 0, 1)
    ImGui_End()
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
