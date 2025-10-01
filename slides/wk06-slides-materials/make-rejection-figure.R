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

# Envelope height
M <- 4

# Target function on [0,1]
f <- function(pi) dbeta(pi, shape1 = 4, shape2 = 10)

# Curve data
df <- data.frame(pi = seq(0, 1, length.out = 1001))
df$dens <- f(df$pi)

# x-positions for vertical lines
pis <- c(0.125, 0.25, 0.50, 0.75)

# Evaluate f() and compute accept/reject probabilities at those positions
seg_info <- data.frame(
  pi0  = pis,
  fval = f(pis)
)
seg_info$acc_prob <- pmin(seg_info$fval / M, 1)          # accept proportion
seg_info$rej_prob <- pmax(1 - seg_info$acc_prob, 0)      # reject proportion

# Build accept (green) segments: y = 0 -> f(pi0)
acc_segments <- transform(
  seg_info,
  x = pi0, xend = pi0,
  y = 0,   yend = fval,
  y_mid = (0 + fval) / 2,                                  # midpoint for label
  lbl = sprintf("Pr(Accept) = %.2f", acc_prob)
) |> 
  filter(yend > 0.01)

# Build reject (red) segments: y = f(pi0) -> M
rej_segments <- transform(
  seg_info,
  x = pi0, xend = pi0,
  y = fval, yend = M,
  y_mid = (fval + M) / 2,                                  # midpoint for label
  lbl = sprintf("Pr(Reject) = %.2f", rej_prob)
)

ggplot(df, aes(x = pi, y = dens)) +
  # Shade under the target distribution
  geom_area(
    data = df,
    aes(x = pi, y = dens),
    fill = "#377eb8",
    alpha = 0.2,
    inherit.aes = FALSE
  ) + 
  geom_hline(
    yintercept = M, 
    color = "black", 
    linetype = "dashed"
  ) + 
  # Label M
  annotate(geom = "label",
           x = .07, 
           y = M, 
           label = "M", 
           color = "black", 
           family = "Source Sans 3") +
  # Target curve with a path-following label
  geom_textpath(
    aes(label = "target distribution"),
    linewidth = 0.8,
    size = 4,
    vjust = -0.1,
    color = "#377eb8", 
    family = "Source Sans 3"
  ) +
  # Accept (green) and reject (red) vertical segments
  geom_segment(
    data = acc_segments,
    aes(x = x, xend = xend, y = y, yend = yend),
    inherit.aes = FALSE,
    linewidth = 0.5,
    color = "#4daf4a", 
    linetype = "dotted"
  ) +
  geom_segment(
    data = rej_segments,
    aes(x = x, xend = xend, y = y, yend = yend),
    inherit.aes = FALSE,
    linewidth = 0.5,
    color = "#e41a1c", 
    linetype = "dotted"
  ) +
  # Midpoint labels: regular ggplot text, centered on each segment
  geom_label(
    data = acc_segments,
    aes(x = x, y = y_mid, label = lbl),
    inherit.aes = FALSE,
    color = "#4daf4a",
    size = 2.7,
    #angle = 90,          # rotate to align with vertical segment (optional)
    vjust = 0.5,
    hjust = 0.5, 
    family = "Source Sans 3"
  ) +
  geom_label(
    data = rej_segments,
    aes(x = x, y = y_mid, label = lbl),
    inherit.aes = FALSE,
    color = "#e41a1c",
    size = 2.7,
    #angle = 90,          # rotate to align with vertical segment (optional)
    vjust = 0.5,
    hjust = 0.5, 
    family = "Source Sans 3"
  ) +
  # Label proposal density
  annotate(geom = "label",
           x = .5, 
           y = M,
           vjust = -0.3,
           size = 3,
           label = "← sample candidate values uniformly from 0 to 1 →", 
           color = "black", 
           family = "Source Sans 3") +
  scale_x_continuous(limits = c(0, 1)) +
  scale_y_continuous(limits = c(0, 4.2)) +
  labs(x = expression(pi), y = "Density") +
  theme_ipsum(base_family = "Source Sans 3") + 
  labs(title = "Illustrating the logic of the rejection algorithm", 
       subtitle = "For a beta(4, 10) target distribution.")

ggsave(filename = "slides/wk06-slides-materials/reject-illustration.pdf", 
       height = 3, width = 4, scale = 2)

rej <- function(f, S, M) {
  
  # record start time
  start_time <- Sys.time()
  
  # create containers and initialize counters
  samples <- numeric(S)  # container to store samples
  rejects <- NULL  # container to track rejected values; for teaching; slow!
  s <- 1 # currently trying to take sample 1
  n_prop <- 0  # count proposals (for an acceptance-rate message)
  
  # so long as the current sample s is less 
  #   than the desired samples S.
  #   do the following:
  while (s <= S) { 
    
    # A: propose z ~ uniform(0,1)
    z <- runif(1)
    
    # B: draw u ~ uniform(0,1)
    u <- runif(1)
    
    # C: Accept or reject
    fz <- f(z) # compute once, for effeciency
    
    ## scenario 1: u <= f(z)/M  →  Accept
    if (u <= fz / M) {
      samples[s] <- z
      s <- s + 1
    } 
    
    ## scenario 2: f(z) > M  →  shouldn't happen; error
    if (fz > M) stop("Stop: Envelope M is too small.")  # find appropriate M
    
    ## scenario 3: u > f(z)/M  →  Reject
    ##   tracking these values just for teaching and learning--not needed usually
    if (u > fz / M) {
      rejects <- c(rejects, z)
    }
    
    # track total proposals so far
    n_prop <- n_prop + 1
  }
  
  # print a summary report
  message(
    paste0(
      "💪 Successfully generated ", scales::comma(S), " samples! 🎉\n\n",
      "✅ Accepted samples: ", scales::comma(S), "\n",
      "❌ Rejected samples: ", scales::comma(length(rejects)), "\n",
      "﹪ Acceptance rate: ", scales::percent(S / n_prop, accuracy = 1), "\n",
      "⏰ Total time: ", prettyunits::pretty_dt(Sys.time() - start_time)
    )
  )
  
  # return
  list(
    n_prop = n_prop,
    acc_rate = S / n_prop,
    samples = samples,
    rejects = rejects
  )
}

# example target distribution; beta(4, 10)
f <- function(z) {
  dbeta(z, shape1 = 4, shape2 = 10)
}

set.seed(1234)
# perform sampling
r <- rej(f, 10000, 4)

# plot target distribution
ggplot() +
  stat_function(fun = f) +
  xlim(0, 1) +
  geom_histogram(binwidth = 1/20, boundary = 0) + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Density", 
       title = "Target distribution", 
       subtitle = "beta(4, 10)") 
ggsave(filename = "slides/wk06-slides-materials/reject-target.pdf", 
       height = 3, width = 4, scale = 2)

bind_rows(
  data.frame(type = "Accepted", values = r$samples),
  data.frame(type = "Rejected", values = r$rejects)
) |>
  mutate(type = factor(type, levels = c("Rejected", "Accepted"))) |>
  ggplot(aes(fill = type, x = values)) +
  geom_histogram(binwidth = 1/50, boundary = 0, color = "black") + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Count", 
       fill = "Result", 
       title = "Samples from rejection algorithm", 
       subtitle = "10,000 accepted samples; 30,870 rejected values")
ggsave(filename = "slides/wk06-slides-materials/reject-samples.pdf", 
       height = 3, width = 4, scale = 2)

# posterior mean
4/(4 + 10)  # closed-form
mean(r$samples)  # simulation


prior_saw <- function(p, n_teeth = 5) {
  ((n_teeth*p) %% 1)
}

gg1 <- ggplot() +
  stat_function(fun = prior_saw) +
  xlim(0, 1) +
  geom_histogram(binwidth = 1/20, boundary = 0) + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Density", 
       title = 'Sawtooth "prior"', 
       subtitle = "Does not integrate to one") 
ggsave(gg1, filename = "slides/wk06-slides-materials/weird-prior.pdf", 
       height = 3, width = 4, scale = 2)


# likelihood (10 tosses; 1 success )
lik <- function(p) {
  p^1 * (1-p)^9
}

gg2 <- ggplot() +
  stat_function(fun = lik) +
  xlim(0, 1) +
  geom_histogram(binwidth = 1/20, boundary = 0) + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Density", 
       title = 'Bernoulli likelihood', 
       subtitle = "10 tosses; 1 success") 

# unnromalized posterior
unnormalized_posterior <- function(p) {
  lik(p)*prior_saw(p)
}

gg3 <- ggplot() +
  stat_function(fun = unnormalized_posterior) +
  xlim(0, 1) +
  geom_histogram(binwidth = 1/20, boundary = 0) + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Density", 
       title = 'A weird unnormalized posterior', 
       subtitle = "Bernoulli likelihood; sawtooth prior") 

layout <- "
AAA###
AAA###
BBBCCC
BBBCCC
"
gg1 + gg2 + gg3 +
  plot_layout(design = layout)

gg3 + gg2 + gg1

ggsave(filename = "slides/wk06-slides-materials/weird.pdf", 
       height = 3, width = 12, scale = 1.5)


((gg1 / gg2) | gg3)  +
  plot_layout(widths = c(2, 2, 2), heights = c(1, 2, 1))


# likelihood (10 tosses; 1 success )
lik <- function(p) {
  p^1 * (1-p)^9
}

# unnormalized posterior
unnormalized_posterior <- function(p) {
  lik(p)*prior_saw(p)
}

# rejection algorithm
set.seed(1234)
r <- rej(unnormalized_posterior, S = 10000, M = 0.03)


bind_rows(
  data.frame(type = "Accepted", values = r$samples),
  data.frame(type = "Rejected", values = r$rejects)
) |>
  mutate(type = factor(type, levels = c("Rejected", "Accepted"))) |>
  ggplot(aes(fill = type, x = values)) +
  geom_histogram(binwidth = 1/50, boundary = 0, color = "black") + 
  theme_ipsum(base_family = "Source Sans 3") +
  scale_fill_manual(values = c("#e41a1c", "#377eb8")) + 
  labs(x = expression(pi), y = "Count", 
       fill = "Result", 
       title = "Samples from rejection algorithm", 
       subtitle = "10,000 accepted samples; 58,295 rejected values")
ggsave(filename = "slides/wk06-slides-materials/weird-reject-samples.pdf", 
       height = 3, width = 4, scale = 2)
