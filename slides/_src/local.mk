# Machine-local overrides for week.mk (this Mac only).
#
# 2026-08-24: the override that pinned figure scripts to R 4.4-arm64 is
# retired. R.framework "Current" is now the native arm64 R 4.6.1 with the full
# course library, so the default RSCRIPT in week.mk is correct. If a future R
# upgrade lands without its packages again, re-pin here, e.g.:
#   R44 := /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources
#   RSCRIPT := R_HOME=$(R44) $(R44)/bin/exec/R --vanilla -s -f
