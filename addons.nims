import std/os
import std/strutils
import std/json
import std/strformat

when defined(addonsDebug):
  const debugAddons = true
else:
  const debugAddons = false

proc logAdd(s: string) =
  if debugAddons:
    echo s

proc splitWords(s: string): seq[string] =
  result = @[]
  for part in s.splitWhitespace():
    if part.len > 0:
      result.add(part)

type SectionMap = JsonNode

proc walkDirRec(root: string): seq[string] =
  result = @[]
  if not dirExists(root): return result
  for kind, p in walkDir(root):
    if kind == pcDir:
      result.add(p)
      let subs = walkDirRec(p)
      for sp in subs: result.add(sp)

# collected C/C++ sources to generate a Nim file with {.compile: ...} pragmas
var discoveredCppSources: seq[string] = @[]

proc findSourceFiles(root: string): seq[string] =
  result = @[]
  if not dirExists(root): return result
  var dirs = @[root]
  for d in walkDirRec(root):
    dirs.add(d)
  for d in dirs:
    for kind, p in walkDir(d):
      if kind == pcFile:
        let lower = p.toLowerAscii()
        if lower.endsWith(".cpp") or lower.endsWith(".c") or lower.endsWith(".cc") or lower.endsWith(".cxx") or lower.endsWith(".mm") or lower.endsWith(".m"):
          result.add(p)

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
  logAdd(fmt"passC: -I{path}")
  switch("passC", fmt"-I{path}")

proc addLink(path: string) =
  if path.len == 0: return
  logAdd(fmt"passL: {path}")
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
    # logAdd(fmt"explicit include entry: {inp} -> full: {full}")
    if dirExists(full):
      addInclude(full)

  # default include directories
  # handle default include directories; for `src` add recursively (respecting simple excludes)
  let includesExcl = pickVars(sections, platformCandidates, "ADDON_INCLUDES_EXCLUDE")
  for ex in includesExcl:
    # logAdd(fmt"includesExcl: {ex}")
    discard

  proc isExcluded(p: string, excludes: seq[string]): bool =
    if excludes.len == 0: return false
    var np = p.replace('\\', '/').toLowerAscii()
    for ex in excludes:
      var base = ex.replace('\\', '/').toLowerAscii()
      if base.endsWith("%"):
        base = base[0 ..< base.len-1]
      if base.len == 0: continue
      if np.contains(base): return true
    return false

  for candidate in @["include", "src"]:
    let d = joinPath(addonDir, candidate)
    if not dirExists(d): continue
    if candidate == "src":
      # add top-level src folder
      if not isExcluded(d, includesExcl): addInclude(d)
      # compute subdirectories once, log count, then iterate
      let subdirs = walkDirRec(d)
      # logAdd(fmt"walkDirRec({d}) -> {subdirs.len} dirs")
      for p in subdirs:
        if dirExists(p):
          # logAdd(fmt"consider dir: {p}, excluded={isExcluded(p, includesExcl)}")
          if not isExcluded(p, includesExcl):
            addInclude(p)
      # discover cpp/c sources under src and pass to C compiler
      let srcFiles = findSourceFiles(d)
      # logAdd(fmt"found {srcFiles.len} source files in {d}")
      for sf in srcFiles:
        logAdd(fmt"add source: {sf}")
        # switch("passC", sf)
        var rel = sf
        if rel.startsWith(projectRoot):
          rel = rel.substr(projectRoot.len + 1)
        rel = rel.replace('\\', '/')
        if rel notin discoveredCppSources:
          discoveredCppSources.add(rel)
    else:
      if not isExcluded(d, includesExcl): addInclude(d)

  # handle ADDON_CFLAGS and ADDON_DEFINES
  let cflags = pickVars(sections, platformCandidates, "ADDON_CFLAGS")
  for f in cflags:
    logAdd(fmt"passC flag: {f}")
    switch("passC", f)
  let defines = pickVars(sections, platformCandidates, "ADDON_DEFINES")
  for d in defines:
    var pd = d
    if pd.len > 0 and not (pd[0] == '-' or pd[0] == '/'): 
      pd = fmt"-D{pd}"
    logAdd(fmt"passC define: {pd}")
    switch("passC", pd)

  # handle ADDON_LDFLAGS
  let ldflags = pickVars(sections, platformCandidates, "ADDON_LDFLAGS")
  for f in ldflags:
    logAdd(fmt"passL ldflag: {f}")
    switch("passL", f)

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
    # also add include/src folders from libs/*
    for kind2, p2 in walkDir(libsDir):
      if kind2 == pcDir:
        let incd = joinPath(p2, "include")
        if dirExists(incd):
          # logAdd(fmt"found libs include: {incd}")
          addInclude(incd)
        let srcd = joinPath(p2, "src")
        if dirExists(srcd):
          # logAdd(fmt"found libs src: {srcd}")
          addInclude(srcd)
          let subdirs = walkDirRec(srcd)
          # logAdd(fmt"walkDirRec({srcd}) -> {subdirs.len} dirs")
          for sp in subdirs:
            if dirExists(sp):
              # logAdd(fmt"consider libs subdir: {sp}")
              addInclude(sp)
          # also find source files in libs/*/src and pass to compiler
          let libSrcFiles = findSourceFiles(srcd)
          # logAdd(fmt"found {libSrcFiles.len} lib source files in {srcd}")
          for lsf in libSrcFiles:
            logAdd(fmt"add lib source: {lsf}")
            # switch("passC", lsf)
            var lrel = lsf
            if lrel.startsWith(projectRoot):
              lrel = lrel.substr(projectRoot.len + 1)
            lrel = lrel.replace('\\', '/')
            if lrel notin discoveredCppSources:
              discoveredCppSources.add(lrel)

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

  # emit generated Nim file with {.compile: ...} pragmas for discovered C/C++ sources
  if discoveredCppSources.len > 0:
    let genDir = joinPath(projectRoot, "generated")
    if not dirExists(genDir):
      let nl = "\n"
      quit(fmt"[Error] required directory not found: {genDir}{nl}Please create it and re-run.{nl}")
    let outPath = joinPath(genDir, "addon_dependencies.nim")
    var contents = "# This file is generated by addons.nims - contains compile pragmas\n"
    for s in discoveredCppSources:
      let dq = "\""
      let cps = "{.compile:"
      let rp = ".}\n"
      contents.add(fmt"{cps} {dq}{s}{dq}{rp}")
    writeFile(outPath, contents)
    logAdd(fmt"wrote generated file: {outPath}")
