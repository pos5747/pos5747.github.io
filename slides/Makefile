# slides/Makefile — one command for every week's generated assets.
#
#   make               rebuild whatever changed, across all weeks
#   make audit         ...then check every deck (read-only; exit 1 if stale)
#   make list          print every asset and its source, per week
#   make clean         remove stamps and LaTeX litter
#
#   make wk02          rebuild one week
#   make audit-wk02    audit one week
#
#   make slidepdfs    export every wkNN-slides.key to wkNN-slides.pdf
#
# This tree IS the published source (the slides/ + slides-dev/ split was merged
# 2026-08-24). Quarto copies only the exported decks at the top level into
# ../docs/slides/ — see README.md ("Publish").
#
# All rules live in _src/week.mk — weekly folders contain only content
# (R/, equations/, code/, figs/, optional snippets.mk). New week: see
# README.md ("Start a new deck").

WEEKS := $(patsubst %/.,%,$(wildcard wk*-slides-material*/.))

all audit notes-audit list clean:
	@fail=0; for w in $(WEEKS); do \
	  echo "== $$w"; \
	  $(MAKE) --no-print-directory -C $$w -f ../_src/week.mk $@ || fail=1; \
	done; exit $$fail

wk%:
	@$(MAKE) --no-print-directory -C $(filter wk$*-slides-material%,$(WEEKS)) -f ../_src/week.mk

audit-wk%:
	@$(MAKE) --no-print-directory -C $(filter wk$*-slides-material%,$(WEEKS)) -f ../_src/week.mk audit

notes-audit-wk%:
	@$(MAKE) --no-print-directory -C $(filter wk$*-slides-material%,$(WEEKS)) -f ../_src/week.mk notes-audit

# ---- deck PDFs ---------------------------------------------------------------
# Export each top-level deck to PDF via Keynote, no point-and-click. Rebuilds
# only when the .key is newer than the .pdf.
#
# slide-export works on a COPY of the deck, so the .key is never opened and can
# never be upgraded or autosaved by the export. The PDF reflects the deck as
# LAST SAVED — save in Keynote before exporting.

DECK_KEYS := $(wildcard wk*-slides.key)
DECK_PDFS := $(DECK_KEYS:.key=.pdf)

.PHONY: slidepdfs
slidepdfs: $(DECK_PDFS)

# One EXPLICIT rule per deck, generated. A pattern rule (wk%-slides.pdf:
# wk%-slides.key) does NOT work here: the `wk%:` convenience target above also
# matches `wk01-slides.pdf`, and having no prerequisites it declares the PDF up
# to date, so nothing ever rebuilds. Explicit rules take precedence over
# pattern rules, which is what makes this version fire.
define DECK_PDF_RULE
$(1:.key=.pdf): $(1)
	@_src/slide-export "$$<" "$$@"
endef
$(foreach k,$(DECK_KEYS),$(eval $(call DECK_PDF_RULE,$(k))))

.PHONY: all audit notes-audit list clean
