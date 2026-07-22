# Reproduce Clark and Golder's (2006) 1946-2000 Established Democracies
# model (Table 2, p. 698; specification in eq. 4, p. 695), with HC1
# cluster-robust standard errors. The load-cg-data snippet is shown on the
# slide; the model fitting is live-coded in class.

## ---- slide: load-cg-data ----

# run just once, then delete
devtools::install_github("carlislerainey/crdata")

# load packages
library(tidyverse)
library(sandwich)  # for robust SEs

# load Clark and Golder's data
cg <- crdata::cg2006  # from my data package

# quick look at variables and their names
glimpse(cg)

## ---- slide: fit-cg-model ----

# reproduce regression
f <- enep ~ eneg*log(average_magnitude) + eneg*upper_tier + en_pres*proximity
fit <- lm(f, data = cg)

# grab estimated coefs and var matrix
beta_hat <- coef(fit)
V_hat <- vcovCL(fit, cluster = ~ country, type = "HC1")

# compute the standard errors
se_hat <- sqrt(diag(V_hat))
