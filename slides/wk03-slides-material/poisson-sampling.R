# illustrate the sampling distribution of our poisson estimator

lambda <- 3
N <- 100  # sample size
n_reps <- 1000  # number of imagined repeated studies

lambda_hat <- numeric(n_reps)  # a (now empty) container
for (i in 1:n_reps) {
  y <- rpois(N, lambda = lambda)  # simulate a dataset (or "study")
  lambda_hat[i] <- mean(y)
}

mean(lambda_hat) - lambda  # mc estimate of bias
sd(lambda_hat)  # mc estimate of se
hist(lambda_hat, breaks = 100)