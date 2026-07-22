
# run just once, then delete
devtools::install_github("carlislerainey/crdata")

# load packages
library(tidyverse)
library(hrbrthemes)
library(showtext)

# load Clark and Golder's data
cg <- crdata::cg2006 |> # from my data package
  mutate(system = cut(average_magnitude, c(-Inf, 1, 5, Inf),
                      labels = c("Single-Member Districts",
                                "Small-Magnitude PR",
                               "Large-Magnitude PR"))) |>
  glimpse()

# download and register Source Sans 3 from google fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto()

# plot
ggplot(cg, aes(x = eneg,
                     y = enep)) +
  geom_point(size = 1, alpha = 0.8) +
  facet_wrap(vars(system), ncol = 3) +
  labs(title = "A Simple Scatterplot",
       subtitle = "It's hard to do a lot better than this.",
       x = "Effective Number of Ethnic Groups",
       y = "Effective Number of Electoral Parties") +
  theme_ipsum(base_family = "Source Sans 3") +
  scale_x_log10() +
  geom_smooth(method = lm, se = FALSE, color = "#e41a1c")

# save plot (path relative to wk01-slides-material/; make runs Rscript here)
ggsave("figs/fig-cg-scatter.pdf",
       height = 2, width = 4, scale = 2)
