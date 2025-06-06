#' Function to generate imputations using SuperLearner for data with a continuous outcome
#'
#' @param y Vector of observed and missing/imputed values of the variable to be imputed.
#' @param x Numeric matrix of variables to be used as predictors in SuperLearner models
#' with rows corresponding to observed values of the variable to be imputed and
#' columns corresponding to individual predictor variables.
#' @param wy Logical vector. A TRUE value indicates locations in \code{y} that are
#' missing or imputed.
#' @param SL.library Either a character vector of prediction algorithms or a
#' list containing character vectors. A list of functions included in the
#' SuperLearner package can be found with \code{SuperLearner::listWrappers()}.
#' @param bw Numeric value or numeric vector for bandwidth of kernel function (as
#' standard deviations of the kernel).
#' @param bw.update logical indicating whether bandwidths should be computed
#' every iteration or only on the first iteration.  Default is \code{TRUE},
#' but \code{FALSE} may speed up the run time at the cost of accuracy.
#' @param kernel one of \code{gaussian}, \code{uniform}, or \code{triangular}.
#' Specifies the kernel to be used in estimating the distribution around a missing value.
#' @param ... further arguments passed to \code{SuperLearner()}.
#' @return numeric vector of randomly drawn imputed values.

continuousSuperLearner <- function(y, x, wy, SL.library, kernel, bw, bw.update, ...) {
  if (!is.numeric(bw)) {
    stop("`bw` must be a numeric value or numeric vector.")
  }

  newdata <- data.frame(x)
  colnames <- paste0("x", seq_len(ncol(newdata)))
  names(newdata) <- colnames

  X <- data.frame(x[!wy,])
  names(X) <- colnames
  Y <- y[!wy]
  missing_indices <- which(wy)

  args <- c(list(Y = Y, X = X, family = stats::gaussian(),
                 SL.library = SL.library),
            list(...))
  args$type <- NULL
  sl <- do.call(SuperLearner, args)
  sl.preds <- predict.SuperLearner(object = sl, newdata = newdata, X = X, Y = Y,
                                   onlySL = TRUE)$pred

  if (length(bw) == 1) {
    bw <- as.list(rep(bw, times = sum(wy)))
  } else if (!bw.update) {
    bw <- sapply(missing_indices, jackknifeBandwidthSelection,
                 bwGrid = bw,
                 preds = sl.preds,
                 y = y,
                 delta = as.numeric(!wy),
                 kernel = kernel)
    bw <- as.list(bw)
    p <- parent.frame(2)
    p$args$bw <- bw
  } else {
    bw <- sapply(missing_indices, jackknifeBandwidthSelection,
                 bwGrid = bw,
                 preds = sl.preds,
                 y = y,
                 delta = as.numeric(!wy),
                 kernel = kernel)
    bw <- as.list(bw)
  }

  imputed_values <- sapply(seq_along(missing_indices), localImputation,
                           preds = sl.preds, y = y,
                           delta = as.numeric(!wy),
                           bw = bw, kernel = kernel)

  return(imputed_values)
}