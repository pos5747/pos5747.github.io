
# run just once, then delete
devtools::install_github("carlislerainey/crdata")

# load packages
library(tidyverse)
library(sandwich)  # for robust SEs

# load Clark and Golder's data
cg <- crdata::cg2006  # from my data package

# quick look at variables and their names
glimpse(cg)