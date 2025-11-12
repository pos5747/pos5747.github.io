# Contact in Several Countries

---
  
  I model the probability that individual $i$ in district $j$ in election $k$ is contacted by a political party as

\begin{equation}
\text{Pr}(\text{Contacted}_{i} = 1) = \text{logit}^{-1}(\alpha_{jk} + {\bf X}_i\beta) \text{ ,}
\end{equation}

where $\alpha_{jk}$ represents an intercept that varies across districts and elections, ${\bf X}_i$ represents a matrix of individual-level covariates (excluding the constant), and $\beta$ represents a vector of non-varying coefficients. 

\begin{center}\rule{0.5\linewidth}{0.5pt}\end{center}

I model the varying intercept across districts as
\begin{equation}
\alpha_{jk} \sim N(\gamma_{0k} + \gamma_{1k}\text{Competitiveness}_j, \sigma^2_{\alpha}) \text{ for } j = 1, 2,..., J \text{ ,}
\end{equation}

where $J$ is the number of districts included in the analysis.

\begin{center}\rule{0.5\linewidth}{0.5pt}\end{center}

I model the varying intercepts and slopes across elections as

\begin{equation}
\begin{pmatrix} \gamma_{0k} \\ \gamma_{1k} \end{pmatrix} 
\sim 
{\large} N\begin{pmatrix}  \begin{pmatrix} \mu_{\gamma_{0}} \\ \mu_{\gamma_{1}} \end{pmatrix}, 
\begin{pmatrix}         \sigma^2_{\gamma_{0}}                                           &                 \rho\sigma_{\gamma_{0}}\sigma_{\gamma_{1}} \\
\rho\sigma_{\gamma_{0}}\sigma_{\gamma_{1}}         &                \sigma^2_{\gamma_{1}}
\end{pmatrix}\end{pmatrix} \text{ , for }k = 1, 2, ..., K \text{ ,}
\end{equation}
where 
\begin{equation}\label{eqn:disint_modeled}
\mu_{\gamma_{0}} = \delta_{00} + \delta_{01}\text{Proportional Rules}_k \text{  ,}
\end{equation}
\begin{equation}\label{eqn:comp_modeled}
\mu_{\gamma_{1}} = \delta_{10} + \delta_{11}\text{Proportional Rules}_k \text{ ,}
\end{equation}          
and $K$ is the number of elections included in the analysis.

---
  
  ```{r message=FALSE, warning=FALSE}
rainey <- read_csv("data/rainey_ld.csv") |>
  glimpse()
```

---
  
  ```{r}
# model is fragile
fit <- glmer(Contacted ~ District.Competitiveness*PR +
               (1 | District.Country) +
               (1 + District.Competitiveness | Alpha.Polity),
             data = rainey, family = binomial)

arm::display(fit)
```

---
  
  ```{r, results='hide', cache = TRUE}
#| warning: false
#| message: false

stan_fit <- stan_glmer(Contacted ~ District.Competitiveness*PR +
                         (1 | District.Country) + 
                         (1 + District.Competitiveness | Alpha.Polity),
                       data = rainey, 
                       family = binomial, 
                       chains = 10,
                       cores = 10,
                       iter = 2000)
```

(We can also use `brm()` here.)

---
  
  ```{r}
hist(summary(stan_fit)[, "Rhat"])
```

---
  
  \small

```{r}
#| warning: false
#| message: false

# compute posterior average for each district
pred_district <- rainey %>%
  select(District.Country, 
         Alpha.Polity, 
         District.Competitiveness, 
         PR) %>%
  distinct() %>%
  add_epred_draws(stan_fit) %>%
  summarize(post_avg = mean(.epred)) %>%
  glimpse()
```

---
  
  \small

```{r}
#| warning: false
#| message: false

# compute posterior average for each country (in a 'typical' district)
pred_country <- rainey %>%
  select(District.Country, 
         Alpha.Polity, 
         District.Competitiveness, 
         PR) %>%
  distinct() %>%
  add_epred_draws(stan_fit, 
                  re_formula = ~ (1 + District.Competitiveness | Alpha.Polity)) %>%
  summarize(post_avg = mean(.epred)) %>%
  glimpse()
```

---
  
  ```{r}
#| fig-asp: 0.5
#| warning: false
#| message: false

ggplot(pred_district, aes(x = District.Competitiveness, y = post_avg)) +
  facet_wrap(vars(Alpha.Polity)) +
  geom_point() +
  geom_line(data = pred_country, color = "red", size = 1.5)
```