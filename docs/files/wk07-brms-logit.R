# Illustrating logistic regression with {brms}

# ---- setup ----

# nice printing
options(digits = 3)

# load packages
library(tidyverse)
library(brms)
library(posterior)
library(marginaleffects)

# load only the turnout data frame and hard-code rescaled variables
turnout <- ZeligData::turnout  |>
  mutate(across(age:income, arm::rescale, .names = "rs_{.col}")) |>
  glimpse()

# formula
f  <- vote ~ rs_age + rs_educate + rs_income + race

# fit model with brms via cmdstanr
fit <- brm(f, data = turnout, family = bernoulli,
           chains = 4, cores = 4,
           backend = "cmdstanr")

# print estimates
fit

# ---- diagnostics ----

# r-hat and ess for each parameter ({brms} warns only when an r-hat exceeds 1.05)
summarise_draws(fit, "rhat", "ess_bulk", "ess_tail")

# number of divergent transitions after warmup
sum(nuts_params(fit, pars = "divergent__")$Value)

# ---- quantities of interest ----

# compute qi
comparisons(fit, variables = list(rs_age = c(-0.5, 0.5)),
            newdata = datagrid(grid_type = "mean_or_mode"))
