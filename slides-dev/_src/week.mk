# week.mk — shared rules for every wkNN-slides-material folder.
#
# Never copied into weekly folders; the top-level slides/Makefile runs it as
#   make -C wkNN-slides-material -f ../_src/week.mk <target>
# Everything is derived from the folder name; the only optional per-week
# file is snippets.mk (declares code snippets, GIF figures — see below).
#
# Targets:
#   make          rebuild whatever is stale (equations, figures, code PDFs)
#   make audit    ...then check the deck against every asset + snippet
#   make list     print every asset and the source that makes it
#   make clean    remove stamp files and LaTeX litter (never assets)
#
# Conventions (see slides/README.md):
#   equations/eqn-<topic>.tex          -> equations/eqn-<topic>.pdf
#   R/fig-<topic>.R writes             -> figs/fig-<topic>.pdf (or .gif)
#   snippets.mk declares               -> code/code-<name>.pdf and/or
#                                         CODE_SNIPPETS for text-box audits

.DEFAULT_GOAL := all

WEEK  := $(patsubst %-slides-materials,%,$(patsubst %-slides-material,%,$(notdir $(CURDIR))))
KEY   := ../$(WEEK)-slides.key
TOOLS := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# R used for figure scripts. Default follows PATH; _src/local.mk can
# override (e.g. to pin a specific R.framework version whose library
# actually has the course packages).
RSCRIPT ?= Rscript
-include $(TOOLS)/local.mk

TEXS := $(wildcard equations/*.tex)
EQNS := $(TEXS:.tex=.pdf)

# Figures run via stamp files: R/fig-x.R reruns whenever the script is newer
# than its last run. This tracks any output — pdf, gif, or several files —
# without the Makefile needing to know the extension.
FIGSRC   := $(wildcard R/fig-*.R)
FIGSTAMP := $(patsubst R/%.R,figs/.stamp/%.done,$(FIGSRC))

# Per-week declarations (optional). snippets.mk may define:
#   SNIPPETS      += code/code-fit-model.pdf        (code shown as an image)
#   code/code-fit-model.pdf: R/lecture-example-01-logit.R
#	$(TOOLS)/slide-code $< fit-model --pdf $@
#   CODE_SNIPPETS += --code R/lecture-example-01-logit.R fit-model
#                                                   (code pasted as text)
SNIPPETS :=
CODE_SNIPPETS :=
-include snippets.mk

all: $(EQNS) $(FIGSTAMP) $(SNIPPETS)

equations/%.pdf: equations/%.tex $(TOOLS)/eqn-preamble.tex
	cd equations && TEXINPUTS=".:$(TOOLS):" latexmk -pdf -interaction=nonstopmode $(notdir $<) >/dev/null && latexmk -c $(notdir $<) >/dev/null

figs/.stamp/%.done: R/%.R
	@mkdir -p figs/.stamp
	$(RSCRIPT) $<
	@touch $@

# Audit the deck against every built asset (whatever actually exists in
# equations/, figs/, code/) plus the declared text snippets. Read-only on
# the deck; exit 1 if anything is stale.
audit: all
	$(TOOLS)/key-audit $(KEY) $(EQNS) $(wildcard figs/*.pdf figs/*.gif) $(wildcard code/*.pdf) $(CODE_SNIPPETS)

# Semantic check against the notes book (LLM-assisted, cached, opt-in —
# deliberately NOT part of `audit`). Run while revising this week's slides.
notes-audit:
	$(TOOLS)/notes-audit $(CURDIR)

list:
	@echo "$(WEEK): deck $(KEY)"
	@for t in $(TEXS); do echo "  eqn   $${t%.tex}.pdf  <-  $$t"; done
	@for r in $(FIGSRC); do echo "  fig   figs/$$(basename $$r .R).*  <-  $$r"; done
	@for s in $(SNIPPETS); do echo "  code  $$s  (snippets.mk)"; done
	@for c in $(CODE_SNIPPETS); do :; done
	@if [ -n "$(CODE_SNIPPETS)" ]; then echo "  text  $(CODE_SNIPPETS)"; fi

clean:
	@rm -rf figs/.stamp Rplots.pdf
	@cd equations 2>/dev/null && rm -f *.aux *.log *.fls *.fdb_latexmk *.synctex.gz || true
	@echo "$(WEEK): cleaned stamps and LaTeX litter"

.PHONY: all audit notes-audit list clean
