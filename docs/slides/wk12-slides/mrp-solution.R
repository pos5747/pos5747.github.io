
# load packages
library(tidyverse)
library(brms)
library(marginaleffects)
library(ggdist)
library(maps)        # for map_data("state")
library(viridisLite) # palettes (used via scale_fill_viridis_c)

# set seed for reproducibility
set.seed(123)

# ces survey subset used throughout
survey <- get_dataset("ces_survey") |>
  glimpse()

# priors
priors_vague <- c(
  prior(normal(0, 1e6), class = "b"),
  prior(normal(0, 1e6), class = "Intercept")
)

# fit model
model <- brm(
  defund ~ age + education + military + gender + (1 + gender | state),
  family = bernoulli,
  prior = priors_vague,
  data = survey, 
  chains = 4, 
  cores = 4
)

# poststratification frame
demographics <- get_dataset("ces_demographics") |>
  glimpse()

# predictions for each row in the poststratification frame
p_ps <- predictions(model, newdata = demographics) |>
  glimpse()

# weighted state-level average predictions (MRP estimates)
p_state <- avg_predictions(
  model,
  newdata = demographics,
  wts = "percent",
  by = "state"
) |>
  glimpse()

# plot posterior density of state estimates
p_state_draws <- p_state |>
  get_draws(shape = "rvar") |>
  sort_by(~ estimate) |>
  glimpse()
p_state_draws$state <- factor(p_state_draws$state, levels = p_state_draws$state)
ggplot(p_state_draws, aes(y = state, xdist = rvar)) +
  stat_slab(height = 2, color = "white") +
  labs(x = "Posterior density of Support for Budget Cuts to Police", y = NULL) +
  xlim(c(.3, .5))

# plot map
us_map <- map_data("state") |>
  as_tibble() |>
  rename(region = region) |>
  glimpse()
state_lookup <- tibble(
  state = state.abb,
  region = tolower(state.name)
) |>
  glimpse()
plot_df <- p_state_draws %>%
  inner_join(state_lookup, by = "state") %>% 
  inner_join(us_map, by = "region") |>
  glimpse()
ggplot(plot_df, aes(x = long, y = lat, group = group, fill = estimate)) +
  geom_polygon(color = "white", linewidth = 0.2) +
  coord_map("albers", lat0 = 39, lat1 = 45) +
  scale_fill_viridis_c(name = "Support for Budget Cuts to Police") +
  theme_void(base_size = 12) +
  theme(
    legend.position = "right",
    plot.title = element_text(face = "bold")
  )


# ----- new

# fit model
model2 <- brm(
  defund ~ as.numeric(age) + as.numeric(education)*gender + military + (1 + as.numeric(age) | state),
  family = bernoulli,
  data = survey, 
  chains = 4, 
  cores = 4
)

# weighted state-level average predictions (MRP estimates)
p1_state <- p_state |>
  mutate(model = "Original")

p2_state <- avg_predictions(
  model2,
  newdata = demographics,
  wts = "percent",
  by = "state"
) |>
  mutate(model = "Updated") |>
  glimpse()

j <- bind_rows(p1_state, p2_state)

ggplot(j, aes(x = model, y = estimate, group = state)) + 
  geom_point() + 
  geom_line()

# compute and store loo inside the models
model  <- add_criterion(model,  "loo")
model2 <- add_criterion(model2, "loo")

# compare (higher elpd_loo is better)
comp <- loo_compare(model, model2)
print(comp)

# loo-based model weights 
w <- model_weights(model, model2, weights = "loo")
print(w)
