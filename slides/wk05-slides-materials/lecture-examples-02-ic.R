# load packages
library(tidyverse)
library(tinytable)

# data 
devtools::install_github("jrnold/ZeligData")
turnout <- ZeligData::turnout

# fit model
f <- vote ~ age + educate + income + race
fit <- glm(f, family = binomial, data = turnout)

# fit model
f <- vote ~ (age + educate + income + race)^2
fit_us <- glm(f, family = binomial(), data = turnout)

# create table
BIC(fit, fit_us) |>
  mutate(diff_min = BIC - min(BIC),
         post_prob = exp(-0.5*diff_min)/sum(exp(-0.5*diff_min))) |>
  tt(rownames = TRUE, digits = 3)

# create table
AIC(fit, fit_us) |>
  mutate(diff_min = AIC - min(AIC),
         akaike_weights = exp(-0.5*diff_min)/sum(exp(-0.5*diff_min))) |>
  tt(rownames = TRUE, digits = 3)


