
# load packages
library(survival)

# load data
canc <- survival::cancer |>
  mutate(sex = case_when(sex == 1 ~ "Male",
                         sex == 2 ~ "Female"))
# quick look
glimpse(canc)

# model
f <- Surv(time, status) ~ age + sex + ph.karno

# Exponential
fit_exp <- survreg(f, data = canc, dist = "exp")

# Log-Normal
fit_ln <- survreg(f, data = canc, dist = "lognormal")

# Weibull
fit_wei <- survreg(f, data = canc, dist = "weibull")

# Rayleigh
fit_ray <- survreg(f, data = canc, dist = "rayleigh")

# Extreme Value (Gumbel)
fit_extr <- survreg(f, data = canc, dist = "extreme")

# Gaussian (Normal)
fit_gaus <- survreg(f, data = canc, dist = "gaussian")

# Logistic
fit_logis <- survreg(f, data = canc, dist = "logistic")

# Log-Logistic
fit_llogis <- survreg(f, data = canc, dist = "loglogistic")
