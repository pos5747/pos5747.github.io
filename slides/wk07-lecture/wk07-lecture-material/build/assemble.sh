#!/bin/zsh
# Regenerate lecture.qmd (one level up from wk07-lecture-material/build/) from the shared setup chunk + section includes.
SP="$(cd "$(dirname "$0")/../.." && pwd)"
D="$SP"
{
cat <<'YAML'
---
title: "MCMC"
subtitle: "Metropolis algorithm · HMC and Stan · {brms} · LOOIC · multinomial logit"
author: "Lecture 07 · POS 5747 · Tuesday, October 6, 2026"
---

YAML
cat "$D/wk07-lecture-material/build/setup-chunk.qmd"
cat <<'BODY'

{{< include sections/01-opening.qmd >}}

{{< include sections/02-metropolis.qmd >}}

{{< include sections/03-stan.qmd >}}

{{< include sections/04-brms.qmd >}}

{{< include sections/05-loo.qmd >}}

{{< include sections/06-multinomial.qmd >}}

{{< include sections/07-wrap.qmd >}}

BODY
} > "$D/lecture.qmd"
echo "assembled $D/lecture.qmd"
