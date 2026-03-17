import std/os
import std/strutils
import std/json
import std/strformat

proc splitWords(s: string): seq[string] =
  result = @[]
  for part in s.splitWhitespace():
    if part.len > 0:
      result.add(part)

type SectionMap = JsonNode

proc parseAddonConfigMk(path: string): SectionMap =
  var sections = newJObject()
  if not fileExists(path):
    return sections
  let lines = readFile(path).splitLines()
  var curSection = "common"
  for raw in lines:
    var line = raw.strip()
    # echo "line: ", line
    if line.len == 0: continue
    if line.startsWith("#"): continue
    if line.endsWith(":"):
      curSection = line[0 ..< line.len-1].strip()
      if not sections.hasKey(curSection):
        sections[curSection] = newJObject()
      continue
    # assignments: VAR = value  or VAR += value
    var name = ""
    var value = ""
    var opAdd = false
    if line.contains("+="):
      let parts = line.split("+=")
      if parts.len == 0: continue
      name = parts[0].strip()
      # echo "name = ", $name
      if parts.len > 1:
        value = parts[1 .. parts.len-1].join("+=").strip()
        # echo "value = ", $value
      opAdd = true
    elif line.contains("="):
      let parts = line.split("=")
      if parts.len == 0: continue
      name = parts[0].strip()
      # echo "name = ", $name
      if parts.len > 1:
        value = parts[1 .. parts.len-1].join("=").strip()
        # echo "value = ", $value
      opAdd = false
    else:
      continue
    if not sections.hasKey(curSection):
      sections[curSection] = newJObject()
    var sect = sections[curSection]
    if not sect.hasKey(name) or not opAdd:
      sect[name] = newJArray()
    for w in splitWords(value):
      # append w to array
      sect[name].add(%* w)
  return sections

proc pickVars(sections: SectionMap, platformCandidates: seq[string], varname: string): seq[string] =
  var outs: seq[string] = @[]
  if sections.kind == JNull: return outs
  if sections.hasKey("common"):
    let common = sections["common"]
    if common.kind != JNull and common.hasKey(varname):
      let arr = common[varname]
      if arr.kind == JArray:
        for i in 0 ..< arr.len: outs.add(arr[i].getStr())
  for p in platformCandidates:
    if sections.hasKey(p):
      let pm = sections[p]
      if pm.kind != JNull and pm.hasKey(varname):
        let arr = pm[varname]
        if arr.kind == JArray:
          for i in 0 ..< arr.len: outs.add(arr[i].getStr())
  return outs

proc addInclude(path: string) =
  if path.len == 0: return
  switch("passC", fmt"-I{path}")

proc addLink(path: string) =
  if path.len == 0: return
  switch("passL", path)

proc processAddonDir(addonDir: string, projectRoot: string, platformCandidates: seq[string]) =
  if not dirExists(addonDir): return
  # parse addon_config.mk if present
  let cfgPath = joinPath(addonDir, "addon_config.mk")
  let sections = parseAddonConfigMk(cfgPath)

  # handle ADDON_INCLUDES
  let includes = pickVars(sections, platformCandidates, "ADDON_INCLUDES")
  for inp in includes:
    var p = inp
    if p.endsWith("%"):
      p = p[0 ..< p.len-1]
    if p.len == 0: continue
    let full = joinPath(addonDir, p)
    if dirExists(full):
      addInclude(full)

  # default include directories
  for candidate in @["include", "src"]:
    let d = joinPath(addonDir, candidate)
    if dirExists(d): addInclude(d)

  # handle ADDON_CFLAGS and ADDON_DEFINES
  let cflags = pickVars(sections, platformCandidates, "ADDON_CFLAGS")
  for f in cflags: switch("passC", f)
  let defines = pickVars(sections, platformCandidates, "ADDON_DEFINES")
  for d in defines: switch("passC", d)

  # handle ADDON_LDFLAGS
  let ldflags = pickVars(sections, platformCandidates, "ADDON_LDFLAGS")
  for f in ldflags: switch("passL", f)

  # handle ADDON_LIBS explicit lists
  let libs = pickVars(sections, platformCandidates, "ADDON_LIBS")
  for l in libs:
    var libPath = l
    if libPath.endsWith("%"):
      libPath = libPath[0 ..< libPath.len-1]
    if libPath.len == 0: continue
    let full = joinPath(addonDir, libPath)
    if fileExists(full) or fileExists(libPath):
      addLink(full)

  # scan libs directory for library files
  let libsDir = joinPath(addonDir, "libs")
  if dirExists(libsDir):
    for kind, p in walkDir(libsDir):
      if kind == pcFile:
        let lower = p.toLowerAscii()
        if lower.endsWith(".lib") or lower.endsWith(".a") or lower.endsWith(".dll") or lower.endsWith(".so") or lower.endsWith(".dylib"):
          addLink(p)

proc processAddons*(addonsMakePath: string, addonsDir: string, projectRoot: string) =
  if not fileExists(addonsMakePath):
    return
  if not dirExists(addonsDir):
    return
  let lines = readFile(addonsMakePath).splitLines()
  let sep = when defined(windows): "\\" else: "/"
  let altSep = if sep == "\\": "/" else: "\\"
  var names: seq[string] = @[]
  for raw in lines:
    var line = raw.strip()
    if line.len == 0: continue
    if line.startsWith("#"): continue
    # take first token
    let token = line.splitWhitespace()[0]
    # strip optional leading "addons/" (use platform-specific separator)
    var name = token
    if name.startsWith("addons" & sep) or name.startsWith("addons" & altSep):
      var parts = name.split(sep)
      if parts.len == 1: # maybe the other separator is used
        parts = name.split(altSep)
      if parts.len > 0: name = parts[^1]
    # fallback: take last path component using platform separators
    if name.contains(sep) or name.contains(altSep):
      var parts2 = if name.contains(sep): name.split(sep) else: name.split(altSep)
      if parts2.len > 0: name = parts2[^1]
    if name.len == 0: continue
    names.add(name)

  # determine platform candidates for addon_config sections
  var platformCandidates = @["common"]
  when defined(windows):
    platformCandidates = @["vs", "msys2", "windows"]
  elif defined(macosx):
    platformCandidates = @["osx", "mac"]
  elif defined(linux):
    platformCandidates = @["linux", "linux64"]

  for n in names:
    let addonPath = joinPath(addonsDir, n)
    if dirExists(addonPath):
      processAddonDir(addonPath, projectRoot, platformCandidates)
