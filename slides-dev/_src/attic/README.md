# Attic — retired tools, kept for reference

Nothing here is part of the workflow. Retired 2026-07-22 when the slide
pipeline settled on: *scripts build assets, `key-audit` reports staleness,
Carlisle updates decks by hand*. Everything below either wrote to `.key`
files (which we decided never to automate) or was superseded.

- `key-sync` — replace images/movies inside a `.key` by file name. Verified
  working against Keynote 15, but writes to decks.
- `key-code` — rewrite a colored-code text box inside a `.key` in place.
  Verified working, but writes to decks.
- `key-add` — scripted first insertion of an asset onto a slide. Writes to
  decks.
- `keynote-workflow.md` — the original design narrative for the whole
  system, including full documentation of the three tools above. The live
  procedure moved to `slides/README.md`; the verified AppleScript surface is
  in `../keynote-scripting-notes.md`.
- `highlight-code-fn.R` — the old highlight.js HTML route for colored code
  (browser copy-paste). Superseded by `slide-code` (clipboard RTF).
- `pygmentize-command-example.txt` — an even older pygmentize/HTML route.
  Superseded by `slide-code`.

If a one-off deck write is ever genuinely wanted, the three `key-*` tools
still work (see caveats in `keynote-workflow.md` here) — run them only on
explicit request, on a deck with no unsaved edits, ideally on a copy first.
