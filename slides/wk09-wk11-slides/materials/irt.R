
library(tidyverse)
library(rstan)
library(tidybayes)

answers <- read_csv("slides/wk09-slides/materials/answers.csv") |>
  # tidy up the variable names to my usual conventions; lowercase, underscores
  rename(student_id = Student, question_id = Question, correct_answer = Correct) |>
  # create integer indices *in additional* to the labels above
  #  - Stan likes integers
  #  - humans like labels
  #  - using the approach below, the integers correspond the the alphabetical 
  #    rank of the label. This means Q2 > Q13, so be careful!
  mutate(student_id_num = as.integer(factor(student_id)),
         question_id_num = as.integer(factor(question_id))) |>
  #slice_sample(n = 100) |>
  glimpse()

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
  real mu_beta;                      
  vector[J] alpha;                      // abilities; one per student
  vector[K] beta;                       // difficulties; one per question
  vector<lower=0>[K] gamma;             // discriminations; one per question

  real<lower=0> sigma_beta;             // SD of difficulties
  real<lower=0> sigma_gamma;            // SD of log-discriminations
}

model {
  // priors for SDs
  sigma_beta ~ cauchy(0, 1);
  sigma_gamma ~ cauchy(0, 0.2);
  
  // mean difficulty 
  mu_beta ~ cauchy(0, 1);

  // abilities, difficultes, and discrimations
  alpha ~ std_normal();
  beta ~ normal(mu_beta, sigma_beta);
  gamma ~ lognormal(0, sigma_gamma);

  // likelihood
  for (n in 1:N) {
    y[n] ~ bernoulli_logit(gamma[kk[n]] * (alpha[jj[n]] - beta[kk[n]]));
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

b <- beta_draws <- spread_draws(fit, beta[question_id_num]) |>
  median_qi() |>
  arrange(beta) |>
  select(question_id_num, beta) |> 
  glimpse()

g <- gamma_draws <- spread_draws(fit, gamma[question_id_num]) |>
  median_qi() |>
  arrange(desc(gamma)) |>
  select(question_id_num, gamma) |> 
  glimpse()

q <- answers |>
  group_by(question_id, question_id_num) |>
  summarize(prop_correct = mean(correct_answer)) |>
  ungroup() %>%
  left_join(b) |>
  left_join(g) |>
  glimpse()

all_pars <- tidy_draws(fit)

obs_questions <- b |>
  left_join(g) |>
  glimpse()


new_students <- tibble(student_id_num = 1:100) %>%
  mutate(alpha = rnorm(n(), mean = 0, sd = 1)) |>
  glimpse()

fake_data <- crossing(question_id_num = unique(answers$question_id_num),
                      student_id_num = unique(new_students$student_id_num)) |>
  left_join(obs_questions) |>
  left_join(new_students) |> 
  mutate(linpred = gamma * (alpha - beta), 
         p = plogis(linpred),
         correct_answer = rbinom(n(), size = 1, prob = p)) |>
  select(student_id_num, question_id_num, correct_answer) %>%
  arrange(student_id_num, question_id_num) |>
  write_csv("slides/wk09-slides/materials/example-answers.csv") |>
  glimpse()

f2 <- fake_data %>% group_by(question_id_num) %>%
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
    letter_grade = reorder(letter_grade, -proportion_correct)
  )

table(f2$letter_grade)


x2 <- as_tibble(x, rownames = "Question")

f3 <- full_join(f2, b) %>%
  glimpse()

plot(f3$proportion_correct, f3$beta)
