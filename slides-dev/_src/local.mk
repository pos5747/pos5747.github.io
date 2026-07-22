# Machine-local overrides for week.mk (this Mac only).
#
# The R.framework "Current" symlink points at R 4.6.1 (x86_64), which has
# almost none of the course packages — the working library lives under
# 4.4-arm64. Pin figure scripts to that R until packages migrate to a newer
# version; then update (or delete) this override.
R44 := /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources
RSCRIPT := R_HOME=$(R44) $(R44)/bin/exec/R --vanilla -s -f
