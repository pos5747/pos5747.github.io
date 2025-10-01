
# load packages
library(tidyverse)
library(ggridges)
library(patchwork)


# priors
priors <- tribble(
  ~name,        ~alpha_star, ~ beta_star,
  "Uniform", 1, 1,
  "Strange", 0.5, 0.5,
  "Carlisle's Anti-Prior", 15, 3, 
  "Carlisle",   3,          15,
) %>% na.omit() %>%
  mutate(name = factor(name, levels = name))

# data
y <- 8
n <- 150

# data frame for priors and posteriors
gg_data <- priors %>%
  crossing(x = seq(0.001, 0.999, length.out = 1000)) %>%
  mutate(alpha_prime = alpha_star + y,
         beta_prime = beta_star + (n - y)) %>% 
  mutate(prior_density = dbeta(x, shape1 = alpha_star, shape2 = beta_star),
         posterior_density = dbeta(x, shape1 = alpha_prime, shape2 = beta_prime)) %>% 
  pivot_longer(cols = ends_with("_density"), names_to = "distribution", values_to = "density") %>%
  glimpse()

# ---- run the code below to plot priors -----

# plot priors only
ggplot(filter(gg_data, distribution == "prior_density"), aes(x = x, y = density, color = name)) + 
  facet_wrap(vars(distribution), scales = "free") +  
  geom_line() + 
  labs(title = "Prior Densities for Each Person")

# ---- run the code below to plot posteriors

gg_pp <- ggplot(gg_data, aes(x = x, y = density, color = name)) + 
  facet_wrap(vars(distribution), scales = "free") +  
  geom_line() + 
  labs(title = "The Posterior and Prior Densities for Each Person")

# create some helpful functions
find_mode <- function(alpha, beta) {
  (alpha - 1)/(alpha + beta - 2)
}
find_mean <- function(alpha, beta) {
  alpha/(alpha + beta)
}
find_sd <- function(alpha, beta) {
  a <- alpha
  b <- beta
  v <- (a*b)/(((a + b)^2)*(a + b + 1))
  sqrt(v)
}
find_median <- function(alpha, beta) {
  a <- alpha
  b <- beta
  s <- rbeta(50000, a, b)
  median(s)
}
vfind_median <- Vectorize(find_median)

point_estimates <- priors %>%
  mutate(alpha_prime = alpha_star + y,
         beta_prime = beta_star + (n - y)) %>%
  mutate(mode = find_mode(alpha_prime, beta_prime),
         mean = find_mean(alpha_prime, beta_prime),
         median = vfind_median(alpha_prime, beta_prime)) %>%
  mutate(name = reorder(name, mean)) %>%
  pivot_longer(mode:median, names_to = "summary_type", values_to = "value") %>%
  glimpse()

gg_pt <- ggplot(point_estimates, aes(x = value, y = name)) + 
  geom_point() + 
  facet_wrap(vars(summary_type)) + 
  labs(title = "Point Estimates from Posterior Distribution")

gg_joy <- gg_data %>%
  filter(distribution == "posterior_density") %>%
  mutate(name = reorder(name, density, max)) %>%
  ggplot(aes(x = x, y = name, height = density)) + 
  geom_ridgeline(scale = 0.2) + 
  labs(title = "A Joy Plot Comparing the Posteriors") 

gg_ci <- priors |> 
  mutate(alpha_prime = alpha_star + y,
         beta_prime = beta_star + (n - y)) |>
  ggplot(aes(x = find_mean(alpha_prime, beta_prime), 
             y = name, 
             xmin = qbeta(0.025, alpha_prime, beta_prime),
             xmax = qbeta(0.975, alpha_prime, beta_prime))) + 
  geom_errorbarh(height = 0) + 
  geom_point() + 
  labs(x = "Posterior Mean and 95% Credible Interval", 
       y = "Prior Name", 
       title = "Posterior Means and 95% Credible Intervals") 

# print the plots
gg_pp
gg_joy
gg_pt
(gg_pp ) / (gg_pt + gg_ci) + plot_layout(guides = 'collect')

