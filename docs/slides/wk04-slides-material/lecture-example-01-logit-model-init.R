
# ---- fit logit model with optim() ----

# data 
devtools::install_github("jrnold/ZeligData")
turnout <- ZeligData::turnout

# formula
f <- vote ~ age + educate + income + race

# fit model
fit <- glm(f, data = turnout, family = binomial)

# coefficient estimates
coef(fit)

# variance estimates
vcov(fit)

# make X and y
mf <- model.frame(f, data = turnout)
X <- model.matrix(f, data = mf)
y <- model.response(mf)

# log-likelihood function
logit_ll <- function(beta, y, X) {
  linpred <- X%*%beta  # perhaps denoted eta
  p <- plogis(linpred) # pi is special in R, so I use p
  ll <- sum(dbinom(y, size = 1, prob = p, log = TRUE))
  return(ll)
}

# use optim
par_start <- rep(0, ncol(X))
opt <- optim(par_start, 
             fn = logit_ll, 
             y = y, 
             X = X, # ← covariates! 🎉
             method = "BFGS",
             hessian = TRUE,
             control = list(fnscale = -1))
opt$par

