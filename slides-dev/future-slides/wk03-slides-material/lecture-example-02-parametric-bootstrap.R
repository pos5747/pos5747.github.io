pi_hat <- 8/150  # ml estimate from observed data

n_bs <- 2000
bs_est <- numeric(n_bs)  # a container for the estimates
for (i in 1:n_bs) {
  bs_y <- rbinom(150, size = 1, prob = 8/150)
  bs_est[i] <- mean(bs_y)
}

print(sd(bs_est), digits = 2)  # se estimate
print(quantile(bs_est, probs = c(0.05, 0.95)), digits = 2)  # 90% ci