#' Extract Subset Rows from Original Data Based on Sampled Tree
#'
#' Given a sampled (pruned) tree and the original data, extracts all rows
#' that match the paths preserved in the tree. Each leaf-to-root path defines
#' a filter condition across the nominal variables.
#'
#' Internal node names carry \code{_colN} suffixes for disambiguation.
#' This function strips those suffixes and returns clean column values in
#' the output subset — no trace of internal naming remains.
#'
#' @param data The original data frame.
#' @param sampled_tree A pruned \code{data.tree} Node object returned by
#'   \code{\link{sample_tree}}.
#' @param nominal_vars The character vector of nominal variable names used
#'   to build the tree (same order as in \code{\link{build_tree}}).
#' @param final_n Integer. After stratified filtering, randomly sample up to
#'   this many rows from each leaf group. Default \code{NULL} means take all.
#' @param seed Integer or NULL. Random seed for reproducibility of the
#'   final-layer random sampling. Default \code{NULL}.
#'
#' @return A data frame containing only the rows matching sampled tree paths,
#'   with at most \code{final_n} rows per leaf group if specified.
#'   All original columns are preserved with their original names and types.
#'
#' @examples
#' \dontrun{
#' data(iris)
#' tree <- build_tree(iris, c("Species"))
#' sampled <- sample_tree(tree, samples_per_level = c(2))
#' subset <- extract_subset(iris, sampled, c("Species"), final_n = 5, seed = 42)
#' }
#'
#' @export
extract_subset <- function(data, sampled_tree, nominal_vars,
                           final_n = NULL, seed = NULL) {
  if (!requireNamespace("data.tree", quietly = TRUE)) {
    stop("Package 'data.tree' is required. Please install it.", call. = FALSE)
  }

  # Set seed for reproducibility of final random sampling layer
  if (!is.null(seed)) set.seed(seed)

  leaf_paths <- collect_leaf_paths(sampled_tree)

  if (length(leaf_paths) == 0) {
    warning("The sampled tree has no leaves. Returning empty data frame.", call. = FALSE)
    return(data[integer(0), , drop = FALSE])
  }

  # Build filter data frame using display_name (stripped of _colN suffix)
  filter_rows <- vector("list", length(leaf_paths))

  for (i in seq_along(leaf_paths)) {
    path <- leaf_paths[[i]]
    row <- list()

    for (j in seq_along(nominal_vars)) {
      var_name <- nominal_vars[j]
      # path contains internal node names; strip _colN to get display value
      raw_val <- if (j <= length(path)) path[[j]] else NA_character_
      display_val <- strip_col_suffix(raw_val)
      row[[var_name]] <- display_val
    }

    filter_rows[[i]] <- as.data.frame(row, stringsAsFactors = FALSE)
  }

  filter_df <- do.call(rbind, filter_rows)

  # Align column types with original data
  for (var in nominal_vars) {
    if (var %in% names(data)) {
      if (is.factor(data[[var]])) {
        filter_df[[var]] <- factor(filter_df[[var]], levels = levels(data[[var]]))
      } else if (is.numeric(data[[var]])) {
        filter_df[[var]] <- as.numeric(filter_df[[var]])
      } else {
        filter_df[[var]] <- as.character(filter_df[[var]])
      }
    }
  }

  # Merge with row-id to preserve original order
  orig_data <- data
  orig_data$.row_id__ <- seq_len(nrow(orig_data))
  result <- merge(orig_data, filter_df, by = nominal_vars, all = FALSE)

  # Final non-stratified layer: randomly sample up to final_n rows per leaf group
  if (!is.null(final_n) && final_n > 0 && nrow(result) > 0) {
    result$.grp_id__ <- interaction(result[nominal_vars], drop = TRUE)
    result <- do.call(rbind, by(result, result$.grp_id__, function(g) {
      if (nrow(g) <= final_n) return(g)
      g[sample(nrow(g), final_n), , drop = FALSE]
    }))
    result$.grp_id__ <- NULL
  }

  result <- result[order(result$.row_id__), , drop = FALSE]
  result$.row_id__ <- NULL
  rownames(result) <- NULL

  return(result)
}


#' Strip internal \code{_colN} suffix from node name
#'
#' @param x A character string, possibly ending with \code{_colN}
#' @return The string without the suffix, or \code{x} unchanged if no suffix found
#' @noRd
strip_col_suffix <- function(x) {
  # Pattern: ends with _col followed by digits
  gsub("_col[0-9]+$", "", x)
}


#' Collect all leaf-to-root filter paths from a tree
#'
#' For each leaf node, returns the sequence of internal node names
#' along the path from root to leaf (excluding Root itself).
#'
#' @param tree A data.tree Node object
#' @return A list of character vectors, each representing one leaf path
#' @noRd
collect_leaf_paths <- function(tree) {
  leaf_nodes <- data.tree::Traverse(tree, filterFun = function(n) n$isLeaf)

  lapply(leaf_nodes, function(leaf) {
    leaf$path[-1]  # remove "Root"
  })
}
