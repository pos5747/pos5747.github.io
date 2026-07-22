# slides/ — frozen snapshot of the published decks

This directory is **exactly what students get**, frozen as it was published
before the current revision. It is the only slide content Quarto copies into
`docs/slides/`.

The decks are being reworked in `../slides-dev/` — Keynote sources, material
folders, the equation/code/figure machinery, and the weeks not yet revised.
Nothing there reaches the website, which is the point: the tree can be
reorganized and rewritten without the live site moving.

Don't edit anything here. It is a snapshot, and every file in it is
superseded by work in `../slides-dev/`.

## Contents

| What | Weeks |
|---|---|
| `wkNN-slides.pdf` | wk01–wk07 |
| `wk09-wk11-slides/` | hierarchical models, IRT, ideal points, MRP (Quarto revealjs: `.html` + `_files/` + `images/` + `styles.css`) |
| `wk12-slides/` | testing, ordered, unordered, interaction (`.html` + support) and `ate.pdf` |

Every file here is linked from the schedule in `../index.qmd`. Nothing else
belongs here — no `.key`, no `_cache/`, no material folders.

## How this ends

There is no per-deck promotion. When the revision is done, this directory is
deleted and `../slides-dev/` is renamed to `slides/` in one swap, with a few
config changes to match. The procedure is in `../slides-dev/README.md`
("Publish").

## Why the snapshot exists at all

Quarto deletes anything in `docs/` it did not produce in the current render,
so "just leave `docs/slides/` alone" is not possible while the site is still
being rendered. The published slides have to be produced from a source
directory inside the project; this is that directory.
