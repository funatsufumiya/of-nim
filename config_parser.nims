import std/os
import std/strutils
import std/strformat
import std/sequtils

# Minimal parser for a restricted "config.txt" DSL.
# Supports:
# - comments starting with `#`
# - `if defined(NAME):`, `when defined(NAME):`, `elif defined(NAME):`, `else:` blocks
# - `echo "..."` and `echo fmt"..."` (fmt ignored)
# - `switch("a", "b")` (returns discovered switch entries as a single output line)
# Placeholders `{addonRoot}`, `{projectRoot}`, `{mainNimRelPath}`, `{mainNimSourcePath}`
# are expanded automatically.

proc stripQuotes(s: string): string =
  if s.len >= 2 and ((s[0] == '"' and s[^1] == '"') or (s[0] == '\'' and s[^1] == '\'')):
    return s[1..^2]
  return s

proc splitArgsList(s: string): seq[string] =
  # naive splitter for comma-separated string literals inside parentheses
  var res: seq[string] = @[]
  var cur = ""
  var inStr = false
  var quoteChar: char = ' '
  for ch in s:
    if inStr:
      if ch == quoteChar:
        inStr = false
        cur.add(ch)
      else:
        cur.add(ch)
    else:
      if ch == '"' or ch == '\'':
        inStr = true
        quoteChar = ch
        cur.add(ch)
      elif ch == ',':
        let t = cur.strip()
        if t.len > 0:
          res.add(stripQuotes(t))
        cur = ""
      else:
        cur.add(ch)
  let t = cur.strip()
  if t.len > 0:
    res.add(stripQuotes(t))
  return res

proc defaultPlatformDefines(): seq[string] =
  var d: seq[string] = @[]
  when defined(windows): d.add "windows"
  when defined(macosx): d.add "macosx"
  when defined(linux): d.add "linux"
  when defined(amd64): d.add "amd64"
  when defined(i386): d.add "i386"
  when defined(arm): d.add "arm"
  return d

proc expandPlaceholders(s: string, addonRoot, projectRoot: string): string =
  result = s.replace("{addonRoot}", addonRoot)
  result = result.replace("{projectRoot}", projectRoot)

proc normalizeArg(s: string): string =
  var t = s.strip()
  if t.len >= 4 and t.startsWith("fmt\""):
    t = t.replace("fmt\"", "\"")
  elif t.len >= 4 and t.startsWith("fmt'"):
    t = t.replace("fmt'", "'")
  return stripQuotes(t)

proc parseConfigTxt*(path: string, addonRoot: string, projectRoot: string, addonName: string, extraDefines: seq[string] = @[]) =
  if not fileExists(path): return
  let lines = readFile(path).splitLines()

  var defines = newSeq[string]()
  for d in defaultPlatformDefines():
    defines.add(d)
  for d in extraDefines:
    defines.add(d)

  # stack of active states according to indentation levels
  var activeStack = @[true]
  var indentStack = @[0]

  proc curActive(): bool =
    return activeStack[^1]

  for raw in lines:
    # compute leading indent (count spaces/tabs) without trimming trailing whitespace
    var indent = 0
    while indent < raw.len and (raw[indent] == ' ' or raw[indent] == '\t'):
      indent.inc()
    var ltrim = ""
    if indent < raw.len:
      ltrim = raw[indent..^1]
    if ltrim.len == 0: continue
    if ltrim.startsWith("#"): continue
    if ltrim == "discard": continue
    var line = ltrim

    # if current line is not a control header and is at the same indent
    # as the last pushed conditional, pop that conditional (it has ended)
    if not (line.startsWith("if defined(") or line.startsWith("when defined(") or line.startsWith("elif defined(") or line.startsWith("else:")):
      if indent == indentStack[^1] and indentStack.len > 1:
        discard indentStack.pop()
        discard activeStack.pop()

    # adjust stacks according to indent (pop deeper blocks)
    while indent < indentStack[^1]:
      discard indentStack.pop()
      discard activeStack.pop()

    # handle control lines
    if line.startsWith("if defined(") or line.startsWith("when defined("):
      # if defined(NAME):
      var name = line
      name = name.replace("if defined(", "").replace("when defined(", "")
      if name.contains(")"):
        name = name.split(")")[0]
      name = name.strip()
      var cond = name in defines
      # pop any deeper or same-level blocks before adding this block
      while indent < indentStack[^1]:
        discard indentStack.pop()
        discard activeStack.pop()
      if indent == indentStack[^1] and indentStack.len > 1:
        discard indentStack.pop()
        discard activeStack.pop()
      indentStack.add indent
      activeStack.add curActive() and cond
      continue
    elif line.startsWith("elif defined("):
      # elif replaces last condition at same level
      var name = line.replace("elif defined(", "")
      if name.contains(")"):
        name = name.split(")")[0]
      name = name.strip()
      var cond = name in defines
      # pop previous condition for this level (if present)
      if indentStack.len > 1:
        if indent == indentStack[^1]:
          discard indentStack.pop()
          discard activeStack.pop()
        else:
          # different indent; pop deeper blocks
          while indent < indentStack[^1]:
            discard indentStack.pop()
            discard activeStack.pop()
      indentStack.add indent
      activeStack.add curActive() and cond
      continue
    elif line.startsWith("else:"):
      # pop deeper or same-level blocks before adding else
      while indent < indentStack[^1]:
        discard indentStack.pop()
        discard activeStack.pop()
      if indent == indentStack[^1] and indentStack.len > 1:
        discard indentStack.pop()
        discard activeStack.pop()
      indentStack.add indent
      activeStack.add curActive() and not activeStack[^1]
      continue

    # switch parsing: switch("a", "b")
    if line.startsWith("switch("):
      let inside = line[7 ..< line.len-1]
      let entries = splitArgsList(inside)
      if curActive() and entries.len > 0:
        let key = entries[0]
        if entries.len > 1:
          for i in 1 ..< entries.len:
            var val = entries[i]
            val = normalizeArg(val)
            val = expandPlaceholders(val, addonRoot, projectRoot)
            # actually invoke nimscript `switch` to apply the setting
            switch(key, val)
            when defined(addonsDebug):
              echo(fmt"[addon {addonName} config.txt] switch: {key} {val}")
        else:
          # no values provided; log key-only switch
          when defined(addonsDebug):
            echo(fmt"[addon {addonName} config.txt] switch: {key}")
      continue

    # echo handling
    if line.startsWith("echo ") and curActive():
      var arg = line[5..^1].strip()
      # support fmt"..." and plain "..."
      if arg.startsWith("fmt\""):
        arg = arg[4..^1]
      arg = stripQuotes(arg)
      arg = expandPlaceholders(arg, addonRoot, projectRoot)
      when defined(addonsDebug):
        echo(fmt"[addon {addonName} config.txt echo] {arg}")
      continue

    # ignore unknown lines
  return
