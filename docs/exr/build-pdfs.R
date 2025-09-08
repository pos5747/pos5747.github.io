# build-all-versions.R (metadata version with timestamp check)

files <- list.files("exr", pattern = "\\.qmd$", full.names = TRUE)

for (f in files) {
  base <- sub("\\.qmd$", "", basename(f))   # wk01-exr-sol
  stem <- sub("-sol$", "", base)            # wk01-exr
  
  out_no  <- file.path("exr", paste0(stem, ".pdf"))
  out_sol <- file.path("exr", paste0(stem, "-sol.pdf"))
  
  qmd_time <- file.info(f)$mtime
  no_time  <- if (file.exists(out_no))  file.info(out_no)$mtime  else as.POSIXct(0, origin="1970-01-01")
  sol_time <- if (file.exists(out_sol)) file.info(out_sol)$mtime else as.POSIXct(0, origin="1970-01-01")
  
  # no solutions
  if (qmd_time > no_time) {
    system2("quarto", c("render", f,
                        "--output", paste0(stem, ".pdf"),
                        "-M", "solutions:false"))
    message("Rebuilt: ", out_no)
  } else {
    message("Up to date: ", out_no)
  }
  
  # with solutions
  if (qmd_time > sol_time) {
    system2("quarto", c("render", f,
                        "--output", paste0(stem, "-sol.pdf"),
                        "-M", "solutions:true"))
    message("Rebuilt: ", out_sol)
  } else {
    message("Up to date: ", out_sol)
  }
}
