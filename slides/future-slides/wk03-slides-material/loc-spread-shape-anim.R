############################################################
# Animated densities (location, scale, shape) — minimal styling
# Revised for slower, smoother evolution (explicit nframes + lower frequency)
############################################################

# Packages
library(tidyverse)
library(gganimate)
library(hrbrthemes)
library(showtext)
library(sn)          # for skew-normal (not used below but OK to keep)

# Fonts (Google: Source Sans 3)
font_add_google("Source Sans 3", family = "Source Sans 3")
showtext_auto()

# Output settings
out_dir  <- "slides/wk03-slides-material/"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Canvas / animation controls
n_frames <- 120 * 3    # build many frames
fps      <- 30
w_px     <- 800
h_px     <- 500
x_grid   <- seq(-6, 6, by = 0.02)
ylim_max <- 0.85        # stable upper bound for normal-ish panels

# ----- Slow-down controls -----
# Frequency of parameter oscillations per full animation:
#   1.0 = one full cycle per animation,
#   0.5 = half-cycle (out-and-back over full run),
#   0.25 = very slow.
speed_cycles_per_anim <- 0.5
# Time helper: frame -> t in [0,1]
t_of   <- function(f, n = n_frames) (f - 1) / (n - 1)
# Smooth loop on [-1, 1] with controlled frequency
cycle  <- function(t) sin(2 * pi * speed_cycles_per_anim * t)

# Minimal theme (no ticks, no tick labels, no legend)
theme_minimal_anim <- theme_ipsum(base_family = "Source Sans 3", base_size = 14) +
  theme(
    legend.position   = "none",
    axis.title.x      = element_text(size = 20),
    axis.title.y      = element_blank(),
    axis.text.x       = element_blank(),
    axis.text.y       = element_blank(),
    axis.ticks.x      = element_blank(),
    axis.ticks.y      = element_blank(),
    panel.grid.major  = element_blank(),
    panel.grid.minor  = element_blank()
  )

# ---------- 1) LOCATION SHIFT (mu moves; sigma fixed) ----------
# Schedulers
mu_loc    <- function(t)  2 * cycle(t)   # slide left/right
sigma_loc <- function(t)  1.0            # fixed spread

# Build frames
df_loc <- map_dfr(seq_len(n_frames), function(f) {
  t  <- t_of(f)
  mu <- mu_loc(t)
  sg <- sigma_loc(t)
  tibble(
    frame   = f,
    x       = x_grid,
    density = dnorm(x_grid, mean = mu, sd = sg),
    mu      = mu,
    sigma   = sg
  )
})

# Plot
p_loc <- ggplot(df_loc, aes(x = x, y = density, group = frame)) +
  geom_line(linewidth = 2) +
  coord_cartesian(xlim = range(x_grid), ylim = c(0, ylim_max), expand = FALSE) +
  labs(x = "estimate", y = NULL) +
  theme_minimal_anim +
  transition_manual(frame)

# Render (& optionally save)
anim_loc <- animate(p_loc, nframes = n_frames, fps = fps, width = w_px, height = h_px, rewind = TRUE); anim_loc
anim_save(file.path(out_dir, "01-location-shift.gif"), animation = anim_loc)


# ---------- 2) SCALE CHANGE (sigma breathes; mu fixed) ----------
# Schedulers: make SD range [0.5, 1.5] so the min is ~50% less than 1.0
mu_scl    <- function(t)  0.0
sigma_scl <- function(t)  1.0 + 0.5 * cycle(t)   # center 1.0, amplitude 0.5 -> [0.5, 1.5]

# Rebuild frames
df_scl <- map_dfr(seq_len(n_frames), function(f) {
  t  <- t_of(f)
  mu <- mu_scl(t)
  sg <- sigma_scl(t)
  tibble(
    frame   = f,
    x       = x_grid,
    density = dnorm(x_grid, mean = mu, sd = sg),
    mu      = mu,
    sigma   = sg
  )
})

# Plot
p_scl <- ggplot(df_scl, aes(x = x, y = density, group = frame)) +
  geom_line(linewidth = 2) +
  coord_cartesian(xlim = range(x_grid), ylim = c(0, ylim_max), expand = FALSE) +
  labs(x = "estimate", y = NULL) +
  theme_minimal_anim +
  transition_manual(frame)

# Render (& optionally save)
anim_scl <- animate(p_scl, nframes = n_frames, fps = fps, width = w_px, height = h_px, rewind = TRUE); anim_scl
anim_save(file.path(out_dir, "02-scale-change.gif"), animation = anim_scl)



# ---------- 3) SHAPE CHANGE (skew varies; mean/SD fixed via shifted-gamma) ----------
# Target mean & SD (match other plots)
m_target <- 0.0
s_target <- 1.0

# Pick a broad shape range for dramatic skew changes:
#   skewness = 2/sqrt(k).  k small -> very skewed; k large -> mild skew.
k_min <- 1     # moderate–strong skew
k_max <- 8    # near-symmetric
# Scheduler for k(t) — ensure a full swing each animation
speed_cycles_per_anim <- 1.0
cycle <- function(t) sin(2 * pi * speed_cycles_per_anim * t)

k_of_t <- function(t) {
  k_c <- 0.5 * (k_min + k_max)
  k_a <- 0.5 * (k_max - k_min)
  k_c + k_a * cycle(t)
}


# Given k, choose theta & location to keep mean=m_target and sd=s_target
theta_from_k <- function(k) s_target / sqrt(k)
loc_from_k   <- function(k) m_target - s_target * sqrt(k)

# Wider x-range to show the long right tail
x_grid_shape <- seq(-6, 10, by = 0.02)

# Build frames
df_shp <- map_dfr(seq_len(n_frames), function(f) {
  t  <- t_of(f)
  k  <- k_of_t(t)
  th <- theta_from_k(k)
  lc <- loc_from_k(k)
  
  dens <- ifelse(
    x_grid_shape > lc,
    dgamma(x_grid_shape - lc, shape = k, scale = th),
    0
  )
  
  tibble(
    frame   = f,
    x       = x_grid_shape,
    density = dens,
    k       = k,
    theta   = th,
    loc     = lc
  )
})

# y-limit for shape panel (avoid popping with tall peaks)
ylim_shape <- c(0, max(df_shp$density) * 1.05)

# Plot
p_shp <- ggplot(df_shp, aes(x = x, y = density, group = frame)) +
  geom_line(linewidth = 2) +
  coord_cartesian(xlim = range(x_grid_shape), ylim = ylim_shape, expand = FALSE) +
  labs(x = "estimate", y = NULL) +
  theme_minimal_anim +
  transition_manual(frame)

# Render (& optionally save)
anim_shp <- animate(p_shp, nframes = n_frames, fps = fps, width = w_px, height = h_px, rewind = TRUE); anim_shp
anim_save(file.path(out_dir, "03-shape-change.gif"), animation = anim_shp)
