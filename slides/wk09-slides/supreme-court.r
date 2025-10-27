
library(MCMCpack)

data(SupremeCourt)

sc <- SupremeCourt |>
  mutate(case_id = 1:n()) |>
  pivot_longer(Rehnquist:Breyer, 
               names_to = "justice", 
               values_to = "vote") |>
  glimpse()

f <- vote ~ (1 | justice) + (1 | case_id)
fit <- glmer(f, data = sc, family = binomial)

library(dplyr)

library(dplyr)

ranef(fit)$justice |>
  as_tibble(rownames = "justice") |>
  rename(ideal_point = `(Intercept)`) |>
  mutate(
    appointed_by = case_when(
      justice %in% c("Breyer", "Ginsburg") ~ "Clinton",
      justice %in% c("Souter", "Thomas") ~ "Bush (41)",
      justice %in% c("Kennedy", "O'Connor", "Scalia", "Rehnquist") ~ "Reagan",
      justice == "Stevens" ~ "Ford",
      TRUE ~ NA_character_
    )
  ) |>
  arrange(ideal_point)

df

data(SupremeCourt)
posterior1 <- MCMCirt1d(t(SupremeCourt),
                        theta.constraints=list(Scalia="+", Ginsburg="-"),
                        B0.alpha=.2, B0.beta=.2,
                        burnin=500, mcmc=100000, thin=20, verbose=500,
                        store.item=TRUE)
summary(posterior1)
