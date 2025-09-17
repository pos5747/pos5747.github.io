
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




