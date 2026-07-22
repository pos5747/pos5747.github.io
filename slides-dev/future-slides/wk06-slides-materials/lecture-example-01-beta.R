# prior
alpha_star <- 3
beta_star <- 15

# data
N <- 150
k <- 8

# posterior
alpha_prime <- alpha_star + k
beta_prime <- beta_star + (N - k)

# plot posterior pdf
library(ggplot2)
ggplot() +
  xlim(0, 1) +
  stat_function(fun = dbeta, n = 1001,
                args = list(shape1 = alpha_prime, 
                            shape2 = beta_prime)) +
  labs(x = "pi",
       y = "posterior density")

# find posterior mean
alpha_prime/(alpha_prime + beta_prime)

# find posterior median
qbeta(0.5, shape1 = alpha_prime, shape2 = beta_prime)

# find posterior mode
(alpha_prime - 1)/(alpha_prime + beta_prime - 2)

# 90% equal-tailed credible interval
qbeta(c(0.05, 0.95), shape1 = alpha_prime, shape2 = beta_prime)

# posterior simulation
pi_tilde <- rbeta(10000, shape1 = alpha_prime, shape2 = beta_prime)
oof_tilde <- (1 - pi_tilde)/pi_tilde

mean(oof_tilde)  # correct
(1 - mean(pi_tilde))/mean(pi_tilde)  # NOT correct

