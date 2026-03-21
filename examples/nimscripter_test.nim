import ofApp
import std/strformat
import nimline
import system
import nimscripter
import std/random

randomize()

{.emit: """
#include "ofMain.h"
""".}

proc mouseX(): float =
  let v: float = global.ofGetMouseX()
  return v

proc mouseY(): float =
  let v: float = global.ofGetMouseY()
  return v

proc color(r, g, b: float) =
  discard global.ofSetColor(r * 255, g * 255, b * 255)

proc randf(): float =
  return rand(1.0)

proc text(s:string, x, y: float) =
  discard global.ofDrawBitmapString(s, x, y)

proc drawAt(x, y: float, s:float = 30) =
  discard global.ofDrawEllipse(x, y, s, s)

exportTo(myImpl, text, drawAt, mouseX, mouseY, color, randf)

let script = NimScriptFile("""
proc setup*() =
  echo "hello from nimscript!"

proc update*() =
  discard

proc draw*() =
  text("this is drawn from script!", 30, 30)

  color(randf(), randf(), randf())
  drawAt(mouseX(), mouseY())
""")

let intr = loadScript(script, implNimScriptModule(myImpl))

proc setup() {.cdecl.} =
  discard global.ofSetFrameRate(60)
  intr.invoke(setup)

proc update() {.cdecl.} =
  let r: float = global.ofGetFrameRate()
  let s = fmt"{r:.2f}"
  discard global.ofSetWindowTitle(s)
  intr.invoke(update)

proc draw() {.cdecl.} =
  discard global.ofSetColor(255, 255, 255)
  intr.invoke(draw)

proc keyPressed(key: cint) {.cdecl.} =
  let ckey = cast[char](key)
  if ckey == 'f' or ckey == 'F':
    discard global.ofToggleFullscreen()
  elif key == global.OF_KEY_ESC or ckey == 'q' or ckey == 'Q':
    discard global.ofExit()
    quit()

when isMainModule:
  var app = makeOfApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
  app.run(800, 600)
