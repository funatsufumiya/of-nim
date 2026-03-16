#!/usr/bin/env bash
LIB_URL="https://github.com/funatsufumiya/of-nim/releases/download/v0.1/osx_libs.zip"
DYLIB_URL="https://github.com/funatsufumiya/of-nim/releases/download/v0.1/osx_dylibs.zip"
LIB_DEST=lib/osx
DYLIB_DEST=.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch() {
  url=$1; destRel=$2
  out="$TMP/$(basename "$url")"
  if [ "$destRel" = '.' ] || [ -z "$destRel" ]; then
    dest="$ROOT"
  else
    dest="$ROOT/$destRel"
  fi
  if [ "$destRel" != '.' ] && [ -d "$dest" ]; then
    echo "$destRel already exists. Remove it reinstall."
    exit 1
    return
  fi
  echo "Downloading $url"
  curl -L -f -o "$out" "$url"
  mkdir -p "$dest"
  unzip -o "$out" -d "$dest" >/dev/null
}

fetch "$LIB_URL" "$LIB_DEST"
fetch "$DYLIB_URL" "$DYLIB_DEST"
echo "Done."
