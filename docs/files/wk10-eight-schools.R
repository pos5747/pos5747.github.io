# load packages
library(tidyverse)
library(cmdstanr)
library(tidybayes)

# eight-schools data; from my 2nd ed. of BDA on p. 140
est <- c(28, 8, -3, 7, -1, 1, 18, 12)
se_est <- c(15, 10, 16, 11, 9, 11, 10, 18)
J <- length(est)

# stan model
stan_code <- "
data {
  int<lower=1> J;             // number of schools (J = 8)
  vector[J] est;              // estimated (or observed) treatment effect estimates for each school
  vector<lower=0>[J] se_est;  // estimated (or observed) standard errors for each school
}

parameters {
  real mu;              // typical or average treatment effect across the 8 schools
  real<lower=0> sigma;  // standard deviation of school treatment effect around mu
  vector[J] theta;      // *actual* treatment effect in each school
}

model {
  // --- priors ---
  mu  ~ normal(0, 1000);   // uninformative prior on mu
  sigma ~ cauchy(0, 20);    // half-cauchy prior on sigma; sd(est) is about 10

  // --- hierarchical bit ---
  theta ~ normal(mu, sigma);  // actual effect ~ N(mu, sigma)

  // --- likelihood ---
  est ~ normal(theta, se_est);  // observed est_j ~ N(theta_j, est_se_j)
}
"

# put data into list to give to Stan
data_list <- list(J = J, est = est, se_est = se_est)

# compile the model with cmdstanr
model <- cmdstan_model(write_stan_file(stan_code))

# sample
fit <- model$sample(
  data = data_list,
  seed = 123,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 2000,
  iter_sampling = 2000
)

# quick look; check rhat, ess, and the hmc diagnostics
fit$summary(variables = c("mu", "sigma", "theta"))
fit$diagnostic_summary()

# --- plot observed estimates and posteriors of theta

# observed data
obs <- data.frame(school = factor(1:J),
                  est = est,
                  se_est = se_est)

# extract simulations of theta_j into a nice data frame
theta_draws <- fit |>
  spread_draws(theta[school]) |>
  # reorder school by observed estimate
  ungroup() |>
  mutate(school = factor(school)) |>
  left_join(obs) |>
  mutate(school = reorder(school, est)) |>
  glimpse()

# make plot
ggplot() +
  # posterior of theta
  stat_eye(
    data = theta_draws,
    aes(x = theta, y = school),
  ) +
  # observed estimates
  geom_pointrange(
    data = obs,
    aes(y = school, x = est, xmin = est - se_est, xmax = est + se_est),
    color = "red", linewidth = 0.5
  ) +
  labs(
    x = "Treatment Effect",
    y = "School",
    title = "Eight Schools",
    subtitle = "Eye shows the posterior distribution;\npoint and line shows observed estimate and SE"
  ) +
  theme_minimal()
