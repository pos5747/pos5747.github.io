# Example figure script. Conventions:
#   - script name = asset name: R/fig-<topic>.R writes figs/fig-<topic>.pdf
#     (or .gif); one script per figure
#   - paths are relative to the week folder (make runs Rscript from there)
#   - theme_ipsum() with Source Sans 3, Set1 colors, vector output

# load packages
library(tidyverse)
library(hrbrthemes)
library(palmerpenguins)
library(showtext)

# download and register Source Sans 3 from google fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto()

# plot
ggplot(penguins, aes(x = flipper_length_mm,
                     y = bill_length_mm,
                     color = species)) +
  geom_point(size = 3, alpha = 0.8) +
  labs(title = "Default ggplot() Style: Source Sans 3 with theme_ipsum()",
       subtitle = "Using the palmerpenguins Data",
       x = "Flipper Length (in mm)",
       y = "Bill Length (in mm)",
       color = "Species") +
  theme_ipsum(base_family = "Source Sans 3") +
  scale_color_manual(values = c("#e41a1c", "#377eb8", "#4daf4a"))

# save plot
ggsave("figs/fig-example.pdf",
       height = 3, width = 4, scale = 2)
