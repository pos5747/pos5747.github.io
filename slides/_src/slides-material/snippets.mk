# snippets.mk — the only per-week Makefile fragment (optional; delete if the
# week has no code on slides). Declares which snippets of the master R
# scripts appear in the deck, so `make audit` can check them.
#
# Mark each excerpt in the master script with a named fence:
#   ## ---- slide: fit-model ----
# (the snippet runs to the next `## ----` fence or end of file)

# Code pasted onto slides as STYLED TEXT (via `slide-code script.R <name>`,
# then Cmd-V in Keynote). One --code entry per snippet; `all` = whole file.
#
# CODE_SNIPPETS += --code R/lecture-example-01-logit.R all
# CODE_SNIPPETS += --code R/lecture-example-01-logit.R fit-model

# Code shown as an IMAGE asset (rare; behaves like an equation PDF):
#
# SNIPPETS += code/code-fit-model.pdf
# code/code-fit-model.pdf: R/lecture-example-01-logit.R
#	$(TOOLS)/slide-code $< fit-model --pdf $@
