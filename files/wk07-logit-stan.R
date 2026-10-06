# Illustrating logistic regression with Stan via {cmdstanr}

# ---- setup ----

# nice printing
options(digits = 3)

# load packages
library(tidyverse)
library(cmdstanr)
library(posterior)
library(bayesplot)

# ---- data for stan ----

# load only the turnout data frame and hard-code rescaled variables
turnout <- ZeligData::turnout  |>
  mutate(across(age:income, arm::rescale, .names = "rs_{.col}")) |>
  glimpse()

# build model frame and design matrices
f  <- vote ~ rs_age + rs_educate + rs_income + race
mf <- model.frame(f, data = turnout)
X  <- model.matrix(f, data = mf)
y  <- model.response(mf)

# bundle data for Stan
stan_data <- list(
  N = nrow(X),
  K = ncol(X),
  y = as.integer(y),
  X = X
)

# ---- write stan program (self-contained document) ----

stan_code <- "
data {
  int<lower=0> N;
  int<lower=1> K;
  array[N] int<lower=0, upper=1> y;
  matrix[N, K] X;
}
parameters {
  vector[K] beta;
}
model {
  beta ~ normal(0, 5);               // weakly informative prior
  y ~ bernoulli_logit(X * beta);     // logistic regression likelihood
}
"

# write the Stan program to file
writeLines(stan_code, con = 'logit.stan')

# ---- cmdstanr ----

# compile the model
mod <- cmdstan_model("logit.stan")

# draw samples
fit_cmd <- mod$sample(
  data = stan_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup   = 1000,
  iter_sampling = 2000,  # excluding warmup
  seed = 123
)

# cmdstanr summary
fit_cmd$summary(variables = "beta")

# ---- diagnostics ----

# r-hat and ess for each parameter
draws_beta <- fit_cmd$draws(variables = "beta")  # draws array
summarise_draws(draws_beta, "rhat", "ess_bulk", "ess_tail")

# divergences, treedepth hits, and E-BFMI for each chain
fit_cmd$diagnostic_summary()

# ---- bayesplot ----

# densities of parameters by chain
mcmc_dens_overlay(draws_beta)

# ridges plot of densities of parameters
mcmc_areas_ridges(draws_beta)

# trace plots of parameters by chain
mcmc_trace(draws_beta)

# r-hat visualization
mcmc_rhat(rhat(fit_cmd, pars = "beta"))

# ---- shinystan (interactive; typically not evaluated in scripts) ----
# launch GUI manually when needed

# library(shinystan)
# launch_shinystan(fit_cmd)

# ---- quantities of interest ----

# put the simulations of the coefficients into a matrix (one row per draw)
beta_tilde <- fit_cmd$draws(variables = "beta", format = "draws_matrix")
head(beta_tilde)

# compute a first difference via invariance principle
X_lo <- cbind(
  "constant"   = 1,   # intercept
  "rs_age"     = -0.5,# 1 SD below avg -- see ?arm::rescale
  "rs_educate" = 0,
  "rs_income"  = 0,
  "white"      = 1    # white indicator = 1
)

# modify rs_age for high case
X_hi <- X_lo
X_hi[, "rs_age"] <- 0.5  # 1 SD above avg

# function to compute first difference
fd_fn <- function(beta, hi, lo) {
  beta <- as.vector(beta)  # prevent column/row confusion
  plogis(hi %*% beta) - plogis(lo %*% beta)
}

# transform coefficient draws into first-difference draws
fd_tilde <- numeric(nrow(beta_tilde))
for (i in 1:nrow(beta_tilde)) {
  fd_tilde[i] <- fd_fn(beta_tilde[i, ], hi = X_hi, lo = X_lo)
}

# posterior mean of first difference
mean(fd_tilde)
