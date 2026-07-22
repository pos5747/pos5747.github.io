# standalone_duration_pdfs.R
# ------------------------------------------------------------
# Plot PDFs for multiple survreg distributions at "typical" covariates
# (means for continuous; mode for categorical) using the lung cancer data.
# ------------------------------------------------------------

# --- packages ----
library(tidyverse)
library(survival)
library(hrbrthemes)
library(showtext)

# For log-logistic density helper
if (!requireNamespace("flexsurv", quietly = TRUE)) {
  stop("Please install {flexsurv} for the log-logistic density: install.packages('flexsurv')")
}

# --- fonts/theme (optional, for nice plotting) ---
# download and register Source Sans 3 from Google Fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto()

# --- data prep ----
# Use the built-in 'cancer' dataset from {survival}
# Recode sex to readable labels and ensure factor type
canc <- survival::cancer |>
  mutate(
    sex = case_when(
      sex == 1 ~ "Male",
      sex == 2 ~ "Female",
      TRUE ~ as.character(sex)
    ),
    sex = factor(sex)
  )

# --- model formula including censoring indicator ---
# The 'status' variable in this dataset is coded 1=censored, 2=dead.
f <- Surv(time, status) ~ age + sex + ph.karno

# --- fit survreg models with various distributions ---
fit_exp    <- survreg(f, data = canc, dist = "exp")         # Exponential
fit_ln     <- survreg(f, data = canc, dist = "lognormal")   # Log-Normal
fit_wei    <- survreg(f, data = canc, dist = "weibull")     # Weibull
fit_ray    <- survreg(f, data = canc, dist = "rayleigh")    # Rayleigh
fit_extr   <- survreg(f, data = canc, dist = "extreme")     # Extreme value (Gumbel)
fit_gaus   <- survreg(f, data = canc, dist = "gaussian")    # Gaussian (Normal)
fit_logis  <- survreg(f, data = canc, dist = "logistic")    # Logistic
fit_llogis <- survreg(f, data = canc, dist = "loglogistic") # Log-Logistic

# --- helper: statistical mode for a vector (first tie) ---
stat_mode <- function(x) {
  xt <- table(x)
  names(xt)[which.max(xt)]
}

# --- construct "typical" covariate row: means/mode ---
typical_row <- canc |>
  summarise(
    age = mean(age, na.rm = TRUE),
    sex = factor(stat_mode(sex), levels = levels(canc$sex)),
    ph.karno = mean(ph.karno, na.rm = TRUE)
  )

# --- linear predictors (AFT location) at typical covariates ---
lp_exp    <- as.numeric(predict(fit_exp,    newdata = typical_row, type = "lp"))
lp_ln     <- as.numeric(predict(fit_ln,     newdata = typical_row, type = "lp"))
lp_wei    <- as.numeric(predict(fit_wei,    newdata = typical_row, type = "lp"))
lp_ray    <- as.numeric(predict(fit_ray,    newdata = typical_row, type = "lp"))
lp_ext    <- as.numeric(predict(fit_extr,   newdata = typical_row, type = "lp"))
lp_gau    <- as.numeric(predict(fit_gaus,   newdata = typical_row, type = "lp"))
lp_logis  <- as.numeric(predict(fit_logis,  newdata = typical_row, type = "lp"))
lp_llogis <- as.numeric(predict(fit_llogis, newdata = typical_row, type = "lp"))

# --- extract survreg scale (sigma) ---
sc_exp    <- 1
sc_ln     <- fit_ln$scale
sc_wei    <- fit_wei$scale
sc_ray    <- fit_ray$scale
sc_ext    <- fit_extr$scale
sc_gau    <- fit_gaus$scale
sc_logis  <- fit_logis$scale
sc_llogis <- fit_llogis$scale

# --- time grid over positive support (based on observed range) ---
t_max  <- quantile(canc$time, 0.99, na.rm = TRUE) |> as.numeric()
t_grid <- tibble(t = seq(1e-6, max(10, t_max), length.out = 800))

# --- density functions consistent with survreg AFT parameterization ---

# Exponential: mean mu = exp(lp); rate = 1/mu
dens_exp <- function(t) {
  mu <- exp(lp_exp)
  rate <- 1 / mu
  dexp(t, rate = rate)
}

# Weibull: shape = 1/sigma; scale = exp(lp)
dens_weibull <- function(t) {
  shape <- 1 / sc_wei
  scale <- exp(lp_wei)
  dweibull(t, shape = shape, scale = scale)
}

# Log-Normal: meanlog = lp; sdlog = sigma
dens_lognormal <- function(t) {
  dlnorm(t, meanlog = lp_ln, sdlog = sc_ln)
}

# Log-Logistic: shape = 1/sigma; scale = exp(lp)  (via flexsurv::dllogis)
dens_loglogistic <- function(t) {
  shape <- 1 / sc_llogis
  scale <- exp(lp_llogis)
  flexsurv::dllogis(t, shape = shape, scale = scale)
}

# Gaussian: mean = lp; sd = sigma  (note: support is all real; we plot on t > 0)
dens_gaussian <- function(t) {
  dnorm(t, mean = lp_gau, sd = sc_gau)
}

# Logistic: location = lp; scale = sigma  (support all real; we plot t > 0)
dens_logistic <- function(t) {
  stats::dlogis(t, location = lp_logis, scale = sc_logis)
}

# Extreme value (Gumbel, minimum-type here): loc = lp; scale = sigma
# PDF: (1/scale) * exp( -z - exp(-z) ), z = (t - loc)/scale
dens_extreme <- function(t) {
  z <- (t - lp_ext) / sc_ext
  (1 / sc_ext) * exp(-z - exp(-z))
}

# Rayleigh: scale s = exp(lp); f(t) = t/s^2 * exp( -t^2/(2 s^2) ), t >= 0
dens_rayleigh <- function(t) {
  s <- exp(lp_ray)
  (t / (s^2)) * exp(- t^2 / (2 * s^2))
}

# --- assemble data and plot ---
pdf_df <-
  bind_rows(
    t_grid |> mutate(density = dens_exp(t),         model = "Exponential"),
    t_grid |> mutate(density = dens_weibull(t),     model = "Weibull"),
    t_grid |> mutate(density = dens_lognormal(t),   model = "Log-Normal"),
    t_grid |> mutate(density = dens_loglogistic(t), model = "Log-Logistic"),
    t_grid |> mutate(density = dens_gaussian(t),    model = "Gaussian"),
    t_grid |> mutate(density = dens_logistic(t),    model = "Logistic"),
    t_grid |> mutate(density = dens_extreme(t),     model = "Extreme Value (Gumbel)"),
    t_grid |> mutate(density = dens_rayleigh(t),    model = "Rayleigh")
  ) |>
  mutate(density = pmax(density, 0))  # numerical guard

ggplot(pdf_df, aes(x = t, y = density)) +
  geom_line() +
  facet_wrap(~ model, scales = "free_y", ncol = 3) +
  labs(
    x = "t (time in days)",
    y = "PDF",
    title = "Predictive PDFs",
    subtitle = paste0(
      "age = ", round(typical_row$age, 1),
      ", sex = ", as.character(typical_row$sex),
      ", ph.karno = ", round(typical_row$ph.karno, 1)
    )
  ) +
  theme_ipsum(base_family = "Source Sans 3")
ggsave(filename = "slides/wk06-slides-materials/duration-distributions.pdf", 
       height = 3, width = 4, scale = 3)

# --- compute BIC and posterior probabilities ---
bic_tbl <- BIC(fit_exp, fit_ln, fit_wei, fit_ray,
               fit_extr, fit_gaus, fit_logis, fit_llogis) |>
  as_tibble(rownames = "model") |>
  mutate(
    diff_min = BIC - min(BIC),
    post_prob = exp(-0.5 * diff_min) / sum(exp(-0.5 * diff_min)),
    clean_model = recode(model,
                         "fit_exp"    = "Exponential",
                         "fit_ln"     = "Log-Normal",
                         "fit_wei"    = "Weibull",
                         "fit_ray"    = "Rayleigh",
                         "fit_extr"   = "Extreme Value (Gumbel)",
                         "fit_gaus"   = "Gaussian",
                         "fit_logis"  = "Logistic",
                         "fit_llogis" = "Log-Logistic"
    )
  ) |>
  mutate(post_prob_rounded = scales::percent(post_prob, accuracy = 0.1)) |>
  arrange(BIC) |>
  select(Model = clean_model, k = df, BIC = BIC, `Post. Prob.` = post_prob_rounded)

library(tinytable)
tt(bic_tbl)
