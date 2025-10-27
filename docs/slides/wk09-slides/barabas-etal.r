
library(tidyverse)

d <- haven::read_dta("slides/wk09-slides/data/Smasterimp_3-24.dta") 

d2 <- d |>
  select(rid, SQ, S, knowcor) |>
  glimpse()
