# of-nim

nim openFrameworks integration

openFrameworks v0.12.0, nim 2.2.8

```nim
import ofApp
import std/strformat
import nimline

{.emit: """
#include "ofMain.h"
""" .}

proc red {.importcpp: "ofColor::red" .}

proc update(user: pointer) {.cdecl.} =
    let r: float = global.ofGetFrameRate()
    let s = fmt"{r:.2f}"
    discard global.ofSetWindowTitle(s)

proc draw(user: pointer) {.cdecl.} =
    discard global.ofSetColor(red)
    discard global.ofDrawRectangle(
        global.ofGetMouseX() - 50,
        global.ofGetMouseY() - 50,
        100, 100)

when isMainModule:
    var app = makeOfApp(update=update, draw=draw)
    app.run(800, 600)
```

![docs/screenshot.png](docs/screenshot.png)

## Pre-requisites

### Windows

```bash
$ .¥scripts¥init_win.ps1
```

### Mac

```bash
$ ./scripts/init_mac.sh
```

## Examples

```bash
$ nim c -r examples/hello.nim
$ nim c -r examples/cpp_interop.nim
```

## TODO

- oF addons support
- project generator
