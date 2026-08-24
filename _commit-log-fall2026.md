# Commit log — Fall 2026 revision

Running description of uncommitted work, batch by batch. Claude never runs
git; Carlisle renders and commits via GitHub Desktop. (Leading underscore
keeps Quarto from rendering this file; it is a tracked file in this repo.)

Note on `CLAUDE.md` files: both repos gitignore `CLAUDE.md` at every level, so
`5747website/CLAUDE.md`, `5747website/slides-dev/CLAUDE.md`, and
`notes/CLAUDE.md` changed today but will **not** appear in any commit.

---

## 2026-08-24 — website repo: Fall 2026 dates, syllabus swap, Assessments page, cleanup

**Status: READY TO COMMIT.** Full `make exercises` → `make notes` →
`make site` run completed 14:58–14:59 with all three exiting 0, no warnings,
no Dropbox conflicted copies. (An earlier attempt failed on six R packages
missing from the migrated library — pscl, MCMCpack, flexsurv, glmmTMB,
retrodesign, xkcd — now installed; and on a Dropbox sync race that left 43
conflicted copies in `notes/docs/`, since deleted. Both gotchas are recorded
in the CLAUDE.md files.) Commit the changed sources together with the
regenerated `docs/` and `_freeze/`. Expected in the commit: the files below
plus every changed file under `docs/`.

### exr/*.pdf — rebuilt
- `make exercises` rebuilt every exercise PDF under the new R and synced them
  here. The wk04/05/06/12 PDFs now carry the `[pdf]` readings links (which
  resolve once the notes repo is pushed). The other weeks are re-rendered but
  should be content-identical apart from package-version noise.

### index.qmd (the schedule)
- Re-dated every block to the Fall 2026 **Tuesday** calendar: Aug 25 – Dec 1,
  midterm Oct 13 (the meeting after MCMC), Nov 24 = "wrap" (inherits the old
  wrap/review slide links), Dec 1 = "posters", final exam Tue Dec 8,
  9:00–11:30 AM in Bellamy 113 (our usual meeting time).
- Due-date remarks moved with their blocks: prospectus Sep 29; first draft +
  workshop outline Oct 20; peer-review memo + workshop drafts Oct 27;
  workshop rehearsal Nov 10; second draft Nov 24; poster presentations Dec 1;
  final draft Dec 8. The Thanksgiving-break block is gone (a Tuesday course
  isn't affected by the Wed–Fri break).
- New header paragraph: meeting day/time/room, office hours (Mondays
  1:00–2:00 PM, Bellamy 540), TA Bryson Lyons (office hours and optional
  study/review session, times TBD), and a link to the Simple Syllabus.
- Removed the `[comments](exam2-comments.qmd)` link from the final-exam block
  (Fall 2025 study guide; now linked from the Assessments page instead).
- nov 17 block now links `[solutions](exr/wk13-exr-sol.pdf)` like every other
  week (file exists; it previously linked the unsolved `wk13-exr.pdf`).
- Fixed the `slides//wk09-wk11-slides/...` double slash.
- **Links stripped back to week one** (decided 2026-08-24; done ~16:20).
  Every `[slides]`, `[materials]`, `[notes]`, `[solutions]` link is removed
  except on the aug 25 block; topic spans and due-date remarks stay. Links
  return one week at a time as each week's materials are actually revised and
  rendered — adding the link is the *last* step of revising a week. The
  targets (`slides/`, `exr/`, `files/`, notes URLs) are untouched on disk.
- Week 1 now links `[exercises](exr/wk01-exr.pdf)` instead of the solutions.
  New weekly rhythm: link exercises when the week goes live; add
  `[solutions]` at the end of the week (Tuesday morning before class). Recorded
  in `5747website/CLAUDE.md`.
- Post-midterm topics reshuffled (Carlisle, ~16:45): a new **ai** meeting on
  oct 20 right after the midterm; hierarchical models 1/2 move to oct 27 /
  nov 03; irt to nov 10; "a final perspective" collapsed into one meeting on
  nov 17; wrap stays nov 24. Due-date remarks stay on their calendar dates
  (they follow the assignment pages, not the topics).
- dec 01 block corrected: the posters are not in class — "No class meeting;
  instead, poster presentations on the 5th floor of Bellamy from 9:45 to
  11:30 AM" (the department poster session, per the DGS scheduling record;
  same details on the research-project page's Poster milestone).
- Carlisle rewrote the header as two bullets (office hours; TA) — the meeting
  time/room sentence and the Simple Syllabus link are gone from the page
  (the navbar still links the syllabus).

### research-project.qmd
- Dates: optional assignments Sep 1/8/15/22; prospectus Sep 29; first
  draft Oct 20; second draft Nov 24 (dropped the "(Tuesday!)" flag — it's
  class day now); poster presentation "in class on Dec. 1"; final project
  "due by Dec. 8".
- Milestone weights added (shares of the course grade, summing to the
  paper's 35%): prospectus 5, first draft 5, peer review 5, second draft 5,
  poster 5, final 10 — the old long-form-syllabus split, now stated on the
  page for the first time.
- New **Peer Review** required assignment (5%, due Oct 27), so the page stands
  alone: the instructions moved here from the wk09 exercise (RAP model link,
  "highest points of leverage," the three required feedback items). First
  Draft gained "Also email the PDF to your assigned reviewer." The
  peer-review *timing* is unchanged (redesign deferred; see root CLAUDE.md).
- Minimal housekeeping: callout now reads "I continue to revise this
  project"; typos fixed ("the the," "T causes X" → "T causes Y" in footnote
  1, "is stronger," "Gerrying," "Some folks [like] Overleaf's").
- Not done (deferred, flagged in root CLAUDE.md): AI-use statement.

### workshop.qmd
- Dates, on the day-before-class (Monday) convention: outline Oct 19,
  drafts Oct 26, rehearsal Nov 9 ("before class on Nov. 10"), workshop due
  Nov 24, delivered "ideally between Nov. 10 and Nov. 24". Rehearsal timing
  now agrees with the schedule (it conflicted in Fall 2025).
- Weights: one lead sentence saying the 10/25/15/50 percentages are shares
  of the workshop's 15% of the course grade.
- The Cox proportional-hazards example (and the published note-to-self
  "I want to replace this Cox PH model with a logit model") is replaced by a
  **turnout logit** using the notes' own data and formula
  (`ZeligData::turnout`, `vote ~ age + educate + income + race`): fit, one
  `predictions()` (expected value across age), one `comparisons()` (first
  difference, education 12 → 16, across age), two ribbon plots. The chunk
  executes at render, so its frozen output regenerates (verified to run under
  the new R).
- New section **"Extra Credit for Participants"**: RIBC students get extra
  credit for attending; each team must design an equivalent alternative
  assignment (handout-based, ~1 hour) for students who cannot attend, and
  include it with their drafts. Policy basis: no FSU extra-credit rule exists
  (checked the Faculty Handbook, FDA syllabus page, and all DGS procedure
  documents); the section cites the University Attendance Policy and the
  fixed-syllabus grading statement.
- Minimal typos: "pass/fall," "three person… work alone," "is lightweight
  document," "big ideas concepts," "each references," "I want to students."
- Carlisle's edits: Topics list now has four suggested topics (binary,
  unordered categorical, ordered categorical, **count** outcomes — count is
  new); the duplicate RIBC/Posit Cloud sentence is gone.
- New `## AI` section, mirroring the paper page: AI always allowed but
  **must declare any use**; encouraged for review and error checking;
  responsible for content; links to the annotated *AJPS* policy; plus a
  sentence saying *where* to document usage (single consolidated statement at
  the end of the take-home handout, covering each component; "No AI tools
  were used" if none). No warning callout here (Carlisle removed it; the
  paper page keeps its).
- Not changed, verify: "about 10 participants," Homecoming (no classes after
  noon Fri Nov 20) inside the delivery window.

### AI-use statement on assessments.qmd (exercises)
- In Carlisle's words: AI always allowed; the exercises are preparation for
  the assessments and exams, so using AI to complete them defeats the
  purpose; AI as a "tutor" is fine but Carlisle or Bryson is better. Together
  with the two assignment-page sections and the annotated policy, this
  satisfies the published syllabus's "expectations … stated in the assignment
  instructions." Closes plan step 10.

### annotated-ajps-ai-policy.qmd — NEW
- The *AJPS* AI policy (version "Updated August 11, 2026," fetched verbatim
  2026-08-24) adopted as the course AI policy for work submitted in the course
  (research project, workshop). Opens with the rule in one sentence ("AI is
  permitted … but every use that shaped the work must be transparently
  reported"), a vocabulary map (author → you/team, manuscript → paper or
  materials, journal → me, reviewers → your peer reviewer), and a note that
  the page is frozen for the semester even if *AJPS* revises theirs.
- Four "Modified" callouts (Carlisle trimmed the draft's "Clarified" ones):
  no Wiley guidelines; where the declaration goes (first-page footnote on
  *every* submission including the optional early assignments, poster may
  link to the paper instead; workshop: end of the take-home handout covering
  each component); "decline" → violation of the collaboration rule and the
  Academic Honor Policy; reviewer section governs the peer-review memo
  (classmate's draft is confidential).
- Two punctuation repairs to the verbatim text (a missing period after
  "manuscripts"; "; Matters" → "; matters"). Not in the navbar; linked from
  the AI sections of `research-project.qmd` and `workshop.qmd`.

### AI sections on research-project.qmd and workshop.qmd (final form)
- Identical wording on both pages: "AI is always allowed, but you **must
  declare any use of AI tools** that shaped the work. See more here." + the
  encouraged/responsible/must-declare paragraph pointing at the annotated
  policy. The paper page keeps the "AI is especially bad at writing text"
  warning callout; the workshop page instead states where to document usage.

### assessments.qmd — NEW
- Weekly assessments + the two exams: points, structure, how to prepare.
  Assembled from existing text (published syllabus bullets, wk01 "Exams" /
  "What do I ask of you?" slides, general parts of the exam-comments pages),
  then hand-edited by Carlisle (assessment length ~10 min, drop-the-two-lowest
  rule, "see me or Bryson," AI-as-study-partner aside). Links the Fall 2025
  exam-comments pages as study guides.

### exam1-comments.qmd, exam2-comments.qmd
- A `callout-warning` at the top of each: "These are my notes for the Fall
  2025 midterm/final exam. They do not necessarily apply to the Fall 2026
  exams." Typos: "range in difficult," "see my sides," "Quantitities,"
  "if the claim is hold."

### suggestions-for-exercises.qmd
- File-naming suggestion now matches the course convention (`wk01-exr.qmd`,
  …); "Use the {tinytable} package…".

### _quarto.yml
- Navbar "Syllabus" now points at the published Simple Syllabus URL instead
  of `syllabus.pdf`.
- New navbar entry "Assessments" → `assessments.qmd` (between Workshop and
  Syllabus).
- `syllabus.pdf` removed from `resources:`.

### syllabus.pdf — deleted from the repo
- Moved to `-old/` (gitignored). The long-form PDF carried pre-2026 grade
  weights (exams 45%, midterm 20%, workshop 20%, no weekly assessments) and
  competed with the Simple Syllabus. GitHub Desktop will show a deletion;
  that is intended. `docs/syllabus.pdf` disappears on the next render.

### README.qmd — deleted from the repo
- Moved to `-old/`. It was an internal to-do that `render: "*.qmd"` would
  have published; its one item (the α vs. α−1 beta log-likelihood bug) is
  now fixed (see slides-dev below and the notes section) and logged in
  `notes/CLAUDE.md`.

### exr/western+jackmanBayes1994apsr.pdf — deleted from the repo
- Moved to `notes/readings/Western1994.pdf` under the new readings rule
  (article PDFs live in the notes repo's `readings/` resource directory and
  are linked from exercise text). `docs/exr/` loses the file on render.

### slides/ ← slides-dev/ — the freeze is merged (~17:00)
- `rm -rf slides && mv slides-dev slides`, per the procedure in the old
  `slides-dev/README.md`. Verified beforehand that all 643 files the frozen
  snapshot published exist byte-identically in the working tree (top level or
  `future-slides/`), so nothing was lost. GitHub Desktop will show the frozen
  `slides/` files deleted and `slides-dev/**` renamed to `slides/**`.
- `_quarto.yml`: `"!slides-dev/"` dropped from `render:`; `resources:` now
  publishes `slides/**` minus `_src/`, `README.md`, `CLAUDE.md`, `Makefile`,
  `future-slides/**`, `**/*.key`, `**/*-material(s)/**`, `.DS_Store`,
  `.stamp/`, `.notes-audit/`. `.quartoignore` loses `slides-dev/`;
  `.gitignore` patterns retargeted `slides-dev/*` → `slides/*`.
- **Consequence for `docs/`:** only `slides/wk01-slides.pdf` and
  `slides/wk02-slides.pdf` publish now. The wk03–wk07 PDFs and the
  wk09–wk12 HTML decks disappear from `docs/slides/` (they live in
  `future-slides/`, unpublished until each week is revised). Nothing on the
  schedule links them, so no 404s.
- `.key` files: `.gitignore` still does not exclude them (unchanged from
  before); add `slides/**/*.key` if you want them out of the repo.

### slides/wk02-slides-material/R/lecture-example-01-beta.R (was slides-dev/…)
- The hand-coded beta log-likelihood (`ll-fn-manual` snippet) computed
  `alpha*sum(log(y)) + beta*sum(log(1 - y))`; corrected to `(alpha - 1)` /
  `(beta - 1)`, matching the density's exponents and the deck's equation
  source. The snippet pasted into `wk02-slides.key` is stale until Carlisle
  re-pastes it (nothing writes to `.key`).

### slides-dev/_src/local.mk
- Retired the override that pinned figure scripts to R 4.4-arm64; the
  default R is now correct (see "Outside this repo"). The old pin is left as
  a commented example.

### _commit-log-fall2026.md — NEW
- This file.

### Pending for this repo, not yet done
- `exr/wk04-exr*.pdf`, `wk05`, `wk06`, `wk12`: the exercise **sources**
  (outside this repo) gained `[pdf]` links to the readings; the PDFs here are
  regenerated only by `make exercises`. Do that before rendering so the
  updated PDFs ride in the same commit — or accept that the links appear in a
  later batch.

### Suggested commit message
```
Fall 2026: Tuesday schedule, retire syllabus.pdf, Assessments page, cleanup

- index.qmd: Fall 2026 dates (Aug 25–Dec 8), header with meeting info,
  office hours, TA; drop stale exam-comments link; wk13 solutions link
- research-project.qmd: dates, milestone weights, Peer Review milestone
- workshop.qmd: dates, weights, turnout logit example replaces Cox,
  extra-credit section
- new assessments.qmd; navbar entry
- new annotated-ajps-ai-policy.qmd; AI-use statements on the paper,
  workshop, and assessments pages
- exam comments: Fall 2025 warning callouts
- _quarto.yml: navbar Syllabus -> Simple Syllabus; drop syllabus.pdf
- remove syllabus.pdf, README.qmd, exr/western+jackman PDF (moved to
  notes/readings/Western1994.pdf)
- slides-dev: fix (alpha - 1) in beta log-likelihood script; retire
  local.mk R pin
```

---

## 2026-08-24 — notes repo (separate commit)

**Status: re-rendered at 15:57 (exit 0, no errors) — READY TO COMMIT**
sources + `docs/` + `_freeze/`. `docs/readings/` holds the ten PDFs.

Supersedes the 14:59 `make notes` run: that one picked up the corrected
log-likelihood but still carried the **old contour breaks**, which had been
tuned to the buggy surface — it baked a broken figure into `docs/` (the
interior maximum collapsed into one flat fill). The 15:57 render was done
after deleting `wk02/01-maximum-likelihood_cache/` and retuning the breaks;
its figure and `optim()` output were checked by eye. Commit the 15:57 state.

Note: still a normal freeze render, not the full clean re-render the software
preflight in `notes/CLAUDE.md` calls for — only wk02/01 re-executed, the
other 31 chapters served cached output — so the preflight (plan step 12) is
still open.

- `readings/` — NEW directory with the article PDFs the exercises assign,
  named `FirstauthorYEAR.pdf`: Arel-Bundock2024 (the JSS marginaleffects
  paper, bib key `@me`), Arel-Bundock2025, Berk2010, deKadt2025, Gelman2014,
  Jackman2004, McCaskey2015, Radean2025 (bib key `@beger2025`; Radean is first
  author), Rainey2014, Western1994. Books stay private (decided 2026-08-24).
- `_quarto.yml` — `resources: readings/` so the PDFs publish at
  `https://pos5747.github.io/notes/readings/<file>.pdf`.
- `wk02/01-maximum-likelihood.qmd` — the two hand-coded beta log-likelihoods
  (contour-plot chunk and the first `ll_fn()`) used `alpha*…` / `beta*…`
  where the derivation has `(alpha - 1)` / `(beta - 1)`; fixed.
  - The fix is an **additive constant** (−142.90 for the chapter's data), so
    the argmax does not move: `optim()` gives 11.98350 / 11.91888 before and
    after; only `$value` shifts (−54.59 → +88.31). The "maximized somewhere
    around α = 12 and β = 12" sentence was correct and is **unchanged**, and
    no printed `optim()` output in the chapter changes at all — the `dbeta`
    `ll_fn()` redefines the manual one before `optim()` ever runs.
  - What the fix *did* break was the **hard-coded contour breaks**, tuned to
    the buggy surface (top break −55 sat 0.4 below its max of −54.60). On the
    corrected surface the top band went from 35 to 5371 of 10,000 grid cells
    and the interior maximum vanished. Breaks changed to
    `c(Inf, 85, 75, 50, 0, -100, -400, -Inf)`; the rendered figure now shows a
    single clean peak at about (12, 12) with six legible labels.
- `wk02/R/` — the superseded Fall 2025 slide-code stash (`beta-ll.R`, which
  carried a third, previously missed copy of the same bug; its `beta-ll.html`
  export; `baseball.R`; `holland-predictive.R`) moved to
  `-old/wk02-R-fall2025/` rather than fixed. Nothing sourced or published it;
  `slides-dev/wk02-slides-material/R/` is the live successor. `-old/` is
  gitignored, so these appear in the commit as **deletions**.

### Suggested commit message
```
Add readings/ (article PDFs for the exercises); fix beta log-likelihood code

- readings/: ten article PDFs (FirstauthorYEAR.pdf), published via resources
- wk02/01-maximum-likelihood.qmd: (alpha - 1)/(beta - 1) in the hand-coded
  log-likelihood, matching the derivation; retune the contour breaks, which
  had been tuned to the buggy surface
- wk02/R/: park the superseded Fall 2025 slide-code scripts in -old/
```

---

## Outside both repos (no commit; listed so nothing is forgotten)

- `exercises/wk04-exr-sol.qmd`, `wk05`, `wk06`, `wk12` — `[[pdf](…)]` links
  after each assigned article (wk04's replaced a broken `[[journal](2010)]`).
  Rebuild with `make exercises`; the resulting PDFs land in this repo's `exr/`.
- Root `Makefile` — NEW: `make site`, `make notes`, `make exercises`,
  `make all`.
- Root `CLAUDE.md` — meeting/office-hours/TA/final-exam facts, registrar
  links, the readings rule (books private), the Makefile, the missing
  AI-use-statement flag, the wk09 pairing-table note, remaining plan steps
  8–13.
- `simple-syllabus/CLAUDE.md` — the saved PDF is the binding syllabus;
  `syllabus.txt` demoted to a paste helper; differences logged.
- R install — the Intel R 4.6.1 was replaced by the native arm64 build,
  library rebuilt (494 packages), cmdstan 2.39.0. Old versions
  (`4.6-x86_64`, `4.5-x86_64`, `4.3-arm64`, cmdstan ≤ 2.38) still on disk
  pending Carlisle's `sudo rm`.

---

## Still open (tracked as plan steps 8–13 in root CLAUDE.md)

- Re-run `make site` (annotated policy edited after the 14:25 render), then
  commit + push this repo (step 8). Notes repo render/commit waits for the
  software preflight (12); `make exercises` before the next website batch so
  the readings links ship.
- Bryson's office hours and study-session time (index.qmd header says TBD).
- Peer-review schedule rework (9). Step 10 (AI-use statement) is done.
- Keynote by hand (11): wk01 grade-components slide and "Aggressive
  Scaffolding" table (Fall 2025); wk02 `ll-fn-manual` snippet re-paste.
- Software preflight + clean render of the notes (12).
- workshop.qmd "verify" items: duplicate RIBC sentence, "about 10
  participants," Homecoming inside the delivery window.
