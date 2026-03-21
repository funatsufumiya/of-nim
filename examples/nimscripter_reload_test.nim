import ofApp
import std/strformat
import nimline
import system
import nimscripter
import std/random
import std/os
import std/paths

randomize()
let projectRoot = parentDir(system.currentSourcePath)

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

var intr: Option[Interpreter]
let scriptPath = projectRoot / "nimscripter_reload_script.nims"

var is_firstload = true

proc reloadScript() =
  if is_firstload:
    echo "Loading script..."
  else:
    echo "Reloading script..."

  let script = NimScriptFile(readFile(scriptPath))
  intr = loadScript(script, implNimScriptModule(myImpl))

  if is_firstload:
    echo "Script loaded!"
  else:
    echo "Script reloaded!"

  is_firstload = false

proc setup() {.cdecl.} =
  discard global.ofSetFrameRate(60)
  echo "projectRoot: ", projectRoot
  echo "scriptPath: ", scriptPath
  reloadScript()
  intr.invoke(setup)

proc update() {.cdecl.} =
  let r: float = global.ofGetFrameRate()
  let s = fmt"{r:.2f}"
  discard global.ofSetWindowTitle(s)
  intr.invoke(update)

proc draw() {.cdecl.} =
  discard global.ofClear(0)
  discard global.ofSetColor(255, 255, 255)
  intr.invoke(draw)

  discard global.ofSetColor(255)
  discard global.ofDrawBitmapString("type [R] to reload script", 30, 100)

proc keyPressed(key: cint) {.cdecl.} =
  let ckey = cast[char](key)
  if ckey == 'f' or ckey == 'F':
    discard global.ofToggleFullscreen()
  elif key == global.OF_KEY_ESC or ckey == 'q' or ckey == 'Q':
    discard global.ofExit()
    quit()
  elif ckey == 'r' or ckey == 'R':
    reloadScript()

when isMainModule:
  var app = makeOfApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
  app.run(800, 600)
