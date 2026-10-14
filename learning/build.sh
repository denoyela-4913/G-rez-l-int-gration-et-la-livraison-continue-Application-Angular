#!/usr/bin/env bash
# Génère les PDF des fiches (learning/build/fiches/) et les CSV Anki des flashcards
# (learning/build/flashcards/).
#   - fiches .md   -> pandoc (HTML + style.css), puis Chrome / Edge headless
#   - fiches .html -> Chrome / Edge headless (le HTML est la source de référence)
#   - flashcards/*.md -> CSV pour l'import Anki (anki_csv.py, python3)
#
# Usage : learning/build.sh [fiche...]   (sans argument : toutes les fiches)
set -euo pipefail
shopt -s nullglob # un motif sans fichier (ex. aucune fiche .html) donne une liste vide

cd "$(dirname "$0")"
OUT=build
mkdir -p "$OUT/fiches" "$OUT/flashcards"

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=(fiches/*.md fiches/*.html flashcards/*.md)
fi

find_browser() {
  local c
  for c in google-chrome chromium chromium-browser \
    "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

# html_to_pdf <source.html> <cible.pdf>
html_to_pdf() {
  local browser src dst profile
  browser=$(find_browser) || { echo "Chrome/Chromium/Edge introuvable" >&2; exit 1; }
  profile=$(mktemp -d -p "$OUT" .chrome-XXXXXX)
  if [[ "$browser" == *.exe ]]; then
    src="file:///$(wslpath -m "$(realpath "$1")")"
    dst=$(wslpath -w "$(realpath -m "$2")")
    profile=$(wslpath -w "$(realpath "$profile")")
  else
    src="file://$(realpath "$1")"
    dst=$(realpath -m "$2")
    profile=$(realpath "$profile")
  fi
  rm -f "$2"
  "$browser" --headless --disable-gpu --no-pdf-header-footer \
    --user-data-dir="$profile" --print-to-pdf="$dst" "$src" >/dev/null 2>&1 || true
  rm -rf "$OUT"/.chrome-*
  [ -s "$2" ] || { echo "échec de la génération de $2" >&2; exit 1; }
}

# md_to_pdf <source.md> <cible.pdf>
md_to_pdf() {
  command -v pandoc >/dev/null || { echo "pandoc introuvable" >&2; exit 1; }
  local html
  html=$(mktemp -p "$OUT" .tmp-XXXXXX.html)
  pandoc "$1" -f markdown -t html5 --standalone --embed-resources \
    --css style.css -V lang=fr --metadata "pagetitle=$(basename "${1%.*}")" -o "$html"
  html_to_pdf "$html" "$2"
  rm -f "$html"
}

for f in "${files[@]}"; do
  f=${f#learning/}
  name=$(basename "${f%.*}")
  case "$f" in
    flashcards/*.md)
      out="$OUT/flashcards/$name.csv"
      python3 anki_csv.py "$f" "$out" ;;
    fiches/*.md)
      out="$OUT/fiches/$name.pdf"
      md_to_pdf "$f" "$out" ;;
    fiches/*.html)
      out="$OUT/fiches/$name.pdf"
      html_to_pdf "$f" "$out" ;;
    *) echo "format ignoré : $f" >&2; continue ;;
  esac
  echo "généré : learning/$out"
done
