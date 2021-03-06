## function: overlapping group selection based on R Package 'grpreg' 
## update (6/21/2016): adapt for cox model
# ------------------------------------------------------------------------------
grpregOverlap <- function(X, y, group, 
                          penalty=c("grLasso", "grMCP", "grSCAD", "gel", 
                                    "cMCP", "gLasso", "gMCP"), 
                          family=c("gaussian","binomial", "poisson", 'cox'), 
                          nlambda=100, lambda, 
                          lambda.min={if (nrow(X) > ncol(X)) 1e-4 else .05},
                          alpha=1, eps=.001, max.iter=1000, dfmax=ncol(X), 
                          gmax=length(group), 
                          gamma=ifelse(penalty=="grSCAD", 4, 3), tau=1/3, 
                          group.multiplier, 
                          returnX = FALSE, returnOverlap = FALSE,
                          warn=TRUE, ...) {

  # Error checking
  if (class(X) != "matrix") {
    tmp <- try(X <- as.matrix(X), silent=TRUE)
    if (class(tmp)[1] == "try-error")  {
      stop("X must be a matrix or able to be coerced to a matrix")
    }   
  }
  if (storage.mode(X)=="integer") X <- 1.0*X

  incid.mat <- incidenceMatrix(X, group) # group membership incidence matrix
  over.mat <- over.temp <- Matrix(incid.mat %*% t(incid.mat)) # overlap matrix
  grp.vec <- rep(1:nrow(over.mat), times = diag(over.mat)) # group index vector
  X.latent <- expandX(X, group)
 
  diag(over.temp) <- 0
  if (all(over.temp == 0)) {
    cat("Note: There are NO overlaps between groups at all!", "\n") 
    cat("      Now conducting non-overlapping group selection ...")
  }
  
  ## Improvement 1 (9/17/2015): Handle situation where variables listed in groups NOT IN X !
  ## This case is possible in pathway selection, where not all genes in some pathways have expression data recorded. 
  ## The exsiting code can already handle this in the sense that those genes not in X 
  ## will not be included the expanded design matrix, except that the group.multiplier vector
  ## needs to be updated with the actual group size (i.e., the size after removing those non-exsiting genes), which can be done using "over.mat".
  
  ## Improvement 2 (3/7/2016): Handle cases where variables in X don't match at 
  ##    all variables in a group, i.e., cases where diag(over.mat) has zero cells.
  gs <- diag(over.mat)
  gs <- gs[gs != 0]  
  
  penalty <- match.arg(penalty)
  if (missing(group.multiplier)) {
    if (strtrim(penalty,2)=="gr") {
      group.multiplier <- sqrt(gs)
    } else {
      group.multiplier <- rep(1, length(group))
    }
  }
  
  family <- match.arg(family)
  if (family != 'cox') {
    fit <- grpreg(X = X.latent, y = y, group = grp.vec, penalty=penalty,
                  family=family, nlambda=nlambda, lambda=lambda, 
                  lambda.min=lambda.min, alpha=alpha, eps=eps, 
                  max.iter=max.iter, dfmax=dfmax, 
                  gmax=gmax, gamma=gamma, tau=tau, 
                  group.multiplier=group.multiplier, warn=warn, ...)
  } else {
    ## survival analysis
    fit <- grpsurv(X = X.latent, y = y, group = grp.vec, penalty = penalty,
                   gamma = gamma, alpha = alpha, nlambda = nlambda, 
                   lambda = lambda, 
                   lambda.min = lambda.min, eps = eps, max.iter = max.iter, 
                   dfmax=dfmax, gmax=gmax, tau=tau, 
                   group.multiplier=group.multiplier, warn=warn, ...)
  }
 
  fit$beta.latent <- fit$beta # fit$beta from grpreg is latent beta
  fit$beta <- gamma2beta(gamma = fit$beta, incid.mat, grp.vec, family = family)
  fit$incidence.mat <- incid.mat
  fit$group <- group
  fit$grp.vec <- grp.vec # this is 'group' argument in Package 'grpreg'
  fit$family <- family
  if (returnX) {
    fit$X.latent <- X.latent
  } 
  if (returnOverlap) {
    fit$overlap.mat <- over.mat
  }
  
  if (family != 'cox') {
    # get results, store in new class 'grpregOverlap', and inherited from 'grpreg'
    val <- structure(fit,
                     class = c('grpregOverlap', 'grpreg'))
  } else {
    val <- structure(fit, 
                     class = c("grpsurvOverlap", "grpregOverlap"))
  }
  val
}
# -------------------------------------------------------------------------------

## function: convert latent beta coefficients (gamma's) to non-latent beta's
## update (6/21/2016): adapt for cox model
# -------------------------------------------------------------------------------
gamma2beta<- function(gamma, incidence.mat, grp.vec, family) {
  # gamma: matrix, ncol = length(lambda), nrow = # of latent vars.
  p <- ncol(incidence.mat)
  J <- nrow(incidence.mat)
  beta <- matrix(0, ncol = ncol(gamma), nrow = p)
  
  if (family != 'cox') {
    intercept <- gamma[1, , drop = FALSE]
    gamma <- gamma[-1, , drop = FALSE]
  } else {
    # Cox model doesn't have an intercept
    gamma <- gamma
  }
  
  for (i in 1:J) {
    ind <- which(incidence.mat[i, ] == 1)
    beta[ind, ] <- beta[ind, ] + gamma[which(grp.vec == i), , drop = FALSE]
  }
  if (family != 'cox') {
    beta <- rbind(intercept, beta)         
    rownames(beta) <- c("(Intercept)", colnames(incidence.mat))
  } else {
    rownames(beta) <- colnames(incidence.mat)
  }
  beta
}
# -------------------------------------------------------------------------------


## function: expand design matrix X to overlapping design matrix (X.latent)
# -------------------------------------------------------------------------------
expandX <- function(X, group) {
  incidence.mat <- incidenceMatrix(X, group) # group membership incidence matrix
  over.mat <- Matrix(incidence.mat %*% t(incidence.mat), sparse = TRUE, 
                     dimnames = dimnames(incidence.mat)) # overlap matrix
  grp.vec <- rep(1:nrow(over.mat), times = diag(over.mat)) # group index vector
  
  # expand X to X.latent
  X.latent <- NULL
  names <- NULL

  ## the following code will automatically remove variables not included in 'group'
  for(i in 1:nrow(incidence.mat)) {
    idx <- incidence.mat[i,]==1
    X.latent <- cbind(X.latent, X[, idx, drop=FALSE])
    names <- c(names, colnames(incidence.mat)[idx])
#     colnames(X.latent) <- c(colnames(X.latent), colnames(X)[incidence.mat[i,]==1])
  }
  colnames(X.latent) <- paste('grp', grp.vec, '_', names, sep = "")
  X.latent
}
# -------------------------------------------------------------------------------
