

library(tidyverse)
library(rstan)
library(tidybayes)

answers <- read_csv("slides/wk09-slides/materials/example-answers.csv") |>
  #ilter(student_id_num <= 10) |>
  glimpse()

grades <- answers %>% 
  group_by(student_id_num) %>%
  summarize(proportion_correct = mean(correct_answer), 
            se = sqrt(mean(correct_answer)*(1 - mean(correct_answer)))/sqrt(n())) |>
  mutate(
    letter_grade = case_when(
      proportion_correct >= 0.93 ~ "A",
      proportion_correct >= 0.90 ~ "A-",
      proportion_correct >= 0.87 ~ "B+",
      proportion_correct >= 0.83 ~ "B",
      proportion_correct >= 0.80 ~ "B-",
      proportion_correct >= 0.77 ~ "C+",
      proportion_correct >= 0.73 ~ "C",
      proportion_correct >= 0.70 ~ "C-",
      proportion_correct >= 0.67 ~ "D+",
      proportion_correct >= 0.63 ~ "D",
      proportion_correct >= 0.60 ~ "D-",
      TRUE ~ "F"
    ),
    letter_grade = reorder(letter_grade, -proportion_correct, ordered = TRUE)
  )


# Let: 
# - n in {1,...,N} index answers
# - j in {1,...,J} index students
# - k in {1,...,K} index questions
# -----
# - jj is a vector of student indices for each answer
# - kk is a vector of question indices for each answer
data_list <- list(
  # upper bounds of indices
  N = nrow(answers),
  J = max(answers$student_id_num), 
  K = max(answers$question_id_num), 
  # indices for each respondent
  jj = answers$student_id_num,
  kk = answers$question_id_num,
  # observed answers
  y = answers$correct_answer
)

stan_code <- "
data {
  // scalars
  int<lower=1> N;                       // number of answers
  int<lower=1> J;                       // number of students
  int<lower=1> K;                       // number of questions
  // vectors of length N
  int<lower=1, upper=J> jj[N];          // student index for answer n
  int<lower=1, upper=K> kk[N];          // question index for answer n
  int<lower=0, upper=1> y[N];           // answer n is correct (0/1)
}

parameters {
  real mu;                      
  vector[J] alpha;                      // abilities; one per student
  vector[K] beta;                       // difficulties; one per question

  real<lower=0> sigma_beta;             // SD of difficulties
  real<lower=0> sigma_alpha;             // SD of abilities
}

model {
  // priors for SDs
  sigma_beta ~ cauchy(0, 1);
  sigma_alpha ~ cauchy(0, 1);

  // mean difficulty 
  mu ~ cauchy(0, 1);

  // abilities, difficultes, and discrimations
  alpha ~ normal(0, sigma_alpha);
  beta ~ normal(0, sigma_beta);

  // likelihood
  for (n in 1:N) {
    y[n] ~ bernoulli_logit(mu + alpha[jj[n]] - beta[kk[n]]);
  }
}
"

fit <- stan(model_code = stan_code, 
            data = data_list,
            iter = 10000, 
            warmup = 3000,
            chains = 10, 
            cores = 10)

print(fit)

alpha_draws <- spread_draws(fit, alpha[student_id_num]) |>
  mean_qi() |>
  glimpse()

fit %>%
  spread_draws(alpha[student_id_num], ndraws = 100) %>%
  median_qi() %>%
  left_join(grades) %>%
  ggplot(aes(x = alpha, xmin = .lower, xmax = .upper, 
             y = reorder(student_id_num, alpha), 
             color = letter_grade)) +
  #geom_label(aes(label = scales::percent(proportion_correct, accuracy = 1)), vjust = -0.3) + 
  geom_pointinterval(linewidth = 0.5, size = 0.5) + 
  theme_minimal()

beta_draws <- spread_draws(fit, beta[question_id_num]) |>
  median_qi() |>
  arrange(desc(beta)) |>
  select(question_id_num, beta) |> 
  glimpse()

fit %>%
  spread_draws(beta[question_id_num]) %>%
  median_qi() %>%
  ggplot(aes(x = beta, xmin = .lower, xmax = .upper, 
             y = reorder(question_id_num, beta))) +
  geom_pointinterval(linewidth = 0.5, size = 0.5) + 
  theme_minimal()

q <- answers |>
  group_by(question_id_num) |>
  summarize(prop_correct = mean(correct_answer)) |>
  ungroup() %>%
  left_join(beta_draws) |>
  glimpse()

ggplot(q, aes(x = beta, y = prop_correct)) + 
  geom_point()

q |>
  select(question_id, nu
