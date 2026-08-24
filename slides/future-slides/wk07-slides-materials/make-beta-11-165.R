#| echo: false
#| message: false
#| warning: false
#| fig-height: 5
#| fig-width: 8

library(dplyr)
library(ggplot2)
library(geomtextpath)  
library(hrbrthemes)
library(showtext)
library(patchwork)


# download and register Source Sans 3 from google fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto() 


# Target function on [0,1]
f <- function(pi) dbeta(pi, shape1 = 11, shape2 = 165)

# Curve data
df <- data.frame(pi = seq(0, 1, length.out = 1001))
df$dens <- f(df$pi)

ggplot(df, aes(x = pi, y = dens)) +
  # Shade under the target distribution
  geom_area(
    data = df,
    aes(x = pi, y = dens),
    fill = "#377eb8",
    alpha = 0.2,
    inherit.aes = FALSE
  ) + 
  # Target curve with a path-following label
  geom_textpath(
    aes(label = "posterior distribution"),
    linewidth = 0.8,
    size = 4,
    vjust = -0.1,
    color = "#377eb8", 
    family = "Source Sans 3"
  ) +
  labs(x = expression(pi), y = "Density") +
  theme_ipsum(base_family = "Source Sans 3") + 
  labs(title =  "My posterior: beta(11, 165)")

ggsave(filename = "slides/wk07-slides-materials/beta-11-165.pdf", 
       height = 3, width = 4, scale = 2)
