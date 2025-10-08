# ---- setup ----

# nice printing
options(digits = 3)

# load packages
library(tidyverse)
library(tinytable)
library(hrbrthemes)
library(showtext)

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

# ---- rstan ----

library(rstan)

fit_rstan <- stan(
  file = "logit.stan",
  data = stan_data,
  chains = 4,
  cores  = 4,
  warmup = 1000,
  iter   = 3000,  # total iter, incl warmup
  seed   = 123
)

# print summary for beta
print(fit_rstan, pars = "beta")

# ---- cmdstanr ----

library(cmdstanr)

mod <- cmdstan_model("logit.stan")

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

# ---- bayesplot ----

library(bayesplot)

# densities of parameters by chain (rstan)
mcmc_dens_overlay(fit_rstan)

# ridges plot of densities of parameters
mcmc_areas_ridges(fit_rstan, regex_pars = "beta")

# r-hat visualization
mcmc_rhat(rhat(fit_rstan))

# ---- shinystan (interactive; typically not evaluated in scripts) ----
# launch GUI manually when needed

library(shinystan)
launch_shinystan(fit_rstan)

# sf <- rstan::read_stan_csv(fit_cmd$output_files())
# launch_shinystan(sf)

# ---- quantities of interest ----

# as draws matrix from rstan (includes lp__ column)
beta_tilde_raw <- posterior::as_draws_matrix(fit_rstan, regex_pars = "beta")
head(beta_tilde_raw)

# drop the unnecessary cols (keep only first five betas); note draw id is in row names
beta_tilde <- as.matrix(beta_tilde_raw)[, 1:5]
head(beta_tilde)

# compute a first difference via invariance principle
X_lo <- cbind(
  "constant"   = 1,   # intercept
  "rs_age"     = -0.5,# 1 SD above avg -- see ?arm::rescale
  "rs_educate" = 0,
  "rs_income"  = 0,
  "white"      = 1    # white indicator = 1 
)

# modify rs_age for high case
X_hi <- X_lo
X_hi[, "rs_age"] <- 0.5  # 1 SD below avg

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
