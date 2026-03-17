import ofApp

# example state
var frameCount = 0

proc update() {.cdecl.} =
    inc frameCount

proc draw() {.cdecl.} =
    discard

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey, " (", $key, "), frameCount: ", $frameCount

when isMainModule:
    var app = makeOfApp(update=update, draw=draw, keyPressed=keyPressed)
    app.run(800, 600)