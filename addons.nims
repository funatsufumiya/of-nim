import std/os
import std/strutils
import std/json
import std/strformat
include "config_parser.nims"

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
  for kind, p in walkDir(root):
    if kind == pcFile:
      let lower = p.toLowerAscii()
      if lower.endsWith(".cpp") or lower.endsWith(".c") or lower.endsWith(".cc") or lower.endsWith(".cxx") or lower.endsWith(".mm") or lower.endsWith(".m"):
        result.add(p)
    elif kind == pcDir:
      let subs = findSourceFiles(p)
      for s in subs: result.add(s)

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
      if parts.len > 1:
        value = parts[1 .. parts.len-1].join("+=").strip()
      opAdd = true
    elif line.contains("="):
      let parts = line.split("=")
      if parts.len == 0: continue
      name = parts[0].strip()
      if parts.len > 1:
        value = parts[1 .. parts.len-1].join("=").strip()
      opAdd = false
    else:
      continue
    if not sections.hasKey(curSection):
      sections[curSection] = newJObject()
    var sect = sections[curSection]
    # store each variable as an object { vals: [...], op: "set"|"add" }
    if not sect.hasKey(name) or not opAdd:
      sect[name] = newJObject()
      sect[name]["vals"] = newJArray()
      sect[name]["op"] = %* (if opAdd: "add" else: "set")
    else:
      # update op to reflect last operation (+= or =)
      sect[name]["op"] = %* (if opAdd: "add" else: "set")
    for w in splitWords(value):
      sect[name]["vals"].add(%* w)
  return sections

proc pickVars(sections: SectionMap, platformCandidates: seq[string], varname: string): seq[string] =
  var result: seq[string] = @[]
  if sections.kind == JNull: return result

  # helper to extract values from node (support backward compatibility)
  proc nodeVals(n: JsonNode): seq[string] =
    var r: seq[string] = @[]
    if n.kind == JArray:
      for i in 0..<n.len: r.add(n[i].getStr())
    elif n.kind == JObject and n.hasKey("vals"):
      let arr = n["vals"]
      for i in 0..<arr.len: r.add(arr[i].getStr())
    return r

  # start with common if present
  if sections.hasKey("common") and sections["common"].hasKey(varname):
    result = nodeVals(sections["common"][varname])

  # respect platformCandidates provided by caller (filter out msys2)
  var filtered = newSeq[string]()
  for p in platformCandidates:
    if p.toLowerAscii() != "msys2":
      filtered.add(p)

  # process platform sections in order; treat op=="set" as override, "add" as append
  for p in filtered:
    if sections.hasKey(p) and sections[p].hasKey(varname):
      let node = sections[p][varname]
      var op = "set"
      if node.kind == JObject and node.hasKey("op"):
        op = node["op"].getStr()
      let vals = nodeVals(node)
      if op == "set":
        result = vals
      else:
        result.add vals
  return result

proc isPlatformMismatch(path: string): bool =
  let lp = path.replace('\\', '/').toLowerAscii()
  when defined(windows):
    # on Windows, skip posix folders
    if lp.contains("/posix"):
      return true
    return false
  else:
    # on non-Windows, skip win32 folders
    if lp.contains("/win32"):
      return true
    return false

proc addInclude(path: string) =
  if path.len == 0: return
  if isPlatformMismatch(path):
    logAdd(fmt"skip include (platform mismatch): {path}")
    return
  logAdd(fmt"passC: -I{path}")
  switch("passC", fmt"-I{path}")

proc addLink(path: string) =
  if path.len == 0: return
  logAdd(fmt"passL: {path}")
  switch("passL", path)

proc processAddonDir(addonDir: string, projectRoot: string, platformCandidates: seq[string]) =
  if not dirExists(addonDir): return
  
  # parse a simple config.txt if provided by addon (restricted DSL)
  let addonTxt = joinPath(addonDir, "config.txt")
  if fileExists(addonTxt):
    let addonRoot = addonDir
    let (_, addonName) = splitPath(addonDir)
    when defined(addonsDebug):
      echo(fmt"[addon {addonName}] included: {addonTxt}")
    parseConfigTxt(addonTxt, addonRoot, projectRoot, addonName)
  
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
  let sourcesExcl = pickVars(sections, platformCandidates, "ADDON_SOURCES_EXCLUDE")
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
      # add top-level src folder (respect both includes and sources exclude)
      if not isExcluded(d, includesExcl) and not isExcluded(d, sourcesExcl):
        addInclude(d)
      # compute subdirectories once, log count, then iterate
      let subdirs = walkDirRec(d)
      for p in subdirs:
        if dirExists(p):
          if not isExcluded(p, includesExcl) and not isExcluded(p, sourcesExcl):
            addInclude(p)
      # discover cpp/c sources under src and pass to C compiler
      let srcFiles = findSourceFiles(d)
      # logAdd(fmt"found {srcFiles.len} source files in {d}")
      for sf in srcFiles:
        # respect ADDON_SOURCES_EXCLUDE
        if isExcluded(sf, sourcesExcl): continue
        # skip platform-mismatched source folders (posix/win32)
        if isPlatformMismatch(sf):
          logAdd(fmt"skip source (platform mismatch): {sf}")
          continue
        logAdd(fmt"add source: {sf}")
        # switch("passC", sf)
        # normalize paths (use forward slashes and lowercase for comparison)
        var nf = sf.replace('\\', '/')
        var proj = projectRoot.replace('\\', '/')
        var nfn = nf.toLowerAscii()
        var projn = proj.toLowerAscii()
        var rel = nf
        if nfn.startsWith(projn):
          rel = nf.substr(proj.len)
          if rel.startsWith("/"):
            rel = rel.substr(1)
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
    # also add include/src folders from libs/* (respect ADDON_INCLUDES_EXCLUDE)
    for kind2, p2 in walkDir(libsDir):
      if kind2 == pcDir:
        # add the lib directory itself (respect ADDON_INCLUDES_EXCLUDE / ADDON_SOURCES_EXCLUDE)
        if dirExists(p2):
          if not isExcluded(p2, includesExcl) and not isExcluded(p2, sourcesExcl):
            addInclude(p2)
        let incd = joinPath(p2, "include")
        if dirExists(incd):
          if not isExcluded(incd, includesExcl) and not isExcluded(incd, sourcesExcl):
            addInclude(incd)
        let srcd = joinPath(p2, "src")
        if dirExists(srcd):
          if not isExcluded(srcd, includesExcl) and not isExcluded(srcd, sourcesExcl):
            addInclude(srcd)
            let subdirs = walkDirRec(srcd)
            for sp in subdirs:
              if dirExists(sp):
                if not isExcluded(sp, includesExcl) and not isExcluded(sp, sourcesExcl):
                  addInclude(sp)
          # also find source files in libs/*/src and pass to compiler
          let libSrcFiles = findSourceFiles(srcd)
          # debug: log libs src dir and number of found source files
          logAdd(fmt"found {libSrcFiles.len} lib source files in {srcd}")
          logAdd(fmt"libs src dir: {srcd}")
          for lsf in libSrcFiles:
            # respect ADDON_SOURCES_EXCLUDE for libs/*/src files
            if isExcluded(lsf, sourcesExcl): continue
            # skip platform-mismatched lib source folders
            if isPlatformMismatch(lsf):
              logAdd(fmt"skip lib source (platform mismatch): {lsf}")
              continue
            logAdd(fmt"add lib source: {lsf}")
            # switch("passC", lsf)
            var nf = lsf.replace('\\', '/')
            var proj = projectRoot.replace('\\', '/')
            var nfn = nf.toLowerAscii()
            var projn = proj.toLowerAscii()
            var lrel = nf
            if nfn.startsWith(projn):
              lrel = nf.substr(proj.len)
              if lrel.startsWith("/"):
                lrel = lrel.substr(1)
            if lrel notin discoveredCppSources:
              discoveredCppSources.add(lrel)
          # also scan the whole lib directory (not only libs/*/src) for other source files
          let libAllFiles = findSourceFiles(p2)
          logAdd(fmt"found {libAllFiles.len} lib source files in {p2}")
          for af in libAllFiles:
            if isExcluded(af, sourcesExcl): continue
            if isPlatformMismatch(af):
              logAdd(fmt"skip lib source (platform mismatch): {af}")
              continue
            logAdd(fmt"add lib source: {af}")
            var anf = af.replace('\\', '/')
            var proj = projectRoot.replace('\\', '/')
            var nfn = anf.toLowerAscii()
            var projn = proj.toLowerAscii()
            var arel = anf
            if nfn.startsWith(projn):
              arel = anf.substr(proj.len)
              if arel.startsWith("/"):
                arel = arel.substr(1)
            if arel notin discoveredCppSources:
              discoveredCppSources.add(arel)

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
      if parts.len > 0: name = parts[parts.len-1]
    # fallback: take last path component using platform separators
    if name.contains(sep) or name.contains(altSep):
      var parts2 = if name.contains(sep): name.split(sep) else: name.split(altSep)
      if parts2.len > 0: name = parts2[parts2.len-1]
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
    else:
      let nl = "\n"
      quit(fmt"[Error] referenced addon '{n}' not found under {addonsDir}{nl}")

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

## Choose a .nim.addons file for the given Nim target (if any).
proc selectAddonsFile*(projectRoot: string, mainNimRelPath: string): string =
  if mainNimRelPath.len == 0: return ""
  let candidate = mainNimRelPath & ".addons"
  if fileExists(candidate): return candidate
  if not isAbsolute(mainNimRelPath):
    let relativeCandidate = joinPath(projectRoot, candidate)
    if fileExists(relativeCandidate): return relativeCandidate
  # if caller provided a path (or basename), extract basename safely
  let (_, base) = splitPath(mainNimRelPath)
  if base.endsWith(".nim"):
    let baseCandidate = joinPath(projectRoot, base & ".addons")
    if fileExists(baseCandidate): return baseCandidate
  return ""
