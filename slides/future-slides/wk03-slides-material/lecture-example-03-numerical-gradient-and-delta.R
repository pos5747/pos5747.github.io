
# load packages
library(tidyverse)
library(numDeriv)   # for numerical gradients

# get the data ready
# ------------------

# nominate data I use for teaching
nom <- read_csv("https://pos3713ri.github.io/data/nominate.csv") |>
  glimpse()

# y: ideology scores for Ds in the 117th congress
y <- nom$ideology[nom$party == "Republican" & nom$congress == 117]

# histogram
hist(y)

# use normal model; estimate mu and sigma w/ optim()
# --------------------------------------------------

# log-likelihood function (using dnorm!)
normal_ll_fn <- function(theta, y) { 
  mu <- theta[1] 
  sigma  <- theta[2] 
  ll <- sum(dnorm(y, mean = mu, sd = sigma, log = TRUE))
  return(ll)
}

# function to fit beta model 
est_normal <- function(y) {
  # use optim; compute hessian
  est <- optim(
    par     = c(0, 1),  # decent starting values for the problem below
    fn      = normal_ll_fn,
    y       = y,
    control = list(fnscale = -1),  
    method  = "BFGS",
    hessian = TRUE            
  ) 
  
  # compute an estimate of covariance matrix (slowly, this first time)
  info_obs <- -est$hessian  # notice negative sign
  var_hat  <- solve(info_obs) 
  
  # check convergence; print warning if needed
  if (est$convergence != 0) print("Model did not converge!")
  
  # return list of elements
  res <- list(theta_hat = est$par, 
              var_hat   = var_hat) 
  return(res)
}


fit <- est_normal(y)
fit$theta_hat  # parameter estimates
fit$var_hat  # covariance matrix estimates

# convert estimates of mu and sigma to estimate of fraction greater than 1/2
# --------------------------------------------------------------------------

# create the function tau
tau_fn <- function(theta) {  
  mu <- theta[1]
  sigma <- theta[2]
  1 - pnorm(0.75, mean = mu, sd = sigma)
}

# estimate tau
tau_fn(fit$theta_hat)

# compute the gradient of tau
grad <- grad(func = tau_fn, x = fit$theta_hat)

# delta method
var_hat_mu <- grad %*% fit$var_hat %*% grad  # R transposes grad as needed
var_hat_mu

# sqrt of variance to find SE
se_hat_mu <- sqrt(var_hat_mu) 
se_hat_mu

# use mc simualtion to evaluate this ci
# --------------------------------------------------------------------------

# true values
N <- 250
true_mu <- 0.50
true_sigma <- 0.25
true_tau <- tau_fn(c(true_mu, true_sigma))

# number of MC simulations (i.e., repeated trials)
n_mc_sims <- 1000

# containers for lower and upper bounds of 90% cis
lwr <- numeric(n_mc_sims)
upr <- numeric(n_mc_sims)

# mc simulations
for (i in 1:n_mc_sims) {
  y_sim <- rnorm(N, mean = true_mu, sd = true_sigma)
  fit_sim <- est_normal(y_sim)
  tau_hat_sim <- tau_fn(fit_sim$theta_hat)
  grad_sim <- grad(func = tau_fn, x = fit_sim$theta_hat)
  se_sim <- sqrt(grad_sim %*% fit_sim$var_hat %*% grad_sim) 
  lwr[i] <- tau_hat_sim - 1.64*se_sim
  upr[i] <- tau_hat_sim + 1.64*se_sim
}

# combine results into a data frame
mc_sims <- tibble(iteration = 1:n_mc_sims,
                  lwr, upr) %>%
  mutate(captured = lwr < true_tau & upr > true_tau)

# compute the proportion of simulations that capture the parameter
mean(mc_sims$captured)

# compute mc se
sd(mc_sims$captured)/sqrt(n_mc_sims)

