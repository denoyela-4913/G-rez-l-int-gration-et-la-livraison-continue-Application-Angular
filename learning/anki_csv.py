#!/usr/bin/env python3
"""Convertit un fichier de flashcards (cartes `Q:` / `R:` séparées par `---`) en CSV pour Anki.

Usage : anki_csv.py flashcards/sujet.md build/sujet.csv
"""
import csv
import html
import re
import sys
from pathlib import Path


def to_html(text: str) -> str:
    """Échappe le HTML, puis transforme `code` en <code>code</code> et les retours ligne en <br>."""
    text = html.escape(text.strip(), quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text.replace("\n", "<br>")


def parse(source: str):
    for block in re.split(r"^---\s*$", source, flags=re.MULTILINE):
        m = re.search(r"^Q:\s*(.*?)^R:\s*(.*)", block, flags=re.MULTILINE | re.DOTALL)
        if m:
            yield to_html(m.group(1)), to_html(m.group(2))


def main(src: str, dst: str) -> None:
    cards = list(parse(Path(src).read_text(encoding="utf-8")))
    if not cards:
        sys.exit(f"aucune carte Q:/R: dans {src}")
    deck = "OlympicTracker::" + Path(src).stem
    with open(dst, "w", encoding="utf-8", newline="") as out:
        out.write("#separator:comma\n#html:true\n#notetype:Basic\n")
        out.write(f"#deck:{deck}\n")
        csv.writer(out, lineterminator="\n").writerows(cards)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
