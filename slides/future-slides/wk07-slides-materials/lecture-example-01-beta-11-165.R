# ---- setup ----

# nice printing
options(digits = 5)

# load packages
library(tidyverse)
library(posterior)
library(foreach)
library(doParallel)
library(scales)
library(prettyunits)

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

# ---- beta(11, 165) posterior -----

# log-posterior distribution
logf <- function(p) {
  ifelse(p <= 0 | p >= 1, 
         -Inf, 
         dbeta(p, 11, 165, log = TRUE))
}

# run metrop
m <- metrop(
  logf, 
  theta_start = 0.5, 
  S = 10000, 
  tau = 0.1, 
  progress_bar = TRUE)

# closed-form vs simulation mean
11 / (11 + 165)
mean(m$samples)

# ---- plotting the samples ----

par(mfrow = c(2, 2))
hist(m$samples, main = "All 10,000 samples", xlab = "p")
plot(m$samples, type = "l", main = "All 10,000 samples", ylab = "p", xlab = "Iteration")
plot(m$samples[1:100], type = "l", main = "First 100 samples", ylab = "p", xlab = "Iteration")
plot(m$samples[1001:1100], type = "l", main = "Samples 1,001–1,100", ylab = "p", xlab = "Iteration")

# ---- burn-in ----

# discard early samples that depend on starting value
mean(m$samples[5001:10000, 1])

# ---- rhat; short run ----

# 25 iterations
m1 <- metrop(logf, theta_start = 0.01, S = 25)
m2 <- metrop(logf, theta_start = 0.25, S = 25)
m3 <- metrop(logf, theta_start = 0.75, S = 25)
m4 <- metrop(logf, theta_start = 0.99, S = 25)

# combine samples
matrix_of_chains <- cbind(
  m1$samples[, 1],
  m2$samples[, 1],
  m3$samples[, 1],
  m4$samples[, 1]
)

# compute R-hat
posterior::rhat(matrix_of_chains)

# plot chains
colnames(matrix_of_chains) <- paste("Chain", 1:ncol(matrix_of_chains))
gg_df <- matrix_of_chains |>
  as_tibble() |>
  mutate(Iteration = 1:n()) |>
  pivot_longer(cols = `Chain 1`:`Chain 4`, names_to = "Chain", values_to = "Sample") |>
  separate(Chain, into = c("tmp", "Chain Number"), remove = FALSE) |>
  mutate(`Chain Number` = as.numeric(`Chain Number`),
         Chain = reorder(Chain, `Chain Number`, ordered = TRUE))
ggplot(gg_df, aes(x = Iteration, y = Sample, group = Chain, color = Chain)) +
  geom_line() +
  labs(title = "Metropolis samples (25 iters per chain)",
       subtitle = "Short runs from overdispersed starts show strong start-value dependence") +
  theme_minimal()


# ---- rhat; long run ----

# 25k iterations
m1 <- metrop(logf, theta_start = 0.01, S = 25000)
m2 <- metrop(logf, theta_start = 0.25, S = 25000)
m3 <- metrop(logf, theta_start = 0.75, S = 25000)
m4 <- metrop(logf, theta_start = 0.99, S = 25000)

# combine samples
matrix_of_chains <- cbind(
  m1$samples[10001:25000, 1],
  m2$samples[10001:25000, 1],
  m3$samples[10001:25000, 1],
  m4$samples[10001:25000, 1]
)

# compute R-hat
posterior::rhat(matrix_of_chains)

# plot chains
colnames(matrix_of_chains) <- paste("Chain", 1:ncol(matrix_of_chains))
gg_df <- matrix_of_chains |>
  as_tibble() |>
  mutate(Iteration = 1:n()) |>
  pivot_longer(cols = `Chain 1`:`Chain 4`, names_to = "Chain", values_to = "Sample") |>
  separate(Chain, into = c("tmp", "Chain Number"), remove = FALSE) |>
  mutate(`Chain Number` = as.numeric(`Chain Number`),
         Chain = reorder(Chain, `Chain Number`, ordered = TRUE))
ggplot(gg_df, aes(x = Iteration, y = Sample, group = Chain, color = Chain)) +
  geom_line() +
  labs(title = "Metropolis samples (25000 iters per chain)",
       subtitle = "Short runs from overdispersed starts show strong start-value dependence") +
  theme_minimal()

# ---- parallel computation ----

# number of cores
parallel::detectCores(logical = FALSE)

# set up 10 cores
cl <- makeCluster(10)
registerDoParallel(cl)

# run 10 chains in parallel
starting_values <- seq(0.05, 0.95, length.out = 10)
matrix_of_chains <- foreach(s = starting_values, .combine = cbind) %dopar% {
  m <- metrop(logf, theta_start = s, S = 250)
  m$samples
}
stopCluster(cl)

# plot chains
colnames(matrix_of_chains) <- paste("Chain", 1:ncol(matrix_of_chains))
gg_df <- matrix_of_chains |>
  as_tibble() |>
  mutate(Iteration = 1:n()) |>
  pivot_longer(cols = `Chain 1`:`Chain 10`, names_to = "Chain", values_to = "Sample") |>
  separate(Chain, into = c("tmp", "Chain Number"), remove = FALSE) |>
  mutate(`Chain Number` = as.numeric(`Chain Number`),
         Chain = reorder(Chain, `Chain Number`, ordered = TRUE))
ggplot(gg_df, aes(x = Iteration, y = Sample, group = Chain, color = Chain)) +
  geom_line() +
  labs(title = "Metropolis samples (250 iters per chain)",
       subtitle = "Short runs from overdispersed starts show strong start-value dependence") +
  theme_minimal()

# ---- ess ----

dim(matrix_of_chains)  # rows = iterations, cols = chains
posterior::ess_bulk(matrix_of_chains)
posterior::ess_tail(matrix_of_chains)

# ---- developing our tuning intuition ----
m1 <- metrop(logf, theta_start = 0.99, S = 1000, tau = 0.1)
m2 <- metrop(logf, theta_start = 0.99, S = 1000, tau = 0.01)
m3 <- metrop(logf, theta_start = 0.99, S = 1000, tau = 0.001)
m4 <- metrop(logf, theta_start = 0.99, S = 1000, tau = 3)

par(mfrow = c(2, 2))
plot(m1$samples, type = "l", main = "tau = 0.1 (nice)", ylim = c(0, 1), ylab = "p", xlab = "iter")
plot(m2$samples, type = "l", main = "tau = 0.01 (accept too often)", ylim = c(0, 1), ylab = "p", xlab = "iter")
plot(m3$samples, type = "l", main = "tau = 0.001 (way too small)", ylim = c(0, 1), ylab = "p", xlab = "iter")
plot(m4$samples, type = "l", main = "tau = 3 (accept too rarely)", ylim = c(0, 1), ylab = "p", xlab = "iter")


# ------------------------------------------------------------------------------
# MCMC
# ------------------------------------------------------------------------------
# MCMC offers a powerful and general way to sample from an
# unnormalized (log-)posterior. The Metropolis algorithm is one such
# method. Hamiltonian Monte Carlo (HMC), implemented in Stan, is even
# better.
#
# ------------------------------------------------------------------------------
# R-hat and burn-in
# ------------------------------------------------------------------------------
# The first MCMC samples are highly dependent on the starting values.
# Because of this, you need to:
#   * Discard the samples from a burn-in period.
#   * Run multiple chains and check that R-hat is less than 1.01.
#
# ------------------------------------------------------------------------------
# ESS and large samples
# ------------------------------------------------------------------------------
# MCMC samples are dependent on previous samples. Because of this,
# you need to:
#   * Generate more samples than you would need if they were
#     independent.
#   * Use ESS (Effective Sample Size) to understand your effective
#     number of independent draws.
# ------------------------------------------------------------------------------
