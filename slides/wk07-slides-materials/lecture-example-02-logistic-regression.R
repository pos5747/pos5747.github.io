# ---- setup ----

# nice printing
options(digits = 3)

# load packages
library(tidyverse)
library(posterior)
library(foreach)
library(doParallel)
library(hrbrthemes)
library(patchwork)
library(marginaleffects)

# ---- metropolis ----

# create function
metrop <- function(logf, theta_start, S = 10000, tau = 0.1, progress_bar = FALSE, ...) {
  # record start time
  start_time <- Sys.time()
  
  # initialize matrix of samples with starting values
  k <- length(theta_start)
  samples <- matrix(NA_real_, nrow = S, ncol = k)
  samples[1, ] <- theta_start
  n_accepted <- 0
  
  # optionally initialize progress bar
  if (progress_bar) {
    pb <- txtProgressBar(min = 0, max = S, style = 3)
  }
  
  # proceed with algorithm
  for (s in 2:S) {
    # extract current location
    current <- samples[s - 1, ]
    
    # generate symmetric random-walk proposal
    proposed_move <- runif(k, -tau, tau)
    proposal <- current + proposed_move 
    
    # acceptance step
    delta  <- logf(proposal, ...) - logf(current, ...)
    if (delta > 0) {
      accept <- TRUE
    } else {
      accept <- (log(runif(1)) <= delta)
    }
    
    # update samples
    if (accept) {
      samples[s, ] <- proposal
      n_accepted <- n_accepted + 1
    } else {
      samples[s, ] <- current
    }
    
    # update progress bar occasionally
    if (progress_bar && (s %% (S / 100) == 0 || s == S)) {
      setTxtProgressBar(pb, s)
    }
  }
  
  # close progress bar if used
  if (progress_bar) close(pb)
  
  # print summary report
  message(
    paste0(
      "💪 Successfully generated ", scales::comma(S), " dependent samples! 🎉\n\n",
      "✅ Accepted moves: ", scales::comma(n_accepted), "\n",
      "﹪ Acceptance rate: ", scales::percent(n_accepted / (S - 1), accuracy = 1),
      " (tune tau so that acceptance rate is about 20%-50%).\n",
      "⏰ Total time: ", prettyunits::pretty_dt(Sys.time() - start_time),  "\n",
      "🧠 Reminder: if a proposal is not accepted, the previous sample is reused. This makes the samples depending on starting values and each other. Discard initial samples, use R-hat to assess convergence, and use ESS to assess effective sample size."
    )
  )
  
  list(
    prop_accepted = n_accepted / (S - 1),
    samples = samples
  )
}

# ---- data ----

# load only the turnout data frame
turnout <- ZeligData::turnout  # see ?ZeligData::turnout for details

# fit logit model 
rs <- function(x) { arm::rescale(x) }  # make an alias to print nicely

# bug??? for some reason this fails with comparisons()
f <- vote ~ rs(age) + rs(educate) + rs(income) + race  # rescaling so that coefs are similar makes everything nicer

# just have to hard-code the rescaled variables, which is not optimal
turnout <- turnout |>
  mutate(across(age:income, rs, .names = "rs_{.col}")) |>
  glimpse()
f <- vote ~ rs_age + rs_educate + rs_income + race

fit <- glm(f, family = binomial, data = turnout)

# print estimates
arm::display(fit, digits = 4)

# ---- log-posterior ----

# make X and y
mf <- model.frame(f, data = turnout)
X <- model.matrix(f, data = mf)
y <- model.response(mf)

# ❌ correct, but unstable, log unnormalized posterior 
log_posterior <- function(beta, y, X) {
  linpred <- X %*% beta
  p <- plogis(linpred)
  sum(dbinom(y, size = 1, prob = plogis(linpred), log = TRUE))  # occassionally makes NaN, b/c 0*Inf
}

# ✅ same unnormalized log posterior, but avoid 0*Inf instability
log_posterior <- function(beta, y, X) {
  linpred <- drop(X %*% beta)
  log1pexp <- ifelse(linpred > 0, linpred + log1p(exp(-linpred)), log1p(exp(linpred)))
  sum(y * linpred - log1pexp)
}

# ---- running the algorithm ----

# sample with metropolis
S <- 10000
m1 <- metrop(log_posterior, S = S, tau = 0.1, theta_start = rep(-2, ncol(X)), y = y, X = X, progress_bar = TRUE)
m2 <- metrop(log_posterior, S = S, tau = 0.1, theta_start = rep(-1, ncol(X)), y = y, X = X, progress_bar = TRUE)
m3 <- metrop(log_posterior, S = S, tau = 0.1, theta_start = rep(1, ncol(X)), y = y, X = X, progress_bar = TRUE)
m4 <- metrop(log_posterior, S = S, tau = 0.1, theta_start = rep(2, ncol(X)), y = y, X = X, progress_bar = TRUE)

# ---- rhat and ess; intercept ----

# first parameter (intercept) and use first 100,000 as burn-in
start <- .2*S + 1
end <-   S
matrix_of_chains <- cbind(
  m1$samples[start:end, 2],
  m2$samples[start:end, 2],
  m3$samples[start:end, 2],
  m4$samples[start:end, 2]
)

# compute r-hat (for intercept)
posterior::rhat(matrix_of_chains)

# compute ess (for intercept)
posterior::ess_bulk(matrix_of_chains)
posterior::ess_tail(matrix_of_chains)

# ---- plots ----

colnames(matrix_of_chains) <- paste("Chain", 1:ncol(matrix_of_chains))
gg_df <- matrix_of_chains |>
  as_tibble() |>
  mutate(Iteration = 1:n()) |>
  pivot_longer(cols = `Chain 1`:`Chain 4`, names_to = "Chain", values_to = "Sample") |>
  separate(Chain, into = c("tmp", "Chain Number"), remove = FALSE) |>
  mutate(`Chain Number` = as.numeric(`Chain Number`),
         Chain = reorder(Chain, `Chain Number`, ordered = TRUE))
gg1 <- ggplot(gg_df, aes(x = Iteration, y = Sample, color = Chain)) +
  geom_line() +
  facet_wrap(vars(Chain))
gg2 <- ggplot(gg_df, aes(x = Sample, color = Chain)) +
  geom_density()
gg1 + gg2

# ---- posterior mean and cd ----

# compare to arm::display(fit)
mean(matrix_of_chains)
sd(matrix_of_chains)

arm::display(fit)

# ---- quantities of interest ----

# make X_lo
X_lo <- cbind(
  "constant" = 1, # intercept
  "rs_age" = -0.5, # 1 SD below avg -- see ?arm::rescale
  "rs_educate" = 0,
  "rs_income" = 0,
  "white" = 1 # white indicator = 1 
)

# make X_hi by modifying the relevant value of X_lo
X_hi <- X_lo
X_hi[, "rs_age"] <- 0.5  # 1 SD above avg

# function to compute first difference
fd_fn <- function(beta, hi, lo) {
  plogis(hi%*%beta) - plogis(lo%*%beta)
}

# put the simulations of the coefficients into a matrix
# note 1: each row is one beta-tilde
# note 2: we're discarding the first samples (start and end defined above)
# note 3: we're just stacking the chains on top of each other
beta_tilde <- rbind(
  m1$samples[start:end, ], # chain 1, minus burn-in
  m2$samples[start:end, ], # chain 2, minus burn-in
  m3$samples[start:end, ], # chain 3, minus burn-in
  m4$samples[start:end, ]  # chain 4, minus burn-in
)

# transform simulations of coefficients into simulations of first-difference
# note 1: for clarity, just do this one simulation at a time,
# note 2: i indexes the simulations
fd_tilde <- numeric(nrow(beta_tilde))  # container
for (i in 1:nrow(beta_tilde)) {
  fd_tilde[i] <- fd_fn(beta_tilde[i, ], hi = X_hi, lo = X_lo)
}

# posterior mean
mean(fd_tilde)

# ---- quantities of interest (glm() + {marginaleffects}) ----

# compute qi; rs(age), etc, not working---not sure why
comparisons(fit, variables = list(rs_age = c(-0.5, 0.5)), 
            newdata = datagrid(grid_type = "mean_or_mode"))
