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
# Nothing in here reaches the website: ../slides/ is a frozen snapshot of the
# published decks and the only Quarto resource. This tree goes live in one
# step, when the revision is done — see README.md ("Publish").
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

.PHONY: all audit notes-audit list clean
