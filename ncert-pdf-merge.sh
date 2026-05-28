#!/bin/bash
# Usage: ./merge_ncert.sh XII-Physics-Book1.zip

ZIP="$1"
OUTNAME="$(basename "${ZIP%.zip}").pdf"
TMPDIR=$(mktemp -d)

echo "Extracting $ZIP..."
unzip -q "$ZIP" -d "$TMPDIR"

echo "Sorting files..."
SORTED=$(ls "$TMPDIR"/*.pdf | python3 -c "
import sys, os, re

def key(path):
    name = os.path.basename(path).replace('.pdf', '')
    # Pattern: 4-letter subject code + 1-digit book number + suffix
    m = re.match(r'^[a-z]{4}\d(.+)$', name)
    suffix = m.group(1) if m else name

    priority = {'ps': 0, 'sm': 2, 'a1': 3, 'a2': 4, 'an': 5}
    if suffix in priority:
        return (priority[suffix], suffix)
    elif suffix.isdigit():
        return (1, suffix.zfill(4))   # numeric chapter, zero-padded for correct order
    else:
        return (99, suffix)           # unknown — append at end, don't crash

files = sys.stdin.read().splitlines()
files.sort(key=key)
print('\n'.join(files))
")

echo "Sorted order:"
echo "$SORTED" | xargs -I{} basename {}

echo "Merging with pdfunite..."
pdfunite $SORTED "$OUTNAME"

rm -rf "$TMPDIR"
echo "Done → $OUTNAME"
