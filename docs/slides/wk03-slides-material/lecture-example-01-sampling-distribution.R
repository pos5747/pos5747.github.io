# illustrate the sampling distribution of our poisson estimator

lambda <- 3
N <- 100  # sample size
n_reps <- 1000  # number of imagined repeated studies

lambda_hat <- numeric(n_reps)  # a (now empty) container
for (i in 1:n_reps) {
  y <- rpois(N, lambda = lambda)  # simulate a dataset (or "study")
  lambda_hat[i] <- mean(y)  # compute ml estimate
  
  # slowly print first 10 simulated studies
  if (i <= 7) {
    Sys.sleep(0.5)
    cat(paste0("Doing the study... "))    
    Sys.sleep(2.5)
    cat(paste0("done.\n\nStudy ", i, ": lambda-hat = ", round(lambda_hat[i], 2), "\n\n"))    
  }
  if (i == 7) cat("[Delays are fake. Computers are fast. Only first 7 shown; we did a bunch more as well.]\n\n")
}

mean(lambda_hat) - lambda  # mc estimate of bias
sd(lambda_hat)  # mc estimate of se
hist(lambda_hat, breaks = 100)
