# load packages
library(tidyverse)
library(marginaleffects)

# data 
devtools::install_github("jrnold/ZeligData")
turnout <- ZeligData::turnout

# fit model
f <- vote ~ age + educate + income + race
fit <- glm(f, family = binomial, data = turnout)

# ev as age ranges from 18 to 90; others at mean/mode
predictions(fit, datagrid(age = 18:90)) 

# fd as age moves across iqr; others at every observed value
comparisons(fit, variables = list(age = "iqr")) 

# avg of the fds above
avg_comparisons(fit, variables = list(age = "iqr")) 

