
# load packages
library(tidyverse)
library(hrbrthemes)
library(palmerpenguins)
library(showtext)
library(marginaleffects)

# download and register Source Sans 3 from google fonts
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto() 
devtools::install_github("jrnold/ZeligData")

# load only the turnout data frame
turnout <- ZeligData::turnout  # see ?ZeligData::turnout for details

# ---- age only ----

f <- vote ~ age
glm_fit <- glm(f, data = turnout, family = binomial)

me_qi <- predictions(glm_fit, 
                     newdata = datagrid(
                       age = \(x) seq(min(x), max(x))),  # set age using fn defined with \() syntax
                     conf_level = 0.90)

ggplot(me_qi, aes(x = age, y = estimate, 
                  ymin = conf.low, 
                  ymax = conf.high)) + 
  geom_line() + 
  labs(title = "The Probability of Voting by Age",
       x = "Age",
       y = "Probability of Voting") +
  theme_ipsum(base_family = "Source Sans 3") 
ggsave("slides/wk04-slides-material/voting.pdf", height = 3, width = 5, scale = 1.5)

# ---- age only ----

st <- turnout |>
  select(vote, age, race, income) |>
  mutate(income = 2*round(income/2)) |>
  glimpse()
f <- vote ~ .
glm_fit <- lm(f, data = st, family = binomial)

me_qi <- predictions(glm_fit, 
                     newdata = datagrid(race = unique, 
                                        income = unique,
                                        age = unique),
                     conf_level = 0.90) |>
  mutate(inc_lab = paste0("$", income, "k"), 
         inc_lab = reorder(inc_lab, income)) |>
  glimpse()

ggplot(me_qi, aes(x = age, y = estimate, linetype = race)) + 
  geom_hline(yintercept = 1.0, color = "#E41A1C", alpha = 0.7) + 
  geom_line() + 
  facet_wrap(vars(inc_lab)) + 
  labs(title = "The Probability of Voting by Age, Income, and Race",
       x = "Age",
       y = "Probability of Voting", 
       linetype = "Race") +
  theme_ipsum(base_family = "Source Sans 3") 
ggsave("slides/wk04-slides-material/voting-problem1.pdf", height = 3, width = 4, scale = 2.5)
  
inv_logit <- function(x) {
  (exp(x))/(1 + exp(x))
}

ggplot() + 
  xlim(-10, 10) + 
  stat_function(fun = plogis) + 
  labs(title = "The Inverse Logit Functin",
       x = "← unbounded linear predictor →",
       y = "probability bounded between 0 and 1") +
  theme_ipsum(base_family = "Source Sans 3") 
ggsave("slides/wk04-slides-material/invlogit.pdf", height = 3, width = 4, scale = 1.3)


# data; see ?crdata::holland2015
holland <- crdata::holland2015 |>
  filter(city == "santiago")

ggplot(holland, aes(x = operations)) + 
  geom_histogram(binwidth = 1, center = 1) +
  theme_ipsum(base_family = "Source Sans 3") + 
  labs(title = "Histogram of Holland's (2015) 'operations' Variable",
       subtitle = "Santiago Only",
       x = "'operations'", 
       y = "Number of Observations")
ggsave("slides/wk04-slides-material/operations.pdf", height = 3, width = 4, scale = 1.9)



library(tidyverse); library(geomtextpath); library(ggrepel); library(hrbrthemes); library(showtext); library(grid)
font_add_google("Source Sans 3","Source Sans 3"); showtext_auto()

p <- \(x,z) plogis(-4 + x + z)
m <- \(x,z) {pp <- p(x,z); pp*(1-pp)}

df <- tidyr::expand_grid(x = seq(0,8,0.1), z = 0:2) |>
  mutate(
    p = p(x,z),
    z_lab = factor(paste0("x[2] == ", z), paste0("x[2] == ", 0:2))  # lower-case x[2]
  )

x_star <- optimize(\(x) abs(m(x,0) - m(x,2)), c(0,8), maximum = TRUE)$maximum

repel_df <- bind_rows(
  tibble(
    x = x_star,
    y = p(x_star, c(0,2)),
    label = paste0(
      "frac(partialdiff*Pr(y),~partialdiff*x[1])==",
      sub("^0","",sprintf("%.3f", m(x_star, c(0,2))))
    ),                                   # lower-case y and x[1]
    alpha = 1
  ),
  df |> group_by(z) |> slice(which(row_number() %% 3 == 1)) |> ungroup() |>
    transmute(x, y = p, label = '""', alpha = 0)
)

set.seed(1234)
ggplot(df, aes(x, p)) +
  geom_textpath(
    aes(linetype = z_lab, label = z_lab),
    color = "black", size = 3.2, vjust = -0.15, hjust = 0.15,
    show.legend = FALSE, parse = TRUE
  ) +
  geom_label_repel(
    data = repel_df,
    aes(x, y, label = label, alpha = alpha),
    inherit.aes = FALSE, parse = TRUE, size = 2.2,
    label.r = unit(0.08,"lines"), point.padding = 0.5,
    box.padding = 0.5, #force = 1., force_pull = 0.2,
    max.time = 2, min.segment.length = 0,
    arrow = arrow(length = unit(1.25,"mm")),
    segment.curvature = 0, segment.angle = 90,
    segment.ncp = 1, max.overlaps = Inf
  ) +
  geom_point(
    data = filter(repel_df, alpha == 1),
    aes(x, y), inherit.aes = FALSE, size = 1.2
  ) +
  scale_alpha_identity() +
  scale_x_continuous(limits = c(0,8), breaks = 0:8, expand = expansion(mult = c(0,0))) +
  scale_y_continuous(limits = c(0,1), breaks = seq(0,1,0.2), expand = expansion(mult = c(0,0))) +
  scale_linetype_manual(values = c("solid","dashed","dotted")) +
  labs(
    title = "Illustrative Logit Model (Without Product Term)",
    subtitle = "From Berry, DeMeritt, and Esarey (2010)",
    x = expression(x[1]),                 # lower-case x[1]
    y = expression(Pr(y))                 # lower-case y in Pr(y)
  ) +
  theme_ipsum(base_family = "Source Sans 3") +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "none",
    panel.grid.minor = element_blank()
  )
ggsave("slides/wk04-slides-material/not-constant.pdf", height = 3, width = 4, scale = 1.9)


