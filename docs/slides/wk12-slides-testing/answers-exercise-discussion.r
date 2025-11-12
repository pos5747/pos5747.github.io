
# load packages
library(tidyverse)
library(rstan)
library(tidybayes)

# load data
answers <- read_csv("https://pos5747.github.io/data/example-answers.csv") |>
  glimpse()

# cretate 1-PL Stan model
stan_code <- "
data {
  int<lower=1> N;  // number of answers
  int<lower=1> J;  // number of students
  int<lower=1> K;  // number of questions
  int<lower=1, upper=J> jj[N];  // student index for answer n
  int<lower=1, upper=K> kk[N];  // question index for answer n
  int<lower=0, upper=1> y[N];  // answer n is correct (0/1)
}

parameters {
  real mu;  // mean difficulty
  vector[J] alpha;  // abilities; one per student
  vector[K] beta;  // difficulties; one per question
  real<lower=0> sigma_beta;  // SD of difficulties
  real<lower=0> sigma_alpha;  // SD of abilities
}

model {
  sigma_beta ~ cauchy(0, 1);  // prior for SD of difficulties
  sigma_alpha ~ cauchy(0, 1);  // prior for SD of abilities
  mu ~ cauchy(0, 10);  // prior for mean difficulty
  alpha ~ normal(0, sigma_alpha);  // abilities
  beta ~ normal(0, sigma_beta);  // difficulties
  for (n in 1:N) {
    y[n] ~ bernoulli_logit(mu + alpha[jj[n]] - beta[kk[n]]);  // likelihood
  }
}
"

# make data for stan
data_list <- list(
  # upper bounds of indices
  N = nrow(answers),                 # - n in {1,...,N} indexes answers
  J = max(answers$student_id_num),   # - j in {1,...,J} indexes students
  K = max(answers$question_id_num),  # - k in {1,...,K} indexes questions
  # indices for each respondent
  jj = answers$student_id_num,   # jj is a vector of student indices for each answer
  kk = answers$question_id_num,  # kk is a vector of question indices for each answer
  # observed answers
  y = answers$correct_answer
)

# fit <- stan(model_code = stan_code, 
#             data = data_list,
#             iter = 4000, 
#             warmup = 2000,
#             chains = 4, 
#             cores = 4)
# 
# # save the fitted model
# script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
# saveRDS(fit, file = paste0(script_dir, "fit.rds"))

# load the fitted model
script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
fit <- readRDS(paste0(script_dir, "fit.rds"))

# check that iter is large enough
print(fit)

# compute grades
grades <- answers %>% 
  group_by(student_id_num) %>%
  summarize(proportion_correct = mean(correct_answer)) %>%
  mutate(
    letter_grade = cut(
      proportion_correct,
      breaks = c(-Inf, 0.60, 0.63, 0.67, 0.70, 0.73, 0.77, 0.80, 0.83, 0.87, 0.90, 0.93, Inf),
      labels = c("F",  "D-", "D",  "D+", "C-", "C",  "C+", "B-", "B",  "B+", "A-", "A"),
      ordered_result = TRUE
    )
  )

# plot abilities
fit %>%
  # this is a powerful, but subtle function for working with stan() output
  # see ?spread_draws()
  # it creates a data frame
  # - alpha contains the simulates of the parameters named 'alpha'
  # - 'student_id_num' contain the index for the particular 'alpha'
  spread_draws(alpha[student_id_num]) %>% 
  # this works like group_by() -> summarize()
  # - spread_draws groups by the index 'student_id_num'
  # - computes the posterior median and 95% quantile interval
  median_qi() %>%  
  # join in the letter grades
  left_join(grades) %>%
  # sample only 25 students to look at
  slice_sample(n = 25) %>%
  # plot it
  ggplot(aes(x = alpha, xmin = .lower, xmax = .upper, 
             y = reorder(student_id_num, alpha), 
             color = letter_grade)) +
  geom_pointinterval(linewidth = 0.5, size = 0.5) + 
  theme_minimal() + 
  labs(y = "random sample of 25 students", 
       color = "letter grade")

# plot difficulties
fit %>%
  spread_draws(beta[question_id_num]) %>%
  median_qi() %>%
  ggplot(aes(x = beta, xmin = .lower, xmax = .upper, 
             y = reorder(question_id_num, beta))) +
  geom_pointinterval(linewidth = 0.5, size = 0.5) + 
  theme_minimal() + 
  coord_flip() + 
  labs(x = "question")

# new code starts here ----

# cretate 2-PL Stan model
stan_code2 <- "
data {
  int<lower=1> N;  // number of answers
  int<lower=1> J;  // number of students
  int<lower=1> K;  // number of questions
  int<lower=1, upper=J> jj[N];  // student index for answer n
  int<lower=1, upper=K> kk[N];  // question index for answer n
  int<lower=0, upper=1> y[N];  // answer n is correct (0/1)
}

parameters {
  real mu;  // mean difficulty
  vector[J] alpha;  // abilities; one per student
  vector[K] beta;  // difficulties; one per question
  vector<lower=0>[K] gamma;                                            // +++++ CHANGE 3a: ADD DISCRIMINATION PARAMETER 
  real<lower=0> sigma_beta;  // SD of difficulties
  // real<lower=0> sigma_alpha;                                        // +++++ CHANGE 1a: DELETE THIS PARAMETER 

}

model {
  sigma_beta ~ cauchy(0, 1);  // prior for SD of difficulties
  // sigma_alpha ~ cauchy(0, 1);  // prior for SD of abilities         // +++++ CHANGE 1b: DELETE THIS PARAMETER 
  mu ~ cauchy(0, 10);  // prior for mean difficulty
  alpha ~ normal(0, 1);  // abilities //                               // +++++ CHANGE 1c: MAKE SD 1
  beta ~ normal(mu, sigma_beta);  // difficulties                      // +++++ CHANGE 2a: MOVE MU INTO DISTRIBUTIN OF BETA
  gamma ~ normal(0, 10);                                               // +++++ CHANGE 3b: ADD DISCRIMINATION PARAMETER 

  for (n in 1:N) {
    y[n] ~ bernoulli_logit(gamma[kk[n]]*(alpha[jj[n]] - beta[kk[n]])); // +++++ CHANGE 2b: REMOVE MU; CHANGE 3b ADD DISCRIMINATIO
  }
}
"

# fit2 <- stan(model_code = stan_code2, 
#             data = data_list,
#             iter = 4000, 
#             warmup = 200,
#             chains = 4, 
#             cores = 4)
# 
# # save the fitted model
# script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)
# saveRDS(fit2, file = paste0(script_dir, "fit2.rds"))

# load the fitted model
fit2 <- readRDS(paste0(script_dir, "fit2.rds"))


# plot abilities
alpha1 <- fit %>%
  spread_draws(alpha[student_id_num]) %>% 
  median_qi() %>%
  select(student_id_num, alpha1 = alpha) %>%
  mutate(rank1 = rank(-alpha1)) %>%
  glimpse()

alpha2 <- fit2 %>%
  spread_draws(alpha[student_id_num]) %>% 
  median_qi() %>%
  select(student_id_num, alpha2 = alpha) %>%
  mutate(rank2 = rank(-alpha2)) %>%
  glimpse()

alpha <- full_join(alpha1, alpha2) 

ggplot(alpha, aes(x = rank1, y = rank2)) + 
  geom_abline(intercept = 0, slope = 1) + 
  geom_segment(aes(x = rank1, xend = rank1, y = rank1, yend = rank2)) + 
  geom_point()
