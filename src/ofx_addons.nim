import std/os
import std/private/ospaths2

const addonDepsPath = joinPath(parentDir(system.currentSourcePath), "..", "generated", "addon_dependencies.nim")

when fileExists(addonDepsPath):
  include ../generated/addon_dependencies
else:
  discard