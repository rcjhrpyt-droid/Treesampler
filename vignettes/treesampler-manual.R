#' Treesampler: User Manual
#'
#' @title Treesampler User Manual
#' @name treesampler-manual
#' @description A complete guide to tree-structured stratified sampling with
#'   the treesampler package. Covers installation, core functions, sampling
#'   strategies, parameters, step-by-step API, Shiny app, and FAQ.
#'
#' @details
#'
#' ## What is treesampler?
#'
#' \strong{treesampler} is an R package that builds a hierarchical tree from
#' categorical variables in tabular data and performs stratified node-level
#' sampling at each layer of the tree. It is designed for rapidly generating
#' small yet representative data subsets for code prototyping and debugging,
#' before running analysis on full datasets.
#'
#' When working with large data frames (tens to hundreds of thousands of rows),
#' every debugging cycle takes too long. Treesampler helps you:
#' \enumerate{
#'   \item Auto-build a tree from categorical/nominal variables
#'   \item Control sampling at each level with two strategies
#'   \item Generate reproducible subsets (10--100x smaller)
#'   \item Copy shareable R code in one click
#' }
#'
#' ## Installation
#'
#' From GitHub:
#' \preformatted{
#' # install.packages("remotes")
#' remotes::install_github("rcjhrpyt-droid/Treesampler")
#' }
#'
#' ## Quick Start
#'
#' ### Option 1: Interactive Shiny App
#'
#' \preformatted{
#' library(treesampler)
#' run_treesampler_app()
#' }
#'
#' A browser window opens automatically with support for uploading files,
#' drag-and-drop variable reordering, visual tree confirmation, strategy
#' selection (\code{"per-parent"} / \code{"level-wise"}), per-level sample
#' size configuration, result download (CSV/RDS), and one-click copy of
#' reproducible R code.
#'
#' ### Option 2: Function Call
#'
#' \preformatted{
#' library(treesampler)
#'
#' result <- treesampler(
#'   data = mtcars,
#'   nominal_vars = c("cyl", "vs", "am"),
#'   samples_per_level = c(2, 2, 2),
#'   method = "per-parent",
#'   final_n = 3,
#'   seed = 42
#' )
#'
#' head(result)
#' nrow(result)
#' print(result)
#' }
#'
#' ## Core Functions
#'
#' \tabular{ll}{
#'   \code{treesampler()} \tab All-in-one: build tree -> sample -> extract subset\cr
#'   \code{build_tree()} \tab Build a \code{data.tree::Node} from nominal variables\cr
#'   \code{sample_tree()} \tab Stratified sampling on the tree (\code{"per-parent"} or \code{"level-wise"})\cr
#'   \code{extract_subset()} \cap Extract sampled rows, with optional \code{final_n} cap\cr
#'   \code{run_treesampler_app()} \tab Launch the interactive Shiny application\cr
#' }
#'
#' @section Two Sampling Strategies:
#'
#' Treesampler offers two strategies controlling \strong{how nodes are selected}
#' at each tree level:
#'
#' \subsection{\code{method = "per-parent"} (default)}{
#' For each parent node selected at the previous level, independently sample N
#' child nodes from its own children.
#'
#' \preformatted{
#'           Root                    Root
#'          / | \                   /   \
#'        A   B   C    --sample->   A     C    (B dropped)
#'       /|\  |\            =>    /|\     |
#'      1 2 3 4 5                 1 2     6
#' }
#'
#' \itemize{
#'   \item Every selected branch gets downstream representation
#'   \item Tree stays balanced across branches
#'   \item \strong{Recommended for most use cases}
#' }
#' }
#'
#' \subsection{\code{method = "level-wise"}}{
#' Pool all nodes at each level together, then uniformly sample N regardless of
#' which parent they belong to.
#'
#' \preformatted{
#'           Root                    Root
#'          / | \                   / | \
#'        A   B   C    --sample->   A B C   (pooled)
#'       /|\  |\            =>     | |
#'      1 2 3 4 5                 2 6
#' }
#'
#' \itemize{
#'   \item Simpler control over total node count per level
#'   \item Some branches may end up empty
#'   \item Use when you only care about total coverage, not balance
#' }
#' }
#'
#' @section Parameters:
#'
#' \describe{
#'   \item{\code{data}}{A data frame containing your data.}
#'   \item{\code{nominal_vars}}{Character vector of column names defining the tree
#'     hierarchy. Order matters: first variable = top level. Maximum 10 variables.
#'     Character/factor columns preferred; numeric columns with <=12 unique values
#'     are also accepted.}
#'   \item{\code{samples_per_level}}{Integer vector specifying how many nodes to
#'     sample at each level. Positive integer N = sample N nodes; NA = keep all
#'     nodes at that level. Shorter than \code{nominal_vars} auto-pads with NA;
#'     longer vectors are truncated.}
#'   \item{\code{method}}{Sampling strategy: \code{"per-parent"} (default) or
#'     \code{"level-wise"}. See the Strategies section above for details.}
#'   \item{\code{final_n}}{Integer or NULL. After stratified filtering, randomly
#'     sample up to this many rows from each leaf group. NULL (default) means take
#'     all rows. Useful when leaf groups have very different sizes.}
#'   \item{\code{seed}}{Integer or NULL. Random seed for reproducible results.}
#'   \item{\code{return_tree}}{Logical. If TRUE, attach the sampled
#'     \code{data.tree::Node} object as attribute \code{"sampled_tree"}.}
#' }
#'
#' @section Step-by-Step API:
#'
#' For finer control over intermediate steps, call the three low-level functions
#' separately:
#'
#' \preformatted{
#' # Step 1: Build the full hierarchy
#' tree <- build_tree(mtcars, c("cyl", "vs"))
#'
#' # Step 2: Sample nodes at each level
#' sampled <- sample_tree(tree, c(3, 2), method = "per-parent")
#'
#' # Step 3: Extract matching rows from original data
#' subset <- extract_subset(mtcars, sampled, c("cyl", "vs"), final_n = 5)
#' }
#'
#' @section Algorithm:
#'
#' \enumerate{
#'   \item \strong{Tree Building}: Each row is mapped to a tree path according to
#'     user-selected nominal variables (max depth 10). If different columns share
#'     identical value strings, internal nodes get an automatic \code{_colN} suffix
#'     for disambiguation.
#'   \item \strong{Sampling}: At each non-root level, select child nodes according
#'     to the chosen strategy:
#'     \itemize{
#'       \item \code{"per-parent"}: under each surviving parent, pick N children
#'       \item \code{"level-wise"}: from all nodes at this depth, pick N uniformly
#'     }
#'   \item \strong{Extraction}: At the leaf level, randomly draw up to
#'     \code{final_n} rows from each leaf group's data.
#' }
#'
#' Expected total rows ~ \code{samples_per_level[1] * samples_per_level[2] * ... * final_n},
#' limited by actual data availability.
#'
#' @section Examples:
#'
#' Basic usage with iris:
#'
#' \preformatted{
#' library(treesampler)
#'
#' data(iris)
#' result <- treesampler(iris,
#'   nominal_vars = "Species",
#'   samples_per_level = 2,
#'   seed = 42
#' )
#' print(result)
#' }
#'
#' Multi-level tree with discretized variable:
#'
#' \preformatted{
#' iris2 <- iris
#' iris2$Sepal.Width_cat <- cut(iris2$Sepal.Width,
#'   breaks = c(2, 3, 3.5, 4.5),
#'   labels = c("narrow", "medium", "wide")
#' )
#'
#' result2 <- treesampler(iris2,
#'   nominal_vars = c("Species", "Sepal.Width_cat"),
#'   samples_per_level = c(2, 2),
#'   seed = 123
#' )
#' print(result2)
#' }
#'
#' Comparing the two strategies:
#'
#' \preformatted{
#' pp <- treesampler(iris, "Species",
#'   samples_per_level = 2, method = "per-parent", seed = 42)
#' lw <- treesampler(iris, "Species",
#'   samples_per_level = 2, method = "level-wise", seed = 42)
#'
#' table(pp$Species)
#' table(lw$Species)
#' }
#'
#' Using final_n to cap rows per leaf group:
#'
#' \preformatted{
#' data(mtcars)
#'
#' sub_all <- treesampler(mtcars, "cyl",
#'   samples_per_level = 2, seed = 42)
#' sub_cap <- treesampler(mtcars, "cyl",
#'   samples_per_level = 2, final_n = 3, seed = 42)
#'
#' nrow(sub_all)  # no cap
#' nrow(sub_cap)  # capped at 3 per group
#' table(sub_cap$cyl)
#' }
#'
#' Reproducibility with seed:
#'
#' \preformatted{
#' r1 <- treesampler(iris, "Species", 1, seed = 123)
#' r2 <- treesampler(iris, "Species", 1, seed = 123)
#' identical(r1, r2)  # TRUE
#' }
#'
#' Return tree object for further analysis:
#'
#' \preformatted{
#' result_tree <- treesampler(iris, "Species",
#'   samples_per_level = 2, seed = 42, return_tree = TRUE)
#' tree_obj <- attr(result_tree, "sampled_tree")
#' print(tree_obj)
#' }
#'
#' Full workflow on simulated e-commerce data:
#'
#' \preformatted{
#' set.seed(2024)
#' n <- 1000
#' user_data <- data.frame(
#'   user_id = 1:n,
#'   region  = sample(c("East", "South", "North", "West"), n, replace = TRUE),
#'   tier    = sample(c("VIP", "Regular", "New"), n, replace = TRUE),
#'   channel = sample(c("App", "Web", "MiniApp"), n, replace = TRUE),
#'   amount  = round(rnorm(n, mean = 200, sd = 80), 2),
#'   stringsAsFactors = FALSE
#' )
#'
#' user_sub <- treesampler(user_data,
#'   nominal_vars      = c("region", "tier", "channel"),
#'   samples_per_level = c(3, 2, 2),
#'   final_n           = 3,
#'   seed              = 99
#' )
#'
#' print(user_sub)
#' table(user_sub$region, user_sub$tier)
#' # 1000 rows -> ~36 rows (3.6%), covering all key dimension combos
#' }
#'
#' @section FAQ:
#'
#' \describe{
#'   \item{Can I use continuous numeric variables?}{
#'     Yes, but discretize them first with \code{cut()}. Otherwise each unique
#'     numeric value becomes its own node, which can make the tree enormous.
#'   }
#'   \item{What happens to missing values?}{
#'     \code{build_tree()} automatically removes rows with NA in any of the
#'     \code{nominal_vars} columns and issues a warning.
#'   }
#'   \item{The tree is too large / browser is slow?}{
#'     Reduce the number of \code{nominal_vars}, or increase
#'     \code{samples_per_level} values to prune more aggressively. A warning is
#'     issued when the tree exceeds 50,000 nodes.
#'   }
#'   \item{How do I get stable/reproducible results?}{
#'     Set the \code{seed} parameter. Different seeds produce different samples;
#'     try a few until you find one you like.
#'   }
#' }
#'
#' @seealso \code{\link{treesampler}}, \code{\link{build_tree}},
#'   \code{\link{sample_tree}}, \code{\link{extract_subset}},
#'   \code{\link{run_treesampler_app}}
#'
#' @author Wenzhe Huang \email{51280155097@stu.ecnu.edu.cn}
#'
#' @keywords internal
NULL
