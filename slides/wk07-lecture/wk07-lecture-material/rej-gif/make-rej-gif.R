# make-rej-gif.R
#
# Animated GIF for the wk07 lecture deck: a naive rejection sampler on the
# 5-coefficient turnout logit posterior, and how inefficient it is.
#
#   left panel   the proposal box (-2 to 2, two of its five dimensions), a
#                spray of proposals, the normal approximation to the posterior
#                (blue), and the accepted draws (red)
#   right panel  counters driven by a real, instrumented run of the sampler:
#                proposals, accepted, elapsed wall clock, a speed badge, a
#                progress bar toward 1,000 draws, the acceptance rate, and
#                (on the final hold) what 1,000 draws would cost
#
# Usage:  Rscript make-rej-gif.R [path/to/rej-run.rds]
#
# Frames are drawn with ggplot2 + patchwork on ragg::agg_png and assembled with
# gifski (no gganimate). Frames go to a scratch folder outside Dropbox; only the
# gif and its final frame (png) land in ../../img/.
#
# Debugging: set REJ_GIF_PREVIEW to a comma-separated list of frame numbers
# (e.g. REJ_GIF_PREVIEW=0,30,200,hold) to render only those frames and skip
# the gif/mp4 assembly.

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(hrbrthemes)
  library(ragg)
  library(gifski)
  library(scales)
})

# ---- paths -----------------------------------------------------------------

# Default input: rej-run.rds beside this script, written by the deck's hidden
# chunk `s1-rej-gif` (sections/01-opening.qmd) from the deck's own rejection
# run: the accepted draws with the proposal index each came from (recovered
# by replaying the run's random stream and checked against rej_wide), the
# run's total proposal count and wall-clock time, and the glm() coefficients
# and covariance for the blue cloud. The deck calls this script during its
# render (since 2026-10-06), so the gif always shows the run on the slides.
script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 1) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
})
default_rds <- file.path(script_dir, "rej-run.rds")
args <- commandArgs(trailingOnly = TRUE)
rds_path <- if (length(args) >= 1) args[1] else default_rds

# frames: scratch space outside Dropbox (hundreds of PNG writes); override with
# REJ_GIF_FRAMES=/some/dir to keep them
frame_dir <- Sys.getenv("REJ_GIF_FRAMES", unset = file.path(tempdir(), "rej-frames"))

# outputs: the deck's img/ folder, found relative to this script
img_dir <- normalizePath(file.path(script_dir, "..", "..", "img"), mustWork = FALSE)

preview <- Sys.getenv("REJ_GIF_PREVIEW")

# ---- deck theme (copied from wk07-lecture-material/build/setup-chunk.qmd) --

# Source Sans 3 is installed locally, so ragg draws it directly through
# systemfonts. The deck's setup chunk turns on showtext instead; showtext is
# not used here (it would replace ragg's text rendering and needs its dpi
# matched to the device). If the font is missing, fall back to showtext.
if (!"Source Sans 3" %in% systemfonts::system_fonts()$family) {
  library(showtext)
  font_add_google("Source Sans 3", family = "Source Sans 3")
  showtext_auto()
  showtext_opts(dpi = 150)  # must match the device res below
}

# tabular (fixed-width) digits for the counters, so they don't jitter
systemfonts::register_variant(
  name = "Source Sans 3 Tabular", family = "Source Sans 3",
  features = systemfonts::font_feature(numbers = "tabular")
)

lecture_colors <- c(red = "#e41a1c", blue = "#377eb8", green = "#4daf4a",
                    purple = "#984ea3", orange = "#ff7f00", gray = "#737b87")

theme_lecture <- function(base_size = 18) {
  ink <- "#1d232b"; soft <- "#4a5260"; grid <- "#e6e9ed"
  theme_ipsum(base_family = "Source Sans 3", base_size = base_size,
              plot_title_family = "Source Sans 3",
              plot_title_size = base_size * 1.2, plot_title_face = "bold",
              plot_title_margin = base_size * 0.5,
              subtitle_family = "Source Sans 3",
              subtitle_size = base_size * 0.95, subtitle_margin = base_size * 0.8,
              strip_text_family = "Source Sans 3",
              strip_text_size = base_size, strip_text_face = "bold",
              caption_family = "Source Sans 3", caption_size = base_size * 0.7,
              axis_text_size = base_size * 0.85,
              axis_title_family = "Source Sans 3",
              axis_title_size = base_size * 0.9, axis_title_face = "plain",
              axis_title_just = "rt",
              plot_margin = margin(8, 12, 8, 8),
              grid_col = grid, grid = "XY", axis_col = grid) +
    theme(text = element_text(color = ink),
          plot.title = element_text(color = ink),
          plot.subtitle = element_text(color = soft),
          axis.text = element_text(color = soft),
          axis.title = element_text(color = soft),
          strip.text = element_text(color = ink, hjust = 0),
          panel.grid.minor = element_blank(),
          legend.position = "top",
          legend.justification = "left",
          legend.margin = margin(0, 0, 0, 0),
          legend.box.spacing = unit(base_size * 0.4, "pt"),
          legend.text = element_text(size = base_size * 0.9, color = ink),
          legend.title = element_text(size = base_size * 0.9, color = soft),
          plot.title.position = "plot",
          plot.caption = element_text(color = soft),
          plot.background = element_rect(fill = "white", color = NA))
}

# design tokens (wk07-lecture-material/DESIGN.md)
col_ink    <- "#1d232b"
col_strong <- "#11161c"
col_muted  <- "#737b87"
col_rule   <- "#dfe3e8"
col_tint   <- "#f1f5fa"
col_navy   <- "#1b2a41"
col_red    <- lecture_colors[["red"]]
col_blue   <- lecture_colors[["blue"]]

# ---- frame geometry and timeline -------------------------------------------

width_px  <- 1400
height_px <- 700
res       <- 150
fps       <- 10

real_secs  <- 6    # phase A: the first 6 s of the run, in real time
fast_secs  <- 30   # phase B: the rest of the run, compressed into ~30 s
hold_secs  <- 6    # phase C: the final frame, held

# ---- the run ----------------------------------------------------------------

run <- readRDS(rds_path)
total_time   <- run$total_time
n_total      <- run$n_proposals
accepted     <- as_tibble(run$accepted)
n_acc_total  <- nrow(accepted)

# constant integer speed-up for phase B
mult <- ceiling((total_time - real_secs) / fast_secs)

# gif time (s) -> run time (s)
run_time <- function(t) {
  pmin(total_time, ifelse(t < real_secs, t, real_secs + (t - real_secs) * mult))
}

# run time (s) -> proposals made so far. The sampler runs at a constant pace
# (an instrumented run on 2026-10-06 logged 0.37 s per 10,000-proposal chunk
# throughout), and the deck's run records only its total time, so proposals
# are taken as linear in time.
n_proposals_at <- function(s) min(n_total, n_total * s / total_time)

# the animated frames: k = 0, 1, ..., until the run time reaches total_time
n_fast_frames <- ceiling((total_time - real_secs) / mult * fps)
frames <- tibble(k = 0:(real_secs * fps + n_fast_frames)) |>
  mutate(t_gif   = k / fps,
         t_run   = run_time(t_gif),
         n_prop  = map_dbl(t_run, n_proposals_at),
         phase   = if_else(t_gif < real_secs, "real", "fast"))

# the frame on which each accepted draw first appears
accepted <- accepted |>
  mutate(arrival_frame = map_int(proposal_index,
                                 \(i) min(frames$k[frames$n_prop >= i])))

# what 1,000 draws would cost, from this run
rate             <- n_acc_total / n_total
proposals_needed <- 1000 / rate
hours_needed     <- proposals_needed * (total_time / n_total) / 3600

# ---- the blue cloud: normal approximation to the posterior -------------------

set.seed(1234)
approx_draws <- MASS::mvrnorm(4000, run$glm_coef, run$glm_vcov) |>
  as_tibble()

# ---- helpers -----------------------------------------------------------------

fmt_clock <- function(s) sprintf("%d:%02d", floor(s / 60), floor(s %% 60))

# a reproducible sample of the proposals that arrived during frame k (uniform
# in the box, which is exactly what the proposals are)
spray_dots <- 120   # x 3 frames on screen; more dots = a bigger gif (250 gave 9 MB)
spray <- function(k) {
  if (k < 1) return(tibble(rs_age = numeric(), rs_educate = numeric()))
  set.seed(k)
  tibble(rs_age = runif(spray_dots, -2, 2), rs_educate = runif(spray_dots, -2, 2))
}

# ---- left panel: the box and the darts ------------------------------------------

base_size <- 13

left_panel <- function(k, hold = FALSE) {
  # proposals: this frame's sample plus the previous two, fading (solid
  # grays, not alpha, so the gif palette stays small)
  dots <- if (hold) NULL else
    bind_rows(mutate(spray(k - 2), shade = "grey84"),
              mutate(spray(k - 1), shade = "grey70"),
              mutate(spray(k),     shade = "grey50"))

  shown <- filter(accepted, arrival_frame <= k)
  pops  <- if (hold) shown[0, ] else filter(shown, k - arrival_frame <= 2)

  caption <- if (hold) {
    "red: the accepted draws · blue: the normal approximation to the posterior"
  } else {
    "dots: a sample of the proposals · the counter counts every one"
  }

  p <- ggplot()
  if (!is.null(dots)) {
    p <- p + geom_point(data = dots, aes(x = rs_age, y = rs_educate, color = shade),
                        size = 0.5, shape = 16) +
      scale_color_identity()
  }
  p +
    geom_point(data = approx_draws, aes(x = rs_age, y = rs_educate),
               color = col_blue, alpha = 0.15, size = 0.8) +
    annotate("rect", xmin = -2, xmax = 2, ymin = -2, ymax = 2,
             fill = NA, color = "grey40", linewidth = 0.6) +
    geom_point(data = pops, aes(x = rs_age, y = rs_educate),
               color = col_red, alpha = 0.5, size = 8) +
    geom_point(data = shown, aes(x = rs_age, y = rs_educate),
               color = col_red, size = 3.5) +
    coord_equal(xlim = c(-2.1, 2.1), ylim = c(-2.1, 2.1)) +
    labs(x = "rs_age", y = "rs_educate", caption = caption) +
    theme_lecture(base_size = base_size) +
    theme(plot.caption = element_text(hjust = 0, size = base_size * 0.8,
                                      color = col_muted, margin = margin(6, 0, 0, 0)),
          plot.caption.position = "plot",
          plot.margin = margin(4, 8, 6, 14))
}

# ---- right panel: the counters -----------------------------------------------------

pt <- function(points) points / .pt   # font points -> ggplot text size (mm)

right_panel <- function(t_run, n_prop, hold = FALSE) {
  n_acc  <- sum(accepted$proposal_index <= n_prop)
  fast   <- t_run >= real_secs
  speed  <- if (fast) paste0(mult, "× speed") else "1× speed"
  share  <- n_acc / 1000
  rate_t <- if (n_acc > 0) {
    paste0("acceptance rate: 1 in ", comma(signif(n_prop / n_acc, 3)))
  } else {
    "acceptance rate: —"
  }

  x0 <- 0.06; x1 <- 0.94          # left and right edges of the readout
  rows <- tibble(
    y     = c(0.87, 0.735, 0.60),
    label = c("proposals", "accepted", "elapsed"),
    value = c(comma(round(n_prop)), comma(n_acc), fmt_clock(t_run)),
    color = c(col_ink, if (n_acc > 0) col_red else col_ink, col_ink)
  )

  bar_y <- 0.33; bar_h <- 0.02    # the progress bar
  bar_x1 <- 0.78

  p <- ggplot() +
    # counters: label left, big tabular number right-aligned
    geom_text(data = rows, aes(x = x0, y = y, label = label),
              hjust = 0, vjust = 0, family = "Source Sans 3",
              size = pt(15), color = col_muted) +
    geom_text(data = rows, aes(x = x1, y = y, label = value, color = color),
              hjust = 1, vjust = 0, family = "Source Sans 3 Tabular",
              fontface = "bold", size = pt(34)) +
    scale_color_identity() +
    annotate("segment", x = x0, xend = x1, y = rows$y - 0.025, yend = rows$y - 0.025,
             color = col_rule, linewidth = 0.4) +
    # speed badge
    annotate("rect", xmin = x0, xmax = x0 + 0.30, ymin = 0.445, ymax = 0.52,
             fill = if (fast) col_navy else col_tint,
             color = if (fast) col_navy else col_blue, linewidth = 0.5) +
    annotate("text", x = x0 + 0.15, y = 0.4825, label = speed,
             family = "Source Sans 3 Tabular", fontface = "bold", size = pt(16),
             color = if (fast) "white" else col_ink) +
    # progress toward 1,000 draws
    annotate("text", x = x0, y = bar_y + 0.045, label = "accepted draws, of the 1,000 we want",
             hjust = 0, vjust = 0, family = "Source Sans 3", size = pt(13.5),
             color = col_muted) +
    annotate("rect", xmin = x0, xmax = bar_x1, ymin = bar_y - bar_h / 2,
             ymax = bar_y + bar_h / 2, fill = col_rule, color = NA) +
    annotate("rect", xmin = x0, xmax = x0 + (bar_x1 - x0) * min(share, 1),
             ymin = bar_y - bar_h / 2, ymax = bar_y + bar_h / 2,
             fill = col_red, color = NA) +
    annotate("text", x = x1, y = bar_y, label = percent(share, accuracy = 0.1),
             hjust = 1, family = "Source Sans 3 Tabular", fontface = "bold",
             size = pt(15), color = if (n_acc > 0) col_red else col_ink) +
    # acceptance rate
    annotate("text", x = x0, y = 0.235, label = rate_t, hjust = 0,
             family = "Source Sans 3 Tabular", size = pt(14), color = col_muted)

  if (hold) {
    payoff <- paste0("At this rate, 1,000 draws need about ",
                     "\n", signif(proposals_needed / 1e6, 2), " million proposals, ",
                     "about ", round(hours_needed), " hours.")
    p <- p +
      annotate("segment", x = x0, xend = x0 + 0.06, y = 0.175, yend = 0.175,
               color = col_red, linewidth = 1) +
      annotate("text", x = x0, y = 0.15, label = payoff, hjust = 0, vjust = 1,
               family = "Source Sans 3", fontface = "bold", size = pt(14.5),
               lineheight = 1.05, color = col_strong)
  }

  p +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(0, 10, 0, 10))
}

# ---- one frame ---------------------------------------------------------------------

title_text <- "Propose uniformly in the box, accept with probability f(z)/M"

draw_frame <- function(k, t_run, n_prop, file, hold = FALSE) {
  # wrap_elements(): the readout uses the full height, not the scatter's panel
  frame <- left_panel(k, hold) + wrap_elements(full = right_panel(t_run, n_prop, hold)) +
    plot_layout(widths = c(53, 47)) +
    plot_annotation(
      title = title_text,
      theme = theme(
        plot.title = element_text(family = "Source Sans 3", face = "bold",
                                  size = base_size * 1.5, color = col_ink,
                                  margin = margin(12, 0, 0, 14)),
        plot.background = element_rect(fill = "white", color = NA)
      )
    )
  agg_png(file, width = width_px, height = height_px, res = res, background = "white")
  print(frame)
  invisible(dev.off())
}

frame_file <- function(i) file.path(frame_dir, sprintf("frame-%04d.png", i))

# ---- render --------------------------------------------------------------------------

dir.create(frame_dir, showWarnings = FALSE, recursive = TRUE)

hold_k <- max(frames$k) + 1
cat(sprintf("run: %s accepted of %s proposals in %.1f s; %d× speed in phase B\n",
            n_acc_total, comma(n_total), total_time, mult))
cat("arrival frames:", paste(accepted$arrival_frame, collapse = ", "), "\n")
cat(sprintf("frames: %d animated + %d hold\n", nrow(frames), hold_secs * fps))

if (nzchar(preview)) {
  # debugging: render only the requested frames
  want <- strsplit(preview, ",")[[1]]
  for (w in want) {
    if (w == "hold") {
      draw_frame(hold_k, total_time, n_total, file.path(frame_dir, "preview-hold.png"), hold = TRUE)
    } else {
      fr <- filter(frames, k == as.integer(w))
      draw_frame(fr$k, fr$t_run, fr$n_prop, file.path(frame_dir, sprintf("preview-%04d.png", fr$k)))
    }
  }
  quit(save = "no")
}

unlink(list.files(frame_dir, pattern = "^(frame|preview)-.*\\.png$", full.names = TRUE))

start <- Sys.time()
for (i in seq_len(nrow(frames))) {
  fr <- frames[i, ]
  draw_frame(fr$k, fr$t_run, fr$n_prop, frame_file(i))
}
# phase C: the final frame, with the payoff block, held for hold_secs
hold_file <- frame_file(nrow(frames) + 1)
draw_frame(hold_k, total_time, n_total, hold_file, hold = TRUE)
for (j in 2:(hold_secs * fps)) file.copy(hold_file, frame_file(nrow(frames) + j))
cat(sprintf("rendered in %.0f s\n", as.numeric(difftime(Sys.time(), start, units = "secs"))))

# ---- assemble ---------------------------------------------------------------------------

png_files <- sort(list.files(frame_dir, pattern = "^frame-\\d{4}\\.png$", full.names = TRUE))
dir.create(img_dir, showWarnings = FALSE, recursive = TRUE)

gif_file <- file.path(img_dir, "rej-sampler.gif")
invisible(gifski(png_files, gif_file = gif_file, width = width_px, height = height_px,
                 delay = 1 / fps, loop = TRUE, progress = FALSE))
invisible(file.copy(hold_file, file.path(img_dir, "rej-sampler-final.png"), overwrite = TRUE))

# (an mp4 of the same frames was written here until 2026-10-06; dropped because the
#  deck never used it and `make site` published it)

cat(sprintf("gif: %s (%.1f MB, %d frames, %.1f s)\n", gif_file,
            file.size(gif_file) / 1e6, length(png_files), length(png_files) / fps))
cat(sprintf(paste0("rate = %.3g; proposals_needed = %s (%s million); ",
                   "hours_needed = %.2f (%d hours)\n"),
            rate, comma(round(proposals_needed)), signif(proposals_needed / 1e6, 2),
            hours_needed, round(hours_needed)))
