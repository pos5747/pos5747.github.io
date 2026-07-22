# The Keynote slide workflow

The slides stay in **Keynote** (the WYSIWYG part is the part that works);
the two tedious support pipelines — (1) LaTeX equations and (2) code +
figures — are automated by the scripts in this directory. This documents the
by-hand procedure the scripts grew out of, the tools that replace it, and
where Claude Code fits. Engineering details of the Keynote AppleScript
surface are in `keynote-scripting-notes.md`.

(A full Quarto/revealjs conversion was prototyped in July 2026 and set
aside in favor of this workflow; the prototype is recoverable from Dropbox
version history of `5747website/slides/convert-to-quarto/` if ever wanted.)

---

## Part 1 — The current procedure

### 1a. Equations (`_src/slides-material/equations/`)

Every equation, theorem card, and exam question on a slide is a **tightly
cropped vector PDF** compiled from its own tiny `.tex` file:

```latex
\documentclass[border=3bp]{standalone}     % crops to the content + 3bp
\input{eqn-preamble.tex}                   % shared preamble (via TEXINPUTS)
\begin{document}
$x^2$                                       % bare math → auto-sized
\end{document}
```

- `_src/eqn-preamble.tex` is the single source of the look: **tgpagella**
  (serif chosen to pair with Source Sans 3), `\parindent`/`\parskip` settings,
  and the Set1 colors (`red` `#e41a1c`, `blue` `#377eb8`, `green` `#4daf4a`)
  so `\textcolor{blue}{\pi^k}` matches the deck's semantics.
- Two layouts (see `eqn4-mini.tex` vs `eqn4-nomini.tex`): bare math
  auto-sizes to its content; prose blocks (theorems, exam questions) get
  `\begin{minipage}{3.5in}` to set the measure and enable wrapping.

**The human loop:** write/edit the `.tex` → run pdflatex → find the PDF →
drag into Keynote → resize/position → *also* paste the LaTeX source into the
slide's presenter notes so the source travels with the deck (that's why the
wk02 `.key` notes are full of LaTeX). Any edit repeats every step, and the
pasted PDF has no memory of which `.tex` it came from.

Historically fragile: the `.tex` files used a relative `\input` path to the
preamble, which broke whenever an equations folder sat at a different depth.
Now `slide-eqn` and the Makefile set `TEXINPUTS`, so every `.tex` writes
`\input{eqn-preamble.tex}` with no path.

### 1b. Code (`_src/highlight-code-fn.R`, `_src/pygmentize-command-example.txt`)

Each lecture example is a well-commented standalone script,
`wkNN-slides-material/lecture-example-NN-<topic>.R`. To get colored code onto
a slide there are two routes, both ending in a browser copy-paste:

1. **highlight.js route** (the one that matches the decks):
   `highlight_code()` in `_src/highlight-code-fn.R` wraps the script in an
   HTML page with a custom hljs theme — comments red, keywords blue, strings
   green (Set1 again) — and opens it in the browser. The `.html` files
   sitting next to each `lecture-example-*.R` in the weekly material folders
   are its output.
2. **pygmentize route**: the one-liner in
   `_src/pygmentize-command-example.txt` (`-O full,style=friendly_grayscale`)
   → HTML → browser (the grayscale `clrzd-*.html` in `templates/_output`).

**The human loop:** edit the `.R` → regenerate the HTML → open in browser →
select the rendered text → copy → paste into Keynote → fix font size/line
height → hand-trim to the lines this particular slide needs. Excerpting is
the worst part: each slide shows a *fragment* of the master script, trimmed
by hand, and re-trimmed after every script edit.

### 1c. Figures (`_src/slides-material/R/`, `figs/`)

Figures come from the same lecture-example scripts or dedicated `make-*.R`
scripts (`make-lpm-plots.R`, `make-beta-11-165.R`, `consistency-gif.R`, …):

- ggplot with `theme_ipsum(base_family = "Source Sans 3")` (registered via
  `{showtext}` + `font_add_google`), Set1 colors.
- Saved as vector PDF: `ggsave(..., height = 3, width = 4, scale = 2)` into a
  `figs/` folder (canonically) or the material folder (in practice).
- Animations via `{gganimate}` + `{gifski}` → GIF (`consistency-gif.R`).

**The human loop:** edit script → rerun → drag the new PDF/GIF into Keynote,
replacing the old copy by hand (Keynote embeds a copy; nothing updates
automatically).

### 1d. Organization

`_src/slides-material/` is the canonical per-week layout —
`R/`, `equations/`, `figs/`, `highlighted-code/` — but the real weekly
folders (`wk03-slides-material` … `wk07-slides-materials`) have drifted into
flat mixes of `.R`, `.html`, `.pdf`, `.gif`, `.tex`, and `.pages` files. The
inconsistent folder names (`-material` vs `-materials`) are part of the same
drift.

---

## Part 2 — Where the tedium actually is

| Step | Pain |
|---|---|
| Equation edit → slide | 5 manual steps (edit, compile, locate, drag, note-paste); no slide↔source link |
| Preamble path | breaks per-directory; silently forks the look |
| Code edit → slide | regenerate HTML, browser, select, copy, paste, restyle |
| Per-slide code excerpts | hand-trimmed, silently go stale when the master script changes |
| Figure edit → slide | rerun + re-drag every time |
| Source tracking | LaTeX in presenter notes is manual and drifts from the `.tex` files |
| Organization | no enforced layout or naming, so every week is a little different |

---

## Part 3 — What's now scripted (in `_src/`)

Two scripts kill the worst loops. Both are installed and tested.

### `_src/slide-code` — colored code to the clipboard, or to a PDF asset

```sh
slide-code lecture-example-01-beta.R          # whole file -> clipboard (RTF)
slide-code lecture-example-01-beta.R 10 24    # lines 10–24 (a slide excerpt)
slide-code lecture-example-01-beta.R 10 24 --pdf code/optim-call.pdf
```

Clipboard mode highlights R with the course's Set1 convention and puts
**styled RTF on the clipboard** (Source Code Pro, comments red, keywords
blue, strings green, numbers black). In Keynote: Cmd-V. No HTML file, no
browser, no select-and-copy. It uses the pygments you already have (`pipx`),
via a custom style matching `highlight-code-fn.R`.

`--pdf` renders the same highlighted snippet to a **tightly cropped vector
PDF** instead — which turns code into an image asset exactly like an
equation, so `key-sync` (below) can update it inside the deck automatically.

### `_src/slide-eqn` — one-command equation PDFs, with live preview

```sh
slide-eqn -n eqn-invariance        # new .tex from the standalone template
slide-eqn eqn-invariance.tex       # compile, clean aux files, open in Preview
slide-eqn -w eqn-invariance.tex    # watch mode: recompile on every save
```

- Sets `TEXINPUTS` so every `.tex` writes `\input{eqn-preamble.tex}` with
  **no relative path** — works at any directory depth, one shared preamble.
- Watch mode (`latexmk -pvc`) + Preview's auto-reload = a live equation
  editor: save the `.tex`, see the new PDF instantly, drag it in when happy.

### `_src/key-sync` — auto-update images *inside* the .key

The re-dragging bottleneck, solved. Keynote has **no linked-media feature**
(checked against Keynote 15, Jan 2026, and the June 2026 iWork updates —
only Numbers *charts* auto-update), but its AppleScript API supports the next
best thing: find an image by its original file name, delete it, re-insert the
new file at the same position and width, save. `key-sync` does exactly that:

```sh
key-sync wk02-slides.key equations/eqn-mle.pdf figs/consistency.pdf ...
```

Verified end-to-end on a copy of the wk02 deck: the named image was replaced
at identical geometry and the regenerated media confirmed inside the saved
`.key`. **You drag each asset in once; from then on it updates by name.**

`key-sync` also handles **animated GIFs** (Keynote stores them as movies;
re-inserting the `.gif` as an image gets auto-promoted back to a movie) and
preserves rotation, opacity, and lock state. Two siblings complete the set:

- **`key-add deck.key N asset`** — the *first* insertion, scripted: drops the
  asset onto slide N so you only position it (no Finder digging), and
  guarantees the media keeps its file name (pasting would name it
  "pasted-image" and break matching).
- **`key-code deck.key script.R [first last]`** — updates a pasted-code
  **text box in place**: finds the box whose first line matches the
  snippet's first line (or `--slide N --item M`), swaps in the current text
  from the master `.R`, keeps the box's font and size (the decks use Menlo
  24), and re-applies Set1 colors character-by-character from pygments
  tokens. The deck's code stays *native editable text* — no clipboard, no
  pasting, no PDF conversion.

Limitations to respect (details + full API notes in
`keynote-scripting-notes.md`):
- Every synced asset needs a **unique, stable file name** — the name *is*
  the link; for code boxes, the **first line** (the leading `# comment`) is
  the link.
- A replacement lands **on top of the z-order** with **no Keynote styling**
  — don't auto-sync images that carry Keynote shadows/borders, participate
  in builds, or sit under annotations. (Equation PDFs and plain figures —
  the assets that actually churn — have none of that.)
- Height follows the new file's aspect ratio (width and top-left position
  are preserved); a longer code snippet grows its box downward — glance at
  the slide after big edits.

### `_src/key-audit` — the up-to-date check, automated

If you'd rather update the deck by hand (avoiding the z-order caveats
entirely), the real bottleneck is *checking* — and that's fully automatable,
mostly without even opening Keynote:

```sh
key-audit wk02-slides.key equations/*.pdf figs/*.gif \
          --code R/lecture-example-01-beta.R 10 24
```

- **Media** (equations, figures, GIFs): a `.key` is a zip whose `Data/`
  entries keep their original file names, so the embedded copy of
  `eqn-mle.pdf` can be read straight out of the package and compared against
  the current file — no Keynote, milliseconds. PDFs are compared **as
  rendered pixels** (both rasterized with pdftoppm), so a rebuilt PDF that
  differs only in timestamps still counts as CURRENT; only real visual
  changes read as STALE.
- **Code text**: one scripted pass extracts every text box from the deck,
  and each declared snippet (file + line range) is checked for presence,
  normalized for whitespace and smart quotes.
- Verdicts per item: `CURRENT` / `STALE` / `NOT IN DECK`, exit code 1 if
  anything is off — so `make audit` after editing sources tells you in
  seconds whether the deck needs touching at all.

### The Makefile: the whole loop in one command

`_src/slides-material/Makefile` wires it together. With the standard
folder shape (`equations/*.tex`, `R/make-*.R` → `figs/*.pdf`, declared code
snippets → `code/*.pdf`):

```sh
make            # recompile whatever .tex/.R changed
make audit      # ...then verify the deck against every asset + snippet (read-only)
make sync       # ...or push the changed image/GIF assets into the deck
make sync-code  # ...or refresh the declared code text boxes in place
```

**The working style is audit-first.** Sources + `make audit` are the system
of record; when something reads STALE, Carlisle updates the deck by hand —
re-drag the image (WYSIWYG, z-order safe), re-paste the code from the
highlighted HTML. Checking was the bottleneck; now it's one read-only
command. The push targets (`make sync`, `make sync-code`) exist and work,
but are not part of the normal workflow — use them only deliberately, on
explicit request, subject to the z-order/styling caveats above.

`make` handles staleness (only touched sources rebuild). Edit any equation,
any figure script, any master R script — one command later the assets are
current and the audit says exactly what the deck still needs.

*(Suggested: add `_src/` to `PATH`, or shell-alias the scripts.)*

---

## Part 4 — How Claude Code fits in

The scripts remove keystrokes; Claude Code removes whole jobs. Standing
policy (see `slides/CLAUDE.md`): Claude audits and reports — it reads decks
freely but **never writes to a `.key`**; deck updates are Carlisle's, by
hand. Items below that modify a deck happen only on explicit request.
Things you can delegate verbatim:

**Authoring**
- *"Make an equation snippet of the Poisson log-likelihood derivation,
  colored like wk02."* → Claude writes the `.tex` (correct preamble, minipage
  if prose), compiles via `slide-eqn`, opens the PDF for dragging.
- *"Put lines 30–41 of lecture-example-02 on my clipboard for a slide."* →
  Claude runs `slide-code` with the right range — or picks the range itself
  from a description ("the part that fits the model").

**Keeping things in sync**
- *"Rebuild everything for wk04."* → recompile every `.tex` in
  `equations/`, rerun every `make-*.R`, regenerate figures — one request, or
  a `Makefile` Claude can write once per week (`make eqns figs`).
- *"Which of my slide excerpts are stale?"* → Claude extracts the deck's text
  via AppleScript (slide text + presenter notes are fully scriptable — that's
  how the wk02 deck was reverse-engineered), diffs code fragments on slides
  against the current `.R` masters, and reports exactly which slides show
  outdated code.

**Source tracking**
- The presenter-notes-as-source-archive step can be automated in both
  directions: Claude can *write* the LaTeX source into a given slide's
  presenter notes via AppleScript after you drag in the PDF, and can *rebuild*
  every equation PDF from what's stored in a deck's notes.

**Housekeeping**
- Migrate each `wkNN-slides-material*` folder to the canonical
  `R/ equations/ figs/ highlighted-code/` layout (and reconcile
  `-material`/`-materials`), updating the `dir <-` paths inside the scripts.
- Start a new week: scaffold the folder, copy the templates, stub the
  `lecture-example-*.R` files from the lecture outline.

**What stays manual:** everything inside Keynote — placement, styling, and
the updates themselves (re-drag, re-paste). The automation's job is to keep
the assets rebuilt and to say, precisely, what's stale.

---

## Part 5 — Suggested conventions going forward

1. **One folder shape per week** (the `_src/slides-material/` shape,
   now with a `Makefile` — copy it and adjust `KEY` and `TOOLS`):
   ```
   wkNN-slides-material/
     Makefile      make / make audit
     R/            lecture-example-*.R, make-*.R
     equations/    eqn-*.tex (+ compiled eqn-*.pdf)
     code/         slide-code --pdf snippets (declared in the Makefile)
     figs/         *.pdf, *.gif  (script outputs only — never hand-edited)
   ```
   (`highlighted-code/` becomes unnecessary once `slide-code` replaces the
   HTML round-trip.)
2. **Asset names are links.** Name every synced file uniquely and stably
   after its content — `eqn-mle-definition.pdf`, `fig-consistency.pdf`,
   `code-optim-call.pdf` — because `key-sync` matches deck images by file
   name. Rename = re-drag.
3. **Keep every slide excerpt's line range out of your head**: when a slide
   shows lines of a master script, leave a comment fence in the script
   (`## ---- slide: optim-call ----`) so Claude (or awk) can re-extract the
   excerpt by name, not by line number — and record the range in the
   Makefile's snippet rule, not in your memory.
4. **`slide-eqn -w` while drafting math; `slide-code` for code; `make audit`
   after any edit — then fix what it flags by hand.**
