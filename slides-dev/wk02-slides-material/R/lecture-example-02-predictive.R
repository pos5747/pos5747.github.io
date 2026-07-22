# Predictive distribution for the Poisson model of Holland's (2015)
# enforcement operations (the "Continue in R" Gist:
# https://gist.github.com/carlislerainey/c3cb055454a076ab49ebca1eca6b0c0c).

# load packages
library(tidyverse)
library(patchwork)

# load holland's data (once per session)
holland2015 <- crdata::holland2015 |>
  glimpse()

# get data for lima
y <- holland2015$operations[holland2015$city == "lima"]

# compute ml estimates of poisson parameter
ml_est <- mean(y)
print(ml_est, digits = 3)

# simulate from predictive distribution
n <- length(y)
y_pred <- rpois(n, lambda = ml_est)
print(y_pred[1:10])  # print first 10 simulated values
print(y[1:10])  # print first 10 observed values


# compare histograms of observed and simulated data sets
gg1 <- ggplot() + geom_histogram(aes(x = y)) + xlim(min(y), max(y))
gg2 <- ggplot() + geom_histogram(aes(x = y_pred)) + xlim(min(y), max(y))
gg1 / gg2 +  plot_layout(axes = "collect")  # stitch these together w/ patchwork


## Create 5 simulated data sets
## ----

# create observed data set
observed_data <- tibble(operations = y, type = "observed") %>%
  glimpse()

# simulate five fake data sets
sim_list <- list()
for (i in 1:5) {
  y_pred <- rpois(n, lambda = ml_est)
  sim_list[[i]] <- tibble(operations = y_pred,
                          type = paste0("simulated #", i))
}

# combine the fake and observed data sets
gg_data <- bind_rows(sim_list) %>%
  bind_rows(observed_data) %>%
  glimpse()

# histogram: plot the observed and fake data sets
ggplot(gg_data, aes(x = operations)) +
  geom_histogram() +
  facet_wrap(vars(type))

# ecdf: make plots of ecdf
ggplot(gg_data, aes(x = operations)) +
  stat_ecdf() +
  facet_wrap(vars(type))

# ecdf: put the ecdfs on the same plot
gg_data2 <- gg_data |>
  separate(type, into = c("type", "version")) |>
  glimpse()
ggplot(gg_data2, aes(x = operations, color = type, group = version)) +
  stat_ecdf()
