
data {
  int<lower=0> N;
  int<lower=1> K;
  array[N] int<lower=0, upper=1> y;
  matrix[N, K] X;
}
parameters {
  vector[K] beta;
}
model {
  beta ~ normal(0, 5);               // weakly informative prior
  y ~ bernoulli_logit(X * beta);     // logistic regression likelihood
}

