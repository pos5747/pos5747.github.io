# Keynote scripting: the verified surface (engineering appendix)

Findings from a deep dive (2026-07-22) into programmatic interaction with
`.key` decks, tested live against Keynote 15. Trimmed 2026-07-22 to what the
surviving audit-only workflow depends on; the write-tool documentation
(`key-sync`, `key-code`, `key-add`) moved to `attic/` with the tools.

**Policy: nothing writes to a `.key`.** Claude may read decks freely —
extract text/notes via AppleScript, unzip the package, audit — always on a
scratchpad copy when unzipping. Deck updates are Carlisle's, by hand.

## Load-bearing findings

- **Keynote has no linked-media feature** (confirmed through Keynote 15 and
  the June 2026 iWork updates; only charts pasted from Numbers auto-update).
  This is why the whole system is *audit and re-drag* rather than
  live-linked assets.
- **A `.key` is a zip** with media in `Data/` and structure in protobuf
  (IWA). Embedded media keep their **original file names** (e.g.
  `Data/fig-consistency-123.gif`), which is what makes file names usable as
  stable deck↔source links — and lets `key-audit` compare embedded bytes
  against current assets without opening Keynote at all.
- **Pasted media lose their names**: pasting names media `pasted-image` /
  `pasted-movie`. Always drag files in, or the audit can't see them.
- **Keynote appends `-N` to every insert**, not only to duplicates (verified
  2026-07-22: a first-ever insert of `fig-beta.png` landed as
  `Data/fig-beta-9078.png`). Hence the naming rule that asset names never
  end in `-<number>` — and why name matching must strip the suffix.
- **An image's `file name` is read-*write*, and setting it swaps the bytes.**
  `set file name of image 1 of slide 1 of doc to POSIX file "…"` performs a
  real content replacement, not a rename (verified 2026-07-22 by hash: the
  new media in `Data/` matched the source file exactly and the old media was
  gone; Keynote also regenerated its `-small-` preview, so no stale preview).
  Geometry and stacking are preserved exactly: position, width, and height
  are unchanged, and the image keeps its z-order — it does **not** come to
  the front. Note the image is scaled into the *existing* frame, so an asset
  whose aspect ratio changed will distort silently rather than resize.
  This does not change the policy below; it only means the constraint is a
  choice, not a technical limit.

## The read surface (all verified working)

| Capability | Notes |
|---|---|
| Extract slide text (`object text of text item j of slide i`) | how `key-audit` checks code snippets |
| Read/write presenter notes | read side used to extract LaTeX from old decks |
| Read an image's `file name`, `position`, `width`, `rotation`, `opacity`, `locked` | `file name` is `rw` in the dictionary; writing it replaces the image (see above) |
| Export all slides to PNG (`export … as slide images`) | visual verification; skipped slides are excluded, so export numbering ≠ slide numbering |

Caveat to remember: text items inside **groups** may not be enumerated by
`text items of slide` — don't group code boxes, or the audit may miss them.

## Which Keynote to target (corrected 2026-08-24)

**Target `com.apple.Keynote`.** That is Apple's current Keynote.

⚠️ **This entry previously said the opposite, and the error was costly.** It
claimed a Mac App Store app named "Keynote Creator Studio.app" was an
impostor spoofing `com.apple.Keynote`, and told the reader to target
`com.apple.iWork.Keynote` instead. That is wrong. Acting on it in August 2026
led to a legitimate Apple app being called malware, two decks being closed
without saving, and the *old* Keynote being deleted.

What actually happened: in February 2026 Apple folded iWork into **Apple
Creator Studio** and unified the Mac bundle identifiers onto the iOS ones,
dropping the `iWork` segment. So:

| | Bundle id | Installed as | Status |
|---|---|---|---|
| Keynote 15+ | `com.apple.Keynote` | `/Applications/Keynote Creator Studio.app` | **current** |
| Keynote 14.x | `com.apple.iWork.Keynote` | `/Applications/Keynote.app` | legacy, pulled from the App Store |

Both are Apple. They differ in code-signing Team ID (`JCRTNEU7GK` for
Creator Studio, `74J34U3R6X` for the legacy app), and **that difference is
not evidence of anything** — it is what misled the 2026-07-22 note. The
reliable checks are the App Store receipt at
`Contents/_MASReceipt/receipt` and `spctl -a -vv` reporting
`source=Mac App Store`.

Both apps can be installed side by side, and while they are, `.key` files
may open in either. If a script must be certain, target the bundle id, not
the name — the executable inside both bundles is called `Keynote`.

## Two remaining launch traps (hit live, 2026-07-22)

1. **Sandboxed opens.** Apple-event `open (POSIX file ...)` silently
   returns `missing value` for some paths (observed for
   `~/Library/CloudStorage/Dropbox/...` and `/private/tmp/...`). Launch the
   file via LaunchServices instead — `open -b com.apple.Keynote <deck>`
   grants access like a Finder double-click — then find the open document by
   `name` from AppleScript.
2. **Auto-termination.** A window-less Keynote is auto-terminated by macOS
   between osascript calls, producing "Connection is invalid (-609)". Open
   the document first (a window keeps it alive) and do all work in one
   osascript run.

## The wrong-document trap

Keynote's `open` sometimes returns `missing value` (notably on cold
launch), and the tempting fallback — `front document` — can silently grab
whatever deck Keynote restored on launch. (Caught live: an audit matched
code against the wrong deck.) `key-audit` therefore absolutizes the deck
path and, when `open` returns nothing, locates the document by comparing
each open document's `file` to the requested path — never window position,
never `name` (the `.key` extension may be hidden).

## Direct `.key` surgery (investigated, rejected)

`keynote-parser` can unpack → YAML → repack and do plain-text replacement;
swapping media bytes is conceivable but unsupported, risks corrupted decks
and stale previews, and needs Keynote-version-matched protobuf schemas.
Reading the zip for audits is safe; writing it is not worth it.
