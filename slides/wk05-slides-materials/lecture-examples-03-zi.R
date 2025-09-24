# load package
library(tidyverse)
library(marginaleffects)
library(modelsummary)
library(glmmTMB)

# load data for santiago
sant <- crdata::holland2015 |> 
  filter(city == "santiago") |>
  glimpse()

# formula corresponds to model 1 for each city in holland (2015) table 2
f <- operations ~ lower + vendors + budget + population

# ---- count regressions ----

# poisson
pois_fit <- glm(f, family = poisson, data = sant)

# negative binomial
nb_fit <- MASS::glm.nb(f, data = sant)

# zero-inflated NB, w/ *constant* zero inflation
zinb0_fit <- glmmTMB(f, ziformula = ~ 1, data = sant, family = nbinom2)

# zero-inflated NB, w/ zero inflation as a function of the covariates
zinb_fit <- glmmTMB(f, ziformula = ~ lower + vendors + budget + population, data = sant, family = nbinom2)

# ---- count regressions ----

# create table
BIC(pois_fit, nb_fit, zinb0_fit, zinb_fit) |>
  mutate(diff_min = BIC - min(BIC),
         post_prob = round(exp(-0.5*diff_min)/sum(exp(-0.5*diff_min)), 3)) |>
  tt(rownames = TRUE, digits = 2)

# ---- predictive distributions ----

# most preferred model (zinb w/ covariates)
zinb_sims <- simulate(zinb_fit, nsim = 15)
bind_cols(sant, zinb_sims) |>
  pivot_longer(cols = c(operations, starts_with("sim_"))) |>
  separate(name, into = c("type", "sim_id"), sep = "_", remove = FALSE) |>
  ggplot(aes(x = value)) + 
  facet_wrap(vars(name)) +
  geom_histogram(center = 0, binwidth = 1)

# least preferred model (poisson w/ covariates)
pois_sims <- simulate(pois_fit, nsim = 15)
bind_cols(sant, pois_sims) |>
  pivot_longer(cols = c(operations, starts_with("sim_"))) |>
  separate(name, into = c("type", "sim_id"), sep = "_", remove = FALSE) |>
  ggplot(aes(x = value)) + 
  facet_wrap(vars(name)) +
  geom_histogram(center = 0, binwidth = 1)
