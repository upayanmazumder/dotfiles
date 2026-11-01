---
name: merge-slide-decks-to-pdf
description: "Merge multiple .ppt/.pptx lecture decks into one ordered, deduplicated, bookmarked PDF (LibreOffice convert, pptx slide-range trim, duplicate detection, pypdf assembly)."
---

# Merge slide decks into one PDF

## 1. Inventory & duplicate detection (before converting)
- `file *.ppt *.pptx` — legacy binary `.ppt` (`Composite Document File V2`) vs `Microsoft PowerPoint 2007+`.
- Same stem in `.ppt` and `.pptx` usually = same deck, older format vs re-saved. Confirm by converting both and diffing `pdftotext -layout` output: wrapping-only diffs = duplicates; drop the legacy one.
- Extract text with `pdftotext -layout`, split on `\f`, and compare pages by word-set Jaccard: `len(A&B)/len(A|B)`. `>= 0.7` = same slide, `>= 0.85` = identical block. Two decks on the same syllabus topic often share **zero** pages (different authors) — low Jaccard means keep both, not dedupe.
- A composite deck ("module-4-and-5-material") usually has a hard module boundary: find the slide whose title is `MODULE n` and split there.

## 2. Convert
```bash
# CAUTION: output name = input stem, so same-stem .ppt and .pptx clobber each other.
# Use ONE outdir per source file when stems collide.
soffice --headless --convert-to pdf --outdir /tmp/cnv "<dir>"/*.pptx "<dir>"/*.ppt
```
`pdfinfo <f> | grep -E 'Pages|Page size'`. Mixed 4:3 (720x540) and 16:9 (960x540) is normal; A4 (595x842) means a typed problem set.

LibreOffice export is deterministic in *rendering* but not in bytes (md5 differs per run) — compare renders, never hashes.

## 3. CRITICAL: never slice a LibreOffice PDF with pypdf
LibreOffice puts **one shared `/Resources` on the page-tree root**, inherited by every page. `pypdf.PdfWriter.add_page()` clones that inherited dict, so extracting 1 page or 45 pages of a 144-page deck yields a ~12 MB file containing all 533 images. Verify with:
```python
# walk from reader.trailer, collect StreamObjects with /Subtype == /Image
```
Symptom: two disjoint page ranges each come out ≈ the whole file's size.

**Fix — trim at the source, then convert:**
1. Rewrite a copy of the `.pptx` keeping only the wanted slides.
2. Convert that copy with LibreOffice (its resource pool then holds only those slides' images).

Trimming rules:
- Slide order lives in `<p:sldIdLst>` as `r:id`s; resolve each `rId` to a part via `ppt/_rels/presentation.xml.rels`.
- Keep original slideN.xml part names (gaps are fine; PowerPoint and LO both accept them).
- Classify relationships by their **`Type` attribute**, never by substring-matching `Target`: `slideMasters/slideMaster1.xml` contains `/slide`, and a loose match deletes the slide-master relationship. LibreOffice then silently falls back to a default theme — fonts change, text re-wraps, body text overlaps titles. This looks like "the deck changed" and is easy to misdiagnose.
- Open each kept/removed slide's `.rels` to drop orphaned `notesSlide` parts too.
- Update `[Content_Types].xml` `<Override>` entries for removed parts.
- Preserve the original **per-entry compression** (`zipfile.ZipInfo.compress_type`): media entries are usually stored (method 0); rewriting them as deflated inflates the file.
- Verify: an identity trim (keep all slides) must produce a package with **zero** content differences.

Then pixel-verify the trimmed export against the full-deck export at 60 dpi (`pdftoppm -r 60`, `PIL.ImageChops.difference(...).getbbox() is None`) for several pages, with the right page offset.

## 4. Order sections
Course order beats filename order. For a Data-Link-Layer module: DLL intro/error detection → CRC & checksum → practice problems → flow & error control (stop-and-wait) → Go-Back-N / Selective Repeat → MAC (ALOHA/CSMA) → multiple access networks (Ethernet, Token Ring, 802.11, Bluetooth). For a Network-Layer module: addressing/header/subnetting/CIDR/NAT → then routing (DVR, RIP, link state, OSPF). Put the official lecture spine first, then supplementary/deep-dive decks, then practice problems.

## 5. Assemble with pypdf
Arch/Fedora pip is externally managed: use a throwaway venv.
```bash
python3 -m venv /tmp/pdfvenv && /tmp/pdfvenv/bin/pip -q install pypdf
```
```python
w = PdfWriter()
for label, path, rng in SECTIONS:          # rng = 1-based inclusive range or None
    r = PdfReader(path)
    pages = range(len(r.pages)) if rng is None else range(rng[0]-1, min(rng[1], len(r.pages)))
    start = len(w.pages)
    for i in pages: w.add_page(r.pages[i])
    w.add_outline_item(label, start)       # one bookmark per section
w.add_metadata({"/Title": ...})
```

## 6. Verify (never skip)
- `pdfinfo` page count == sum of kept ranges; file size sane (a subset must not be ≈ the source's size — that is the resource-leak symptom).
- Boundary pages: `pdftotext -f N -l N -layout out.pdf -` shows the expected section title.
- Outline: walk `PdfReader(out).outline`; each `get_destination_page_number(it)+1` hits the right start page.
- Visual: `pdftoppm -f P -l P -r 65 -png out.pdf /tmp/shots/p` on title, figure-heavy and table pages, tiled with PIL — confirms fonts, colors and embedded images survived.
- In bash, quote full literal paths: a glob like `"$DIR/Module - 4/Name"*_merged.pdf` unquoted word-splits on the spaces in the directory name and `pdftoppm` prints its usage banner.
