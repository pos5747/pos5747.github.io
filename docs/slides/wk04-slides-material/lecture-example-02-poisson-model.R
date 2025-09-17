
# ---- fit poisson model with optim() ----

# data; see ?crdata::holland2015
holland <- crdata::holland2015 |>
  filter(city == "santiago")

# formula corresponds to model 1 for each city in holland (2015) table 2
f <- operations ~ lower + vendors + budget + population

# ---- create a function to fit the model ----

# log-likelihood function
poisson_ll <- function(beta, y, X) {
  linpred <- X%*%beta  # perhaps denoted eta
  lambda <- exp(linpred) 
  ll <- sum(dpois(y, lambda = lambda, log = TRUE))
  return(ll)
}

# function to fit model
est_poisson <- function(f, data) {
  
  # make X and y
  mf <- model.frame(f, data = data)
  X <- model.matrix(f, data = mf)
  y <- model.response(mf)
  
  # create starting values
  par_start <- rep(0, ncol(X))
  
  # run optim()
  est <- optim(par_start, 
               fn = poisson_ll, 
               y = y,
               X = X,
               hessian = TRUE, # for SEs!
               control = list(fnscale = -1),
               method = "BFGS") 
  
  # check convergence; print warning if not
  if (est$convergence != 0) print("Model did not converge!")
  
  # create list of objects to return
  res <- list(beta_hat = est$par,
              var_hat = solve(-est$hessian))
  
  # return the list
  return(res)
}

# fit model
fit <- est_poisson(f, data = holland)
print(fit, digits = 2)  # print estimates w/ reasonable digits

# ---- compute the expected value given X_c ----

# create chosen values for X
# note 1: naming columns helps a bit later
# note 2: can also do with f, model.matrix(..., newdata = ...)
X_c <- cbind(
  "constant" = 1, # intercept
  "lower"      = median(holland$lower), 
  "vendors"    = median(holland$vendors),
  "budget"     = median(holland$budget),
  "population" = median(holland$population)
)

# function to compute qi
ev_fn <- function(beta, X) {
  exp(X%*%beta)
}

# invariance property
ev_hat <- ev_fn(fit$beta_hat, X_c)

# delta method
library(numDeriv)  # for grad()
grad <- grad(
  func = ev_fn,     # what function are we taking the derivative of?
  x = fit$beta_hat, # what variable(s) are we taking the derivative w.r.t.?
  X = X_c)          # what other values are needed?
se_ev_hat <- sqrt(grad %*% fit$var_hat %*% grad)

# ---- compute the ev given X_c (w/ range of values) ----

# create chosen values for X
X_c <- cbind(
  "constant" = 1, # intercept
  "lower"      = seq(min(holland$lower), max(holland$lower), by = 1), 
  "vendors"    = median(holland$vendors),
  "budget"     = median(holland$budget),
  "population" = median(holland$population)
)

# containers for estimated quantities of interest and ses
ev_hat <- numeric(nrow(X_c))
se_ev_hat <- numeric(nrow(X_c))

# loop over each row of X_c and compute qi and se
for (i in 1:nrow(X_c)) {   # for the ith row of X...
  # invariance property
  ev_hat[i] <- ev_fn(fit$beta_hat, X_c[i, ])
  # delta method
  grad <- grad(
    func = ev_fn, 
    x = fit$beta_hat, 
    X = X_c[i, ]) 
  se_ev_hat[i] <- sqrt(grad %*% fit$var_hat %*% grad)
}

# put X_c, qi estimates, and se estimates in data frame
qi <- cbind(X_c, ev_hat, se_ev_hat) |>
  data.frame() |>
  glimpse()

# plot
ggplot(qi, aes(x = lower, y = ev_hat, 
               ymin = ev_hat - 1.64*se_ev_hat, 
               ymax = ev_hat + 1.64*se_ev_hat)) + 
  geom_ribbon() + 
  geom_line()

# ---- compute first difference ----

# make X_lo
X_lo <- cbind(
  "constant" = 1, # intercept
  "lower"      = quantile(holland$lower, probs = 0.25), 
  "vendors"    = median(holland$vendors),
  "budget"     = median(holland$budget),
  "population" = median(holland$population)
)

# make X_hi by modifying the relevant value of X_lo
X_hi <- X_lo
X_hi[, "lower"] <- quantile(holland$lower, probs = 0.75) 

# function to compute first difference
fd_fn <- function(beta, hi, lo) {
  exp(hi%*%beta) - exp(lo%*%beta)
}

# invariance property
fd_hat <- fd_fn(fit$beta_hat, X_hi, X_lo)

# delta method
grad <- grad(
  func = fd_fn, 
  x = fit$beta_hat, 
  hi = X_hi,
  lo = X_lo)  
se_fd_hat <- sqrt(grad %*% fit$var_hat %*% grad)

# estimated fd
fd_hat

# estimated se
se_fd_hat

# 90% ci
fd_hat - 1.64*se_fd_hat  # lower
fd_hat + 1.64*se_fd_hat  # upper
