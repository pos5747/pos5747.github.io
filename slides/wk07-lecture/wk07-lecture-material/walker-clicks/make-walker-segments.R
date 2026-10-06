# Cut the "walker" Metropolis animation into click-advanced segments for the
# revealjs lecture deck.
#
# The animation is figs/fig-metropolis-walker.gif in ../wk07-slides-material.
# A gif runs on its own clock; in class Carlisle wants to pause and explain, so
# this script cuts the same frames into short mp4 segments that end at chosen
# pause points. On the slide the segments sit in an r-stack: the first plays on
# arrival, and each click (next fragment, which a clicker sends as Right/PageDown)
# plays the next one, which then holds its last frame until the next click.
#
# Run from wk07-lecture/:
#   Rscript wk07-lecture-material/walker-clicks/make-walker-segments.R
#
# It sources the walker figure script (which re-renders its gif, byte-identical,
# and leaves `plan`, `png_files`, `fps`, and the slow-iteration indices in scope),
# writes img/walker/seg-NN.mp4, and rewrites the generated slide block in
# sections/02-metropolis.qmd between the "walker-clicks" markers.

suppressPackageStartupMessages(library(tidyverse))

deck_dir     <- normalizePath(".")
material_dir <- normalizePath("../wk07-slides-material")
scratch      <- file.path(tempdir(), "walker-segments")
out_dir      <- file.path(deck_dir, "img", "walker")
section_qmd  <- file.path(deck_dir, "sections", "02-metropolis.qmd")
stopifnot(file.exists(file.path(material_dir, "R", "fig-metropolis-walker.R")),
          file.exists(section_qmd))

# ---- 1. the frames: run the figure script in its own folder ------------------

setwd(material_dir)
source("R/fig-metropolis-walker.R", local = TRUE)  # defines plan, png_files, fps, ...
setwd(deck_dir)

# ---- 2. the pause points -----------------------------------------------------
# Each row names the (iteration, phase) whose LAST frame ends a segment; the
# next click starts the frame after it. Edit this table to reshape the clicks.
# Default (2026-10-06): pause after the intro; after every step (propose,
# compute, draw u, decide, record) of iterations 2 to 5 and of the in-mass
# iterations from the first reject-by-u through the first accept-by-u (19 to
# 22 with this seed); let the two fast runs play through.

step_iterations <- c(2:5, slow_inmass:slow_accept_u)
stops <- bind_rows(
  tibble(s = 1, phase = "intro"),
  expand_grid(s = step_iterations, phase = c("propose", "compute", "draw_u", "decide", "record")),
  tibble(s = burn_end, phase = if (zoom_after_burnin) "zoom" else "record"),  # end of the burn-in run
  tibble(s = n_shown, phase = "hold")                                          # the end
)

# the plan row where each stop's last frame sits
stop_rows <- stops |>
  inner_join(plan |> mutate(row = row_number()), by = c("s", "phase")) |>
  group_by(s, phase) |>
  summarize(row = max(row), .groups = "drop") |>
  arrange(row)
stopifnot(nrow(stop_rows) == nrow(stops), max(stop_rows$row) == nrow(plan))

# ---- 3. one mp4 per segment --------------------------------------------------

min_frames <- 5  # pad very short segments so the player has something to end on
unlink(scratch, recursive = TRUE); dir.create(scratch, recursive = TRUE)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
unlink(list.files(out_dir, pattern = "^seg-\\d+\\.mp4$", full.names = TRUE))

seg_start <- c(1, head(stop_rows$row, -1) + 1)
seg_end   <- stop_rows$row
segments <- tibble(seg = seq_along(seg_end), from_row = seg_start, to_row = seg_end) |>
  mutate(ends_at = paste0(plan$s[to_row], "-", plan$phase[to_row]),
         n_frames = NA_integer_, file = sprintf("seg-%02d.mp4", seg))

for (i in seq_len(nrow(segments))) {
  rows <- segments$from_row[i]:segments$to_row[i]
  frames <- rep(png_files[rows], times = plan$reps[rows])
  if (length(frames) < min_frames) frames <- c(frames, rep(tail(frames, 1), min_frames - length(frames)))
  segments$n_frames[i] <- length(frames)

  seg_dir <- file.path(scratch, sprintf("seg-%02d", i)); dir.create(seg_dir)
  file.copy(frames, file.path(seg_dir, sprintf("f-%04d.png", seq_along(frames))))
  status <- system2("ffmpeg", c("-y", "-loglevel", "error", "-framerate", fps,
                                "-i", shQuote(file.path(seg_dir, "f-%04d.png")),
                                # h264 needs even dimensions; the PNGs are 1500 x 843
                                "-vf", shQuote("pad=ceil(iw/2)*2:ceil(ih/2)*2:color=white"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
                                "-movflags", "+faststart",
                                shQuote(file.path(scratch, segments$file[i]))))
  if (status != 0) stop("ffmpeg failed on segment ", i)
}
file.copy(file.path(scratch, segments$file), out_dir, overwrite = TRUE)
write_csv(segments |> select(seg, file, ends_at, n_frames) |> mutate(seconds = n_frames / fps),
          file.path(out_dir, "segments.csv"))

# ---- 4. the slide block ------------------------------------------------------

video <- function(file, fragment) {
  sprintf('<video %sdata-autoplay muted playsinline preload="auto" width="1280" src="img/walker/%s"></video>',
          if (fragment) 'class="fragment" ' else "", file)
}
click_map <- segments |>
  mutate(line = sprintf("%d. %s (%.1f s)", seg, ends_at, n_frames / fps)) |>
  pull(line)

# reveal.js 5.1 starts data-autoplay media when a slide is entered, but not when
# a fragment inside the slide is shown by navigation (verified in headless Chrome
# 2026-10-06: Reveal.next() never called play() on the fragment's video). This
# handler does it: rewind and play the video of each fragment as it is shown,
# and reset a fragment's video when it is hidden again (stepping back), so
# stepping forward replays it from the start.
handler <- c(
  "<script>",
  "(function () {",
  "  function media(el) {",
  "    var list = el.matches && el.matches('video[data-autoplay]') ? [el] : [];",
  "    return list.concat(Array.prototype.slice.call(el.querySelectorAll('video[data-autoplay]')));",
  "  }",
  "  function hook() {",
  "    Reveal.on('fragmentshown', function (ev) {",
  "      (ev.fragments || [ev.fragment]).forEach(function (f) {",
  "        media(f).forEach(function (v) {",
  "          // a click during a segment leaves that segment playing to its end",
  "          // underneath the new one (seeking a hidden video to its end does not",
  "          // take in Chrome), so stepping back shows its last frame",
  "          v.currentTime = 0; var p = v.play(); if (p && p.catch) p.catch(function () {});",
  "        });",
  "      });",
  "    });",
  "    Reveal.on('fragmenthidden', function (ev) {",
  "      (ev.fragments || [ev.fragment]).forEach(function (f) {",
  "        media(f).forEach(function (v) { v.pause(); v.currentTime = 0; });",
  "      });",
  "    });",
  "  }",
  "  function init() { if (!window.Reveal) return; if (Reveal.isReady()) hook(); else Reveal.on('ready', hook); }",
  "  if (document.readyState === 'complete') init(); else window.addEventListener('load', init);",
  "})();",
  "</script>"
)

block <- c(
  "<!-- walker-clicks: begin (generated by wk07-lecture-material/walker-clicks/make-walker-segments.R; do not edit by hand) -->",
  "## The algorithm, one iteration at a time",
  "",
  "::: {.r-stack}",
  "```{=html}",
  video(segments$file[1], fragment = FALSE),
  video(segments$file[-1], fragment = TRUE),
  handler,
  "```",
  ":::",
  "",
  "::: {.notes}",
  sprintf("The walker animation (`wk07-slides-material/figs/fig-metropolis-walker.gif`) cut into %d segments that advance on click: the first plays on arrival, each click plays the next and holds its last frame. %d clicks in all. Segment ends (iteration-step) and lengths:",
          nrow(segments), nrow(segments) - 1),
  "",
  click_map,
  "",
  "A clicker's next button sends Right or Page Down, which reveal maps to the next fragment, so nothing needs configuring. Clicking while a segment is still playing skips to the next one; Left steps back to the previous segment's last frame.",
  "",
  "[CTK: the pause points are the `stops` table at the top of make-walker-segments.R; edit it and re-run the script to reshape the clicks.]",
  ":::",
  "<!-- walker-clicks: end -->"
)

qmd <- readLines(section_qmd)
b <- grep("^<!-- walker-clicks: begin", qmd)
e <- grep("^<!-- walker-clicks: end", qmd)
if (length(b) == 1 && length(e) == 1) {
  qmd <- c(qmd[seq_len(b - 1)], block, qmd[(e + 1):length(qmd)])
} else {
  # first time: insert before the "## `metrop()`" slide, after the Accept/reject slide
  at <- grep("## `metrop()`", qmd, fixed = TRUE)[1]  # the first such slide
  stopifnot(!is.na(at))
  qmd <- c(qmd[seq_len(at - 1)], block, "", qmd[at:length(qmd)])
}
writeLines(qmd, section_qmd)

cat(sprintf("%d segments, %d clicks, %.1f s of video, %.1f MB in img/walker/\n",
            nrow(segments), nrow(segments) - 1, sum(segments$n_frames) / fps,
            sum(file.size(file.path(out_dir, segments$file))) / 1e6))
print(segments |> select(seg, ends_at, n_frames), n = Inf)
