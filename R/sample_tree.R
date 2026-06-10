#' Sample Nodes at Each Level of a Tree
#'
#' Performs stratified random sampling on a hierarchical tree. At each level,
#' a specified number of child nodes are randomly selected from the available
#' nodes at that level. Two sampling strategies are supported:
#'
#' - \code{"level-wise"}: Sample N nodes uniformly from all nodes at each level,
#'   regardless of parent. Simpler control but may produce imbalanced trees.
#' - \code{"per-parent"} (default): For each selected parent node at level L,
#'   sample N child nodes at level L+1. Preserves tree balance and ensures
#'   coverage across all selected branches.
#'
#' @param tree A \code{data.tree} Node object returned by \code{\link{build_tree}}.
#' @param samples_per_level An integer vector specifying how many nodes to sample
#'   at each tree level. Length should equal the number of nominal variables.
#'   Use \code{NA} or value >= total available to keep all nodes at that level.
#' @param method Sampling method: \code{"per-parent"} (default) or \code{"level-wise"}.
#' @param seed An optional integer seed for reproducible sampling.
#'
#' @return A pruned \code{data.tree} Node object containing only the selected
#'   nodes and their descendants.
#'
#' @examples
#' \dontrun{
#' data(iris)
#' tree <- build_tree(iris, c("Species", "Sepal.Width"))
#' sampled <- sample_tree(tree, samples_per_level = c(2, 3))
#' print(sampled)
#' }
#'
#' @export
sample_tree <- function(tree, samples_per_level,
                        method = c("per-parent", "level-wise"),
                        seed = NULL) {

  if (!requireNamespace("data.tree", quietly = TRUE)) {
    stop("Package 'data.tree' is required. Please install it.", call. = FALSE)
  }

  method <- match.arg(method)

  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Determine tree depth
  depths <- data.tree::ToDataFrameTree(tree, "level")$level
  max_depth <- max(depths) - 1

  if (max_depth == 0) {
    warning("Tree has only root node. Returning unchanged tree.", call. = FALSE)
    return(data.tree::Clone(tree))
  }

  # Pad / trim samples_per_level
  if (length(samples_per_level) < max_depth) {
    samples_per_level <- c(samples_per_level, rep(NA, max_depth - length(samples_per_level)))
  } else if (length(samples_per_level) > max_depth) {
    samples_per_level <- samples_per_level[seq_len(max_depth)]
  }

  # Tree size safety check
  total_nodes <- tree$totalCount
  if (total_nodes > 50000) {
    warning(
      sprintf("Tree has %d nodes. Large trees may be slow. Consider reducing nominal variables.",
              total_nodes),
      call. = FALSE
    )
  }

  if (method == "level-wise") {
    result <- sample_level_wise(tree, samples_per_level)
  } else {
    result <- sample_per_parent(tree, samples_per_level)
  }

  return(result)
}


#' Per-parent sampling strategy
#'
#' For each selected parent node, sample N child nodes.
#' Works directly with node objects — no name-based lookup needed.
#'
#' @noRd
sample_per_parent <- function(tree, samples_per_level) {
  tree_clone <- data.tree::Clone(tree)
  current_nodes <- list(tree_clone)

  for (level in seq_along(samples_per_level)) {
    n_sample <- samples_per_level[level]

    if (is.na(n_sample)) {
      next_nodes <- unlist(lapply(current_nodes, function(n) n$children), recursive = FALSE)
      current_nodes <- next_nodes
      next
    }

    next_nodes <- list()
    for (node in current_nodes) {
      if (length(node$children) == 0) next

      if (length(node$children) <= n_sample) {
        selected_children <- node$children
      } else {
        selected_names <- sample(names(node$children), n_sample)
        selected_children <- node$children[selected_names]
        to_remove <- setdiff(names(node$children), selected_names)
        for (nm in to_remove) {
          node$RemoveChild(nm)
        }
      }
      next_nodes <- c(next_nodes, selected_children)
    }
    current_nodes <- next_nodes
  }

  prune_empty_branches(tree_clone)
  return(tree_clone)
}


#' Level-wise sampling strategy
#'
#' At each level, sample N nodes uniformly from all nodes at that level.
#' Fixed: works with node object references instead of name-based FindNode,
#' so it is robust even when nodes share display names across levels.
#'
#' @noRd
sample_level_wise <- function(tree, samples_per_level) {
  tree_clone <- data.tree::Clone(tree)

  for (level in seq_along(samples_per_level)) {
    n_sample <- samples_per_level[level]

    if (is.na(n_sample)) next

    # Get all nodes at this depth as objects (not names)
    target_depth <- level + 1  # root is level 1
    level_nodes <- data.tree::Traverse(
      tree_clone,
      filterFun = function(node) node$level == target_depth
    )

    if (length(level_nodes) <= n_sample) next

    # Sample by index into the node list (object-level, no name collision risk)
    keep_idx <- sample(seq_along(level_nodes), n_sample)
    remove_idx <- setdiff(seq_along(level_nodes), keep_idx)

    # Remove unselected nodes by accessing their parents directly via $parent
    for (idx in remove_idx) {
      victim <- level_nodes[[idx]]
      parent_node <- victim$parent
      if (!is.null(parent_node)) {
        parent_node$RemoveChild(victim$name)
      }
    }
  }

  prune_empty_branches(tree_clone)
  return(tree_clone)
}


#' Remove internal nodes that lost all children during pruning
#'
#' After sampling removes some children, some internal nodes may become empty
#' (non-leaf with zero children). This post-order traversal cleans them up.
#'
#' @param tree A data.tree Node object (will be modified in place)
#' @return The same tree, cleaned
#' @noRd
prune_empty_branches <- function(tree) {
  changed <- TRUE
  while (changed) {
    changed <- FALSE
    # Post-order: process leaves first, then move up
    all_internal <- data.tree::Traverse(
      tree,
      filterFun = function(n) !n$isLeaf && !n$isRoot,
      traversal = "post-order"
    )

    for (node in all_internal) {
      if (length(node$children) == 0) {
        parent <- node$parent
        if (!is.null(parent)) {
          parent$RemoveChild(node$name)
          changed <- TRUE
        }
      }
    }
  }

  return(tree)
}
