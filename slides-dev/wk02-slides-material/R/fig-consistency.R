# animate the sampling distribution of a (biased but) consistent estimator
# collapsing onto the truth as n grows

# load packages
library(tidyverse)
library(gganimate)
library(gifski)  # needed to render gif
library(hrbrthemes)
library(showtext)

# download and register Source Sans 3 from google fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto()

set.seed(123)

theta <- 0
sample_sizes <- c(100, 200, 300, 400, 500, 1000, 2000, 5000, 10000, 20000)

sim_data <- lapply(sample_sizes, function(n) {
  tibble(
    estimate = replicate(10000, (sum(rnorm(n, mean = theta, sd = 1)) + 25)/n),
    n = n
  )
}) |> bind_rows()

sim_data <- sim_data |> mutate(n = factor(n, levels = as.character(sample_sizes)))

anim <- ggplot(sim_data, aes(x = estimate)) +
  geom_density(fill = "#e41a1c", alpha = 1.0, color = NA) +
  geom_vline(xintercept = theta, linetype = "dashed") +
  labs(
    title = "Sampling Distribution of Estimate",
    subtitle = "Sample size: {closest_state}",
    x = "Estimate",
    y = "Density"
  ) +
  transition_states(n, transition_length = 2, state_length = 1, wrap = FALSE) +
  ease_aes("linear") +
  theme_ipsum(base_family = "Source Sans 3")

# render the gif (path relative to wk02-slides-material/; make runs Rscript here)
animate(anim, fps = 10, duration = 20, width = 4*1.7, height = 3*1.7, units = "in", res = 150,
        renderer = gifski_renderer("figs/fig-consistency.gif"))
