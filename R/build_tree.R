#' Build a Hierarchical Tree from Nominal Variables
#'
#' Constructs a tree structure from a data frame based on specified nominal
#' (categorical) variables. Each level of the tree corresponds to one variable,
#' and each node represents a unique value combination at that level.
#'
#' To avoid ambiguity when different variables share identical value strings,
#' internal node names are suffixed with \code{_colN} (where N is the 1-based
#' position among nominal_vars). These suffixes are stripped automatically
#' by \code{\link{extract_subset}} before returning results.
#'
#' @param data A data frame containing the variables.
#' @param nominal_vars A character vector of column names to use as tree levels.
#'   Maximum length is 10. Variables are applied in order, from top to bottom
#'   of the tree.
#' @param max_depth Integer. Maximum number of levels allowed. Default 10.
#'
#' @return A \code{data.tree} Node object representing the hierarchical structure.
#'   Each non-root node has:
#'   \itemize{
#'     \item{\code{variable}: The variable name at this level}
#'     \item{\code{n_rows}: Number of data rows under this node}
#'     \item{\code{display_name}: The original value string (without suffix)}
#'     \item{\code{level_idx}: 1-based index into nominal_vars}
#'   }
#'
#' @examples
#' \dontrun{
#' data(iris)
#' tree <- build_tree(iris, c("Species", "Sepal.Width"))
#' print(tree)
#' }
#'
#' @importFrom data.tree Node
#' @export
build_tree <- function(data, nominal_vars, max_depth = 10L) {
  if (!requireNamespace("data.tree", quietly = TRUE)) {
    stop("Package 'data.tree' is required. Please install it.", call. = FALSE)
  }

  # Depth limit
  if (length(nominal_vars) > max_depth) {
    stop(
      "Maximum tree depth is ", max_depth,
      ". You provided ", length(nominal_vars), " variables.",
      call. = FALSE
    )
  }

  if (length(nominal_vars) == 0) {
    stop("At least one nominal variable must be specified.", call. = FALSE)
  }

  missing_vars <- setdiff(nominal_vars, names(data))
  if (length(missing_vars) > 0) {
    stop(
      "The following variables are not found in data: ",
      paste(missing_vars, collapse = ", "),
      call. = FALSE
    )
  }

  # Remove rows with NA in nominal variables
  complete_idx <- stats::complete.cases(data[, nominal_vars, drop = FALSE])
  n_removed <- sum(!complete_idx)
  if (n_removed > 0) {
    warning(
      n_removed, " row(s) with missing values in nominal variables were removed.",
      call. = FALSE
    )
    data <- data[complete_idx, , drop = FALSE]
  }

  if (nrow(data) == 0) {
    stop("No rows remain after removing missing values.", call. = FALSE)
  }

  root <- data.tree::Node$new("Root")
  root$variable <- NA_character_
  root$n_rows <- nrow(data)

  build_level <- function(node, subset, level_idx) {
    if (level_idx > length(nominal_vars)) return()

    var <- nominal_vars[level_idx]
    values <- unique(subset[[var]])

    for (val in values) {
      # Internal name: append _colN suffix for disambiguation
      internal_name <- paste0(as.character(val), "_col", level_idx)

      child <- node$AddChild(internal_name)
      child$variable <- var
      child$display_name <- as.character(val)
      child$filter_value <- val
      child$level_idx <- level_idx

      child_data <- subset[subset[[var]] == val, , drop = FALSE]
      child$n_rows <- nrow(child_data)

      build_level(child, child_data, level_idx + 1)
    }
  }

  build_level(root, data, 1)

  # Add human-readable label
  root$Do(function(node) {
    if (node$isRoot) {
      node$level_name <- "Root"
      node$display_name <- "Root"
    } else {
      node$level_name <- paste0(node$variable, " = ", node$display_name)
    }
  })

  return(root)
}


#' Get the mapping between internal node names and display names
#'
#' Returns a named list where each element maps an internal node name
#' (with \code{_colN} suffix) to its display name and variable info.
#' Used internally by Shiny app for display purposes.
#'
#' @param tree A \code{data.tree} Node object returned by \code{\link{build_tree}}.
#'
#' @return A data frame with columns: \code{internal_name}, \code{display_name},
#'   \code{variable}, \code{level_idx}, \code{n_rows}.
#'
#' @noRd
get_node_mapping <- function(tree) {
  all_nodes <- data.tree::Traverse(tree, filterFun = function(n) !n$isRoot)

  data.frame(
    internal_name = sapply(all_nodes, function(n) n$name),
    display_name = sapply(all_nodes, function(n) n$display_name),
    variable = sapply(all_nodes, function(n) n$variable),
    level_idx = sapply(all_nodes, function(n) n$level_idx),
    n_rows = sapply(all_nodes, function(n) n$n_rows),
    stringsAsFactors = FALSE
  )
}
