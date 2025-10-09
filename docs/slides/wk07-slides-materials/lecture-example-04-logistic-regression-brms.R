# ---- setup ----

# nice printing
options(digits = 3)

# load packages
library(tidyverse)
library(brms)

# load only the turnout data frame and hard-code rescaled variables
turnout <- ZeligData::turnout  |>
  mutate(across(age:income, arm::rescale, .names = "rs_{.col}")) |>
  glimpse()

# build model frame and design matrices
f  <- vote ~ rs_age + rs_educate + rs_income + race

# fit model with brms
fit <- brm(f, data = turnout, family = bernoulli, 
           chains = 10, cores = 10)

# compute qi
comparisons(fit, variables = list(rs_age = c(-0.5, 0.5)), 
            newdata = datagrid(grid_type = "mean_or_mode"))

# fit model with brms via cmdstan!
fit <- brm(f, data = turnout, family = bernoulli, 
           backend = "cmdstanr")

