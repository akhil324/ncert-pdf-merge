# ncert-pdf-merge

A shell script to extract NCERT book ZIP files and merge all chapter PDFs into a single, correctly ordered PDF — without re-encoding or quality loss.

---

## Why this exists

NCERT distributes textbooks as ZIP archives containing individual chapter PDFs. The files are not in alphabetical order inside the ZIP, and naive `sort` breaks the book structure because prelim pages (`ps`), appendices (`a1`, `a2`), supplementary material (`sm`), and answer keys (`an`) have letter-based suffixes that ASCII-sort incorrectly relative to numeric chapter files.

This tool solves the ordering problem with an explicit priority map and uses `pdfunite` (not Ghostscript) so pages are copied as-is — no re-encoding, no quality loss, near-instant merge.

---

## How it works

### Filename pattern

All NCERT PDFs follow this naming convention:

```
[4-letter subject code][1-digit book number][suffix].pdf
```

Examples: `keph101.pdf`, `lech2ps.pdf`, `kemh1a2.pdf`

### Suffix priority map

| Suffix | Meaning | Order |
|--------|---------|-------|
| `ps` | Prelim / title pages | **1st** |
| `01`, `02` … `NN` | Chapters (numeric) | 2nd, sorted numerically |
| `sm` | Supplementary material | After chapters |
| `a1` | Appendix 1 | After `sm` |
| `a2` | Appendix 2 | After `a1` |
| `an` | Answers | **Last** |

Plain `ls | sort` fails because `'0'(ASCII 48) < 'a'(ASCII 97)` — putting `ps` (prelims) after all chapters. This script uses a Python keying function instead.

### Why `pdfunite` and not Ghostscript

| | `pdfunite` | Ghostscript (`-sDEVICE=pdfwrite`) |
|--|--|--|
| Re-encodes content | No | Yes — full re-render |
| Speed on a 15 MB book | ~1–2s | ~30–60s |
| Output fidelity | Byte-identical pages | May degrade fonts/images |
| Use case | Joining pages | Transforming / repairing PDFs |

Ghostscript is the right tool when you need to compress, repair, or flatten a PDF. For pure merging, `pdfunite` is correct.

---

## Requirements

```bash
# Debian / Ubuntu
sudo apt install poppler-utils python3 unzip

# macOS (Homebrew)
brew install poppler python3 unzip
```

---

## Usage

```bash
chmod +x merge_ncert.sh
./merge_ncert.sh XII-Physics-Book1.zip
```

Output: `XII-Physics-Book1.pdf` in the current directory.

### Batch merge all ZIPs in a folder

```bash
for zip in *.zip; do
    ./merge_ncert.sh "$zip"
done
```

---

## The script

```bash
#!/bin/bash
# merge_ncert.sh — merge an NCERT book ZIP into a single PDF
# Usage: ./merge_ncert.sh <book.zip>

set -e

ZIP="$1"

if [[ -z "$ZIP" || ! -f "$ZIP" ]]; then
    echo "Usage: $0 <ncert-book.zip>"
    exit 1
fi

OUTNAME="$(basename "${ZIP%.zip}").pdf"
TMPDIR=$(mktemp -d)

echo "Extracting $ZIP ..."
unzip -q "$ZIP" -d "$TMPDIR"

echo "Sorting files ..."
SORTED=$(ls "$TMPDIR"/*.pdf | python3 -c "
import sys, os, re

def key(path):
    name = os.path.basename(path).replace('.pdf', '')
    # Pattern: 4-letter code + 1-digit book number + suffix
    m = re.match(r'^[a-z]{4}\d(.+)$', name)
    suffix = m.group(1) if m else name

    priority = {'ps': 0, 'sm': 2, 'a1': 3, 'a2': 4, 'an': 5}

    if suffix in priority:
        return (priority[suffix], suffix)
    elif suffix.isdigit():
        return (1, suffix.zfill(4))  # zero-pad for correct numeric order
    else:
        return (99, suffix)          # unknown suffix — append at end

files = sys.stdin.read().splitlines()
files.sort(key=key)
print('\n'.join(files))
")

echo "Merge order:"
echo "$SORTED" | xargs -I{} basename {}

echo "Merging with pdfunite ..."
pdfunite $SORTED "$OUTNAME"

rm -rf "$TMPDIR"
echo "Done → $OUTNAME"
```

---

## Verified book structures

| ZIP | Files | Sorted order |
|-----|-------|-------------|
| `XI-Physics-Book1.zip` | 10 | `ps → 101–107 → a1 → an` |
| `XI-Physics-Book2.zip` | 9 | `ps → 201–207 → an` |
| `XII-Physics-Book1.zip` | 10 | `ps → 101–108 → an` |
| `XII-Physics-Book2.zip` | 8 | `ps → 201–206 → an` |
| `XI-Chemistry-Book1.zip` | 9 | `ps → 101–106 → a1 → an` |
| `XI-Chemistry-Book2.zip` | 5 | `ps → 201–203 → an` |
| `XII-Chemistry-Book1.zip` | 8 | `ps → 101–105 → a1 → an` |
| `XII-Chemistry-Book2.zip` | 7 | `ps → 201–205 → an` |
| `XI-Maths-Book1.zip` | 19 | `ps → 101–114 → sm → a1 → a2 → an` |
| `XII-Maths-Book1.zip` | 10 | `ps → 101–106 → a1 → a2 → an` |
| `XII-Maths-Book2.zip` | 9 | `ps → 201–207 → an` |
| `XII-English-Book1.zip` | 22 | `ps → 101–105 → 111–118 → 121–126 → 131–132` |
| `XII-English-Book2.zip` | 14 | `ps → 101–108 → 111–115` |
| `XII-English-Book3.zip` | 7 | `ps → 101–106` |

> The English books have multi-section chapter numbering (1xx, 2xx, 3xx within one book number). The numeric sort handles this correctly since `111 < 121 < 131` lexicographically and numerically.

---

## Edge cases handled

- **No `an` file** — some English books omit the answer key; the script continues without error
- **No `sm`, `a1`, `a2`** — absent suffixes are simply skipped
- **Unknown suffix** — appended at the end with priority `99`; the script never crashes on unexpected filenames
- **Multi-section English chapters** — three-digit chapter numbers (`101`–`132`) sort correctly via zero-padded numeric comparison

---

## License

MIT
