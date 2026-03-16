import ofApp

# example state
var frameCount = 0

proc nimUpdate(user: pointer) {.cdecl.} =
    inc frameCount

proc nimDraw(user: pointer) {.cdecl.} =
    discard

proc nimKey(user: pointer, key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey, " (", $key, "), frameCount: ", $frameCount

when isMainModule:
    var app = makeOfApp(update=nimUpdate, draw=nimDraw, key=nimKey, user=nil)
    app.run(800, 600)