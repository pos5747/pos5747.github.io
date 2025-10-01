# a function for rejection algorithm
rej <- function(f, S, M) {
  
  # record start time
  start_time <- Sys.time()
  
  # create containers and initialize counters
  samples <- numeric(S)  # container to store samples
  rejects <- NULL  # container to track rejected values; for teaching; slow!
  s <- 1 # currently trying to take sample 1
  n_prop <- 0  # count proposals (for an acceptance-rate message)
  
  # so long as the current sample s is less 
  #   than the desired samples S.
  #   do the following:
  while (s <= S) { 
    
    # A: propose z ~ uniform(0,1)
    z <- runif(1)
    
    # B: draw u ~ uniform(0,1)
    u <- runif(1)
    
    # C: Accept or reject
    fz <- f(z) # compute once, for effeciency
    
    ## scenario 1: u <= f(z)/M  →  Accept
    if (u <= fz / M) {
      samples[s] <- z
      s <- s + 1
    } 
    
    ## scenario 2: f(z) > M  →  shouldn't happen; error
    if (fz > M) stop("Stop: Envelope M is too small.")  # find appropriate M
    
    ## scenario 3: u > f(z)/M  →  Reject
    ##   tracking these values just for teaching and learning--not needed usually
    if (u > fz / M) {
      rejects <- c(rejects, z)
    }
    
    # track total proposals so far
    n_prop <- n_prop + 1
  }
  
  # print a summary report
  message(
    paste0(
      "💪 Successfully generated ", scales::comma(S), " samples! 🎉\n\n",
      "✅ Accepted samples: ", scales::comma(S), "\n",
      "❌ Rejected samples: ", scales::comma(length(rejects)), "\n",
      "﹪ Acceptance rate: ", scales::percent(S / n_prop, accuracy = 1), "\n",
      "⏰ Total time: ", prettyunits::pretty_dt(Sys.time() - start_time)
    )
  )
  
  # return
  list(
    n_prop = n_prop,
    acc_rate = S / n_prop,
    samples = samples,
    rejects = rejects
  )
}


# unnormalized prior
prior_saw <- function(p, n_teeth = 5) {
  ((n_teeth*p) %% 1)
}

# likelihood (10 tosses; 1 success )
lik <- function(p) {
  p^1 * (1-p)^9
}

# unnormalized posterior
unnormalized_posterior <- function(p) {
  lik(p)*prior_saw(p)
}

# rejection algorithm
r <- rej(unnormalized_posterior, S = 10000, M = 0.03)

# posterior mean
mean(r$samples)

# 90% credible interval
quantile(r$samples, probs = c(0.05, 0.95))

# histogram
hist(r$samples, breaks = 100)
