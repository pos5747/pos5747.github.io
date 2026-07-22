# Making slides

Decks are Keynote — the WYSIWYG source of truth for layout and design.
Equations, code, and figures are **generated assets** built from sources in
each week's `wkNN-slides-material/` folder. The system in one sentence:
*scripts build assets, `make audit` says what's stale, hands fix the deck.*

Nothing ever writes to a `.key` file. The machinery lives in `_src/`
(engineering notes: `_src/keynote-scripting-notes.md`; retired tools:
`_src/attic/`).

## The one command

From `slides-dev/`:

```sh
make                    # rebuild every stale asset, all weeks
make audit              # ...then check every deck; exit 1 + report if stale
make wk02               # one week
make audit-wk02         # one week's audit
make notes-audit-wk02   # LLM check vs. the notes book (opt-in; see below)
make list               # every asset and its source
make clean              # stamps and LaTeX litter (never assets)
```

All rules live in `_src/week.mk`; weekly folders contain only content.

## Start a new deck

1. Duplicate `_src/00-slides.key` → `wkNN-slides.key`.
2. Copy `_src/slides-material/` → `wkNN-slides-material/`.

That's it — no Makefile to edit; everything is derived from the folder name.

## The folder shape

```
wkNN-slides-material/
  R/            fig-<topic>.R (one per figure) + master lecture-example scripts
  equations/    eqn-NN-<topic>.tex → eqn-NN-<topic>.pdf (NN = deck order)
  code/         code-<name>.pdf (code shown as an image; rare)
  figs/         fig-<topic>.pdf / .gif — script outputs only, never hand-edited
  snippets.mk   declares code snippets for the audit (optional)
```

## Naming: asset names are links

`key-audit` matches embedded media by original file name, so names are the
one thing connecting a deck to its sources. Rules:

- Equations: `eqn-NN-<topic>` — type prefix, a zero-padded sequence number
  in order of first appearance in the deck, then a content slug that
  matches the notes book's terminology (`eqn-05-toothpaste-likelihood`).
  The number exists for one reason: it makes an alphabetical file list
  roughly follow deck order, so a human scanning for an equation knows
  which part of the list to look in. It is **rough by design** — as slides
  get added, reordered, or cut, the numbers will drift and may be stale or
  not exactly right. That's fine; don't chase exactness. Renumber (or
  don't) whenever convenient.
  **The number is NOT part of the deck link** — `key-audit` matches
  equations by slug, ignoring the number — so renumbering never breaks the
  audit and needs no re-dragging. (The deck's embedded copy keeps the
  number it was dragged in under; it trues up whenever the slide is next
  revised.) The *slug* is the link: changing the slug = re-drag.
- Figures and code: `fig-<topic>` / `code-<name>` (`fig-consistency`,
  `code-fit-model`) — no numbers; there are few enough per week.
- **Script name = asset name**: `R/fig-consistency.R` writes
  `figs/fig-consistency.gif`. Finding a figure's source is reading its
  file name.
- Variants get words, never trailing numbers (`fig-cg-scatter-log`, not
  `fig-cg-scatter-2` — Keynote uses `-N` internally for duplicates, which
  would confuse the audit).
- Rename = re-drag. Always **drag the file** into Keynote; pasting names
  media "pasted-image" and blinds the audit.

## Equations

- One `.tex` per equation in `equations/`, from
  `_src/slide-eqn -n eqn-NN-<topic>`. Draft with `slide-eqn -w` (live
  preview: save the `.tex`, Preview reloads the PDF).
- `\documentclass[border=3bp]{standalone}`, then `\input{eqn-preamble.tex}`
  — no path; TEXINPUTS finds the shared preamble in `_src/`.
- Bare math auto-sizes. Wrap prose (theorems, questions) in
  `\begin{minipage}{3.5in}`.
- The `.tex` file is the source of record — never only in Presenter Notes.
  (Older decks stash LaTeX in notes; extract it when revising.)
- Notation should match the notes book — `make notes-audit-wkNN` checks
  (see below).
- `make` compiles all; drag the PDF in once; `make audit` flags real visual
  changes (rebuilt-but-identical PDFs stay CURRENT).

## Code

- One well-commented master script per example in `R/`
  (`lecture-example-NN-<topic>.R`). The `.R` file is the source of record —
  code never lives only on a slide.
- Mark each slide excerpt with a named fence in the script:

  ```r
  ## ---- slide: fit-model ----
  ```

  The snippet runs to the next `## ----` fence or end of file. Fences, not
  line numbers — editing the script never renumbers anything.
- Onto the slide: `_src/slide-code script.R fit-model` puts the excerpt on
  the clipboard as colored, editable text — already Menlo 24, the deck's
  code style — then Cmd-V in Keynote. (`--list` shows a script's fences;
  `--pdf` renders an image asset instead, for the rare code-as-image slide.)
- Declare each snippet in the week's `snippets.mk` so `make audit` checks
  that the deck's text still matches the script.
- Code should match the notes book's code — `make notes-audit-wkNN` checks
  (see below).

## Figures

- One script per figure: `R/fig-<topic>.R` writes `figs/fig-<topic>.pdf`
  (or `.gif`), with paths **relative to the week folder** (`make` runs
  `Rscript` from there).
- ggplot: `theme_ipsum(base_family = "Source Sans 3")`, registered via
  `{showtext}` + `font_add_google("Source Sans 3")`; Set1 colors; save
  vector with `ggsave(..., height = 3, width = 4, scale = 2)`.
- Animations: `{gganimate}` + `{gifski}` → GIF.
- `make` reruns a figure script whenever it's newer than its last run
  (stamp files in `figs/.stamp/`), so GIFs and multi-output scripts are
  tracked too.

## Style

- Text: Source Sans 3 · Code: Menlo 24 · Mock annotations: Marker Felt
  (Thin) · Math: tgpagella (via `_src/eqn-preamble.tex`).
- Colors: Set1 — red `#e41a1c`, blue `#377eb8`, green `#4daf4a`; in code:
  comments red, keywords blue, strings green.
- Transitions: none by default; Magic Move when it earns it.

## The update loop

1. Edit any `.tex` or `.R`.
2. `make audit` (from `slides-dev/`) — rebuilds what changed, then reports per
   deck: CURRENT / STALE / NOT IN DECK.
3. Fix by hand in Keynote: re-drag stale PDFs/GIFs; re-paste stale code via
   `slide-code`.

## The notes correspondence audit (opt-in)

The notes book (`../../notes/wkNN/`) is the source of truth for notation
and code. `make notes-audit-wkNN` asks a Sonnet agent whether this week's
equations and master scripts have drifted from the notes — substantive
drift only (symbols, formulas, variable names, model specs), never
formatting. Verdicts: CURRENT / STALE (with reason; exit 1) / NOMATCH.

- **Deliberately separate from `make audit`**: editing the notes never
  triggers anything. Run it when you sit down to revise a week's slides.
- Results are cached by content hash — if neither the slide sources nor
  the notes chapters changed, the cached report replays with no API call.
- `_src/notes-audit <week-dir> --dry-run` shows what would be compared
  (and saves the assembled prompt) without calling the API; `--force`
  bypasses the cache; `NOTES_AUDIT_MODEL` overrides the model.

## Publish

Nothing in `slides-dev/` reaches the website. `../slides/` is a frozen
snapshot of the decks as they were published before this revision, and it is
the only slide content Quarto copies into `docs/` — so work here freely, the
live site cannot move under you.

There is no per-deck promotion step. When the revision is done, this tree
becomes the published one in a single swap:

```sh
cd ..
rm -rf slides          # drop the frozen snapshot
mv slides-dev slides
```

Then restore the old publishing config, which the freeze temporarily
displaced:

1. `_quarto.yml` — drop `- "!slides-dev/"` from `render:`, and put the `!`
   exclusions back under `resources:` so the working tree's private parts
   stay unpublished:
   `!slides/_src/**`, `!slides/README.md`, `!slides/CLAUDE.md`,
   `!slides/Makefile`, `!slides/future-slides/**`, `!slides/**/*.key`,
   `!slides/**/.DS_Store`, `!slides/**/.stamp/**`, `!slides/**/.notes-audit/**`.
   The `.key` and `future-slides/` exclusions keep hundreds of MB off the
   site. The entry must stay in glob form (`slides/**`) — a bare directory
   entry is copied wholesale and every `!` is silently ignored.
2. `.quartoignore` — remove the `slides-dev/` line.
3. `.gitignore` — retarget the five `slides-dev/*` patterns to `slides/*`.

**Check the schedule links before rendering.** `../index.qmd` links
`slides/wk03-slides.pdf` … `slides/wk12-slides/*.html`, but after the swap
those weeks sit under `slides/future-slides/`. Any week still in
`future-slides/` needs either its link updated or its artifact moved to the
top level, or it will 404. `wk01`/`wk02` are already at the right paths.

Finally: export each revised deck by hand (File → Export To → PDF →
`wkNN-slides.pdf`), `quarto render`, then commit the source change **and**
`docs/` together and push.

## Division of labor

Claude edits sources, runs `make`/`make audit`, and reports what's stale —
including extracting text or notes from a deck (read-only, on a scratchpad
copy). Carlisle does everything inside Keynote: design, placement,
re-dragging, re-pasting, PDF export. No automation writes to a `.key`.
