# load package
library(tidyverse)
library(marginaleffects)
library(modelsummary)

# load data for santiago
sant <- crdata::holland2015 |> 
  filter(city == "santiago")

# formula corresponds to model 1 for each city in holland (2015) table 2
f <- operations ~ lower + vendors + budget + population

# nb regression
nb_fit <- MASS::glm.nb(f, data = sant)

# simulate from predictive distribution for nb
nb_sims <- simulate(nb_fit, nsim = 5)

# plot
bind_cols(sant, nb_sims) |>
  pivot_longer(cols = c(operations, starts_with("sim_"))) |>
  separate(name, into = c("type", "sim_id"), sep = "_", remove = FALSE) |>
  ggplot(aes(x = value)) + 
  facet_wrap(vars(name)) +
  geom_histogram(center = 0, binwidth = 1)