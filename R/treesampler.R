#' Treesampler: Tree-Stratified Sampling from Tabular Data
#'
#' The main orchestrating function. Builds a hierarchical tree from nominal
#' variables, performs stratified sampling at each level, and returns a
#' representative subset of the data.
#'
#' Use this function to quickly generate a smaller, structured subset of a
#' large dataset for code testing before running on full data.
#'
#' @param data A data frame.
#' @param nominal_vars A character vector of column names defining the tree
#'   hierarchy. Variables are ordered from top to bottom. Maximum 10 variables.
#' @param samples_per_level An integer vector specifying how many nodes to
#'   sample at each tree level. Use \code{NA} to keep all nodes at that level.
#'   If shorter than \code{nominal_vars}, remaining levels keep all nodes.
#' @param method Sampling method: \code{"per-parent"} (default) or \code{"level-wise"}.
#' @param final_n Integer or NULL. After stratified sampling, randomly sample
#'   up to this many rows from each leaf group (the "non-stratified" final layer).
#'   Default \code{NULL} means take all rows in each leaf group.
#' @param seed Optional integer seed for reproducible sampling.
#' @param return_tree Logical. If \code{TRUE}, attach the sampled tree as an
#'   attribute named \code{"sampled_tree"}. Default \code{FALSE}.
#'
#' @return A data frame of class \code{\link[treesampler]{treesampler}} containing
#'   only the sampled rows. Attributes include \code{n_original}, \code{n_subset},
#'   \code{sampling_method}, \code{nominal_vars}, \code{samples_per_level}.
#'
#' @examples
#' \dontrun{
#' data(iris)
#'
#' sub <- treesampler(iris,
#'   nominal_vars = c("Species"),
#'   samples_per_level = 2,
#'   seed = 42
#' )
#'
#' # Two-level tree
#' sub2 <- treesampler(iris,
#'   nominal_vars = c("Species", "Sepal.Width"),
#'   samples_per_level = c(2, 3),
#'   seed = 42
#' )
#'
#' # With tree object returned
#' result <- treesampler(iris,
#'   nominal_vars = c("Species"),
#'   samples_per_level = 1,
#'   return_tree = TRUE
#' )
#' }
#'
#' @importFrom stats complete.cases
#' @export
treesampler <- function(data,
                        nominal_vars,
                        samples_per_level,
                        method = c("per-parent", "level-wise"),
                        final_n = NULL,
                        seed = NULL,
                        return_tree = FALSE) {

  method <- match.arg(method)

  if (!is.data.frame(data)) {
    stop("'data' must be a data frame.", call. = FALSE)
  }

  if (length(nominal_vars) == 0) {
    stop("'nominal_vars' must contain at least one variable name.", call. = FALSE)
  }

  missing_vars <- setdiff(nominal_vars, names(data))
  if (length(missing_vars) > 0) {
    stop(
      "The following nominal_vars are not in data: ",
      paste(missing_vars, collapse = ", "),
      call. = FALSE
    )
  }

  if (length(samples_per_level) < length(nominal_vars)) {
    samples_per_level <- c(
      samples_per_level,
      rep(NA, length(nominal_vars) - length(samples_per_level))
    )
    message(
      "samples_per_level has fewer elements than nominal_vars. ",
      "Unspecified levels will keep all nodes."
    )
  } else if (length(samples_per_level) > length(nominal_vars)) {
    samples_per_level <- samples_per_level[seq_along(nominal_vars)]
    warning(
      "samples_per_level has more elements than nominal_vars. Extra values ignored.",
      call. = FALSE
    )
  }

  tree <- build_tree(data, nominal_vars)
  sampled_tree <- sample_tree(tree, samples_per_level, method = method, seed = seed)
  result <- extract_subset(data, sampled_tree, nominal_vars,
                           final_n = final_n, seed = seed)

  attr(result, "sampled_tree") <- if (return_tree) sampled_tree else NULL
  attr(result, "n_original") <- nrow(data)
  attr(result, "n_subset") <- nrow(result)
  attr(result, "sampling_method") <- method
  attr(result, "nominal_vars") <- nominal_vars
  attr(result, "samples_per_level") <- samples_per_level
  attr(result, "final_n") <- final_n

  class(result) <- c("treesampler", class(result))

  message(
    sprintf("Subset extracted: %d rows (%.1f%% of original %d rows)",
            nrow(result), nrow(result) / nrow(data) * 100, nrow(data))
  )

  return(result)
}


#' Print method for treesampler objects
#'
#' Displays a summary of the sampling operation: original vs subset size,
#' method used, and variable hierarchy.
#'
#' @param x A treesampler object.
#' @param ... Additional arguments passed to \code{\link[base]{print.data.frame}}.
#'
#' @return Invisibly returns \code{x}.
#'
#' @export
print.treesampler <- function(x, ...) {
  cat("Treesampler subset\n")
  cat("--------------------\n")
  cat("Original rows:", attr(x, "n_original"), "\n")
  cat("Subset rows:  ", attr(x, "n_subset"), "\n")
  cat("Sampling:     ", attr(x, "sampling_method"), "on",
      length(attr(x, "nominal_vars")), "levels")
  if (!is.null(attr(x, "final_n"))) {
    cat(" + final_n =", attr(x, "final_n"))
  }
  cat("\n")
  cat("Variables:    ", paste(attr(x, "nominal_vars"), collapse = " > "), "\n\n")

  NextMethod()
}
