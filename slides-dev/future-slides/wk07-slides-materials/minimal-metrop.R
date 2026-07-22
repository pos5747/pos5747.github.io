metrop <- function(logf, theta_start, S = 10000, tau = 0.1, ...) {
  # initialize matrix of samples with starting values
  k <- length(theta_start)
  samples <- matrix(NA_real_, nrow = S, ncol = k)
  samples[1, ] <- theta_start
  
  # proceed with algorithm
  for (s in 2:S) {
    # extract current location
    current <- samples[s - 1, ]
    
    # generate symmetric random-walk proposal
    proposed_move <- runif(k, -tau, tau)
    proposal <- current + proposed_move
    
    # acceptance step
    delta <- logf(proposal, ...) - logf(current, ...)
    if (delta > 0) {
      accept <- TRUE
    } else {
      accept <- (log(runif(1)) <= delta)
    }
    
    # update samples
    if (accept) {
      samples[s, ] <- proposal
    } else {
      samples[s, ] <- current
    }
  }
  
  # return
  samples
}

