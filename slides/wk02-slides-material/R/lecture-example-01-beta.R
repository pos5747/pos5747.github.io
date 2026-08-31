# Beta model of batting averages, fit with optim(). Follows the lecture
# build-up: write the log-likelihood by hand, then the dbeta() shortcut,
# then optim(), then a reusable est_beta() — then apply it to Lahman's
# baseball data (the "Continue in R" Gist:
# https://gist.github.com/carlislerainey/17f281357ffd91972dce3dc670f35a37).

# load packages
library(tidyverse)
library(Lahman)  # data from Lahman's baseball database

## ---- slide: ll-fn-manual ----

# manually typing log-likelihood
ll_fn <- function(theta, y) {
  alpha <- theta[1]
  beta <- theta[2]
  ll <- (alpha - 1)*sum(log(y)) + (beta - 1)*sum(log(1 - y)) -
    length(y)*log(beta(alpha, beta))
  return(ll)
}

## ---- slide: ll-fn-dbeta ----

# using dbeta shortcut (good!)
ll_fn <- function(theta, y) {
  alpha <- theta[1]
  beta <- theta[2]
  ll <- sum(dbeta(y, shape1 = alpha, shape2 = beta, log = TRUE))
  return(ll)
}

## ---- slide: optim-call ----

# use optim()
est <- optim(par = c(2, 2),
             fn = ll_fn,
             y = y,
             control = list(fnscale = -1),
             method = "Nelder-Mead")

## ---- slide: est-beta-fn ----

# make function that fits beta model
est_beta <- function(y) {
  est <- optim(par = c(2, 2), fn = ll_fn, y = y,
               control = list(fnscale = -1),
               method = "BFGS") # for >1d problems
  if (est$convergence != 0) print("Model did not converge!")
  res <- list(est = est$par)
  return(res)
}

# fit beta model
ml_est <- est_beta(y)
print(ml_est, digits = 3)

## ---- slide: batting-average-application ----

# create data frame with batting average
bstats <- battingStats() |>
  filter(yearID == 2023) |>  # data from 2023
  filter(AB >= 100) |>  # players with at least 100 at-bats
  select(player_id = playerID, batting_average = BA) |>
  arrange(-batting_average) |>
  na.omit() |>
  glimpse()

# plot histogram
hist(bstats$batting_average)

# estimate beta model
theta_hat <- est_beta(bstats$batting_average)
theta_hat

# use invariance property to get mean
theta_hat$est[1]/(theta_hat$est[1] + theta_hat$est[2])

# this is slightly different than the sample avg
mean(bstats$batting_average)
