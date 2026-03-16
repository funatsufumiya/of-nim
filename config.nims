import std/strutils
import std/strformat
import std/os
# import std/private/ospaths2
from std/sequtils import toSeq

let projectRoot = parentDir(system.currentSourcePath)

# Ensure required library folders exist; if missing, instruct user to run installer scripts.
proc requireDirs(dirs: seq[string], hintCmd: string) =
  for d in dirs:
    let p = joinPath(projectRoot, d)
    if not dirExists(p):
      let newline = "\n"
      quit(fmt"[Error] {p} not found.{newline}Please run: {hintCmd} to install the libraries and retry.{newline}")

when defined(windows):
  requireDirs(@["lib\\vs"], ".\\scripts\\init_win.ps1")
elif defined(macosx):
  requireDirs(@["lib/osx"], "./scripts/init_mac.sh")

switch("backend", "cpp")

when defined(windows):
  switch("cc", "vcc")
  switch("passC", "/std:c++17")
  switch("passC", "/utf-8")
  switch("passC", "/MD")
else:
  switch("passC", "-std=c++17")

switch("path", "src")
switch("passC", "-Iglew")
switch("passC", "-Icairo")
switch("passC", "-Iinclude")
switch("passC", "-Iinclude/utils")
switch("passC", "-Iinclude/math")
switch("passC", "-Iinclude/events")
switch("passC", "-Iinclude/types")
switch("passC", "-Iinclude/graphics")
switch("passC", "-Iinclude/communication")
switch("passC", "-Iinclude/gl")
switch("passC", "-Iinclude/app")
switch("passC", "-Iinclude/3d")
switch("passC", "-Iinclude/sound")
switch("passC", "-Iinclude/video")
switch("passC", "-Iutils")

# const ofLibPath =
when defined(windows):
  switch("passL", "lib\\vs\\x64\\openframeworksLib.lib")
  switch("passL", "lib\\vs\\x64\\libboost_filesystem-vc141-mt-x64-1_66.lib")
  switch("passL", "lib\\vs\\x64\\libboost_system-vc141-mt-x64-1_66.lib")
  switch("passL", "lib\\vs\\x64\\glew32s.lib")
  switch("passL", "lib\\vs\\x64\\glfw3.lib")
  switch("passL", "lib\\vs\\x64\\tess2.lib")
  switch("passL", "lib\\vs\\x64\\libfreetype.lib")
  switch("passL", "lib\\vs\\x64\\FreeImage.lib")
  switch("passL", "lib\\vs\\x64\\fmod64_vc.lib")
  switch("passL", "lib\\vs\\x64\\uriparser.lib")
  switch("passL", "lib\\vs\\x64\\libssl.lib")
  switch("passL", "lib\\vs\\x64\\libcrypto.lib")
  switch("passL", "lib\\vs\\x64\\libcurl.lib")
  switch("passL", "user32.lib")
  switch("passL", "gdi32.lib")
  switch("passL", "opengl32.lib")
  switch("passL", "glu32.lib")
  switch("passL", "shell32.lib")
  switch("passL", "ole32.lib")
  switch("passL", "winmm.lib")
  switch("passL", "comdlg32.lib")
  switch("passL", "ws2_32.lib")
  switch("passL", "imm32.lib")
  switch("passL", "version.lib")
  switch("passL", "advapi32.lib")
  switch("passL", "Wldap32.lib")
  switch("passL", "Crypt32.lib")

elif defined(macosx):
  # --- openFrameworks.a reconstruct ---
  const
    target = "lib/osx/openFrameworks.a"
    parts = ["lib/osx/openFrameworks.a.partaa", "lib/osx/openFrameworks.a.partab", "lib/osx/openFrameworks.a.partac"]
  if not fileExists(target):
    var presentParts: seq[string] = @[]
    for p in parts:
      if fileExists(p):
        presentParts.add(p)
    if presentParts.len == parts.len:
      echo "Reconstructing ", target, " from parts..."
      let cmd = "cat " & presentParts.join(" ") & " > " & target
      try:
        exec(cmd)
      except OSError:
        quit("Failed to reconstruct " & target)
        
  switch("passL", "lib/osx/openframeworks.a")
  switch("passL", "lib/osx/glfw3.a")
  switch("passL", "lib/osx/tess2.a")
  switch("passL", "lib/osx/glew.a")
  switch("passL", "lib/osx/curl.a")
  switch("passL", "lib/osx/uriparser.a")
  switch("passL", "lib/osx/freeimage.a")
  switch("passL", "lib/osx/freetype.a")
  # switch("passL", "lib/osx/libz.a")
  switch("passL", "lib/osx/libfmod.dylib")
  switch("passL", "-framework OpenGL")
  switch("passL", "-framework CoreFoundation")
  switch("passL", "-framework CoreText")
  switch("passL", "-framework Cocoa")
  switch("passL", "-framework IOKit")
  switch("passL", "-framework CoreVideo")
  switch("passL", "-framework Security")
  switch("passL", "-lobjc")
  switch("passL", "-lz")
  switch("passL", fmt"-rpath {projectRoot}/lib/osx")

elif defined(linux):
  discard