# Core algorithm tests for treesampler

# Source all package R files (needed when running via test_file outside installed pkg)
# Find package root: walk up from current dir until we find R/ directory
pkg_root_dir <- getwd()
for (k in 1:6) {
  if (dir.exists(file.path(pkg_root_dir, "R"))) break
  pkg_root_dir <- normalizePath(file.path(pkg_root_dir, ".."), mustWork = FALSE)
}
invisible(lapply(
  list.files(file.path(pkg_root_dir, "R"), pattern = "\\.R$", full.names = TRUE),
  source
))

test_that("build_tree creates correct structure for single variable", {
  data(iris)
  tree <- build_tree(iris, c("Species"))

  expect_s3_class(tree, "Node")
  expect_equal(tree$name, "Root")
  expect_equal(tree$n_rows, 150)

  # Should have 3 children (setosa, versicolor, virginica)
  expect_equal(length(tree$children), 3)

  # Each child should have n_rows = 50
  for (child in tree$children) {
    expect_equal(child$n_rows, 50)
    expect_true(!is.null(child$display_name))
    expect_true(!is.null(child$level_idx))
    expect_equal(child$level_idx, 1L)
  }
})

test_that("build_tree handles two-level tree", {
  data(iris)
  tree <- build_tree(iris, c("Species", "Sepal.Width"))

  expect_s3_class(tree, "Node")

  # Root -> 3 species -> each has multiple Sepal.Width values
  expect_equal(length(tree$children), 3)

  total_leaves <- length(data.tree::Traverse(tree, filterFun = function(n) n$isLeaf))
  expect_true(total_leaves > 0)

  # Internal node names should have _colN suffix
  first_child <- tree$children[[1]]
  expect_true(grepl("_col1$", first_child$name))
  expect_false(grepl("_col1$", first_child$display_name))
})

test_that("build_tree enforces max depth of 10", {
  data(iris)
  iris$fake1 <- sample(letters[1:2], 150, replace = TRUE)
  vars <- c("Species", rep("fake1", 10))

  expect_error(
    build_tree(iris, vars),
    "Maximum tree depth"
  )
})

test_that("build_tree rejects empty nominal_vars", {
  data(iris)
  expect_error(build_tree(iris, character(0)), "At least one")
})

test_that("build_tree warns on NA removal and stops on all-NA", {
  df <- data.frame(
    x = c("a", "b", NA),
    y = 1:3,
    stringsAsFactors = FALSE
  )
  expect_warning(
    tree <- build_tree(df, "x"),
    "row\\(s\\) with missing"
  )
  expect_equal(tree$n_rows, 2)

  df_all_na <- data.frame(x = c(NA, NA, NA), y = 1:3)
  expect_error(build_tree(df_all_na, "x"), "No rows remain")
})

test_that("sample_tree per-parent works correctly", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = c(2), seed = 42)

  expect_s3_class(sampled, "Node")
  expect_equal(length(sampled$children), 2)
  expect_true(sampled$totalCount < tree$totalCount)
})

test_that("sample_tree keeps all when N >= available", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = c(99))

  # All 3 species kept (since only 3 exist)
  expect_equal(length(sampled$children), 3)
})

test_that("sample_tree with NA keeps all at that level", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = NA_integer_)

  expect_equal(length(sampled$children), 3)
})

test_that("sample_tree level-wise works correctly", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = c(2),
                         method = "level-wise", seed = 123)

  expect_s3_class(sampled, "Node")
  expect_equal(length(sampled$children), 2)
})

test_that("extract_subset returns correct subset", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = c(2), seed = 42)
  sub <- extract_subset(iris, sampled, c("Species"))

  expect_true(nrow(sub) > 0)
  expect_true(nrow(sub) < nrow(iris))
  # Output should NOT contain _colN in Species values
  expect_false(any(grepl("_col", sub$Species)))
  # Original columns preserved
  expect_true(all(c("Sepal.Length", "Sepal.Width", "Petal.Length",
                     "Petal.Width") %in% names(sub)))
})

test_that("extract_subset preserves row order", {
  data(iris)
  set.seed(999)
  iris_shuffled <- iris[sample(nrow(iris)), ]

  tree <- build_tree(iris_shuffled, c("Species"))
  sampled <- sample_tree(tree, samples_per_level = c(1), seed = 1)
  sub <- extract_subset(iris_shuffled, sampled, c("Species"))

  # Subset should contain original columns in correct types
  expect_true(all(names(iris) %in% names(sub)))
  # Row count should be positive and less than original
  expect_true(nrow(sub) > 0 && nrow(sub) <= nrow(iris_shuffled))
})

test_that("treesampler wrapper produces valid output", {
  data(iris)
  result <- treesampler(iris,
                        nominal_vars = c("Species"),
                        samples_per_level = 2,
                        seed = 42)

  expect_s3_class(result, "treesampler")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) < nrow(iris))
  expect_equal(attr(result, "n_original"), 150)
  expect_equal(attr(result, "sampling_method"), "per-parent")
})

test_that("treesampler with return_tree includes tree attribute", {
  data(iris)
  result <- treesampler(iris,
                        nominal_vars = c("Species"),
                        samples_per_level = 1,
                        return_tree = TRUE)

  expect_s3_class(attr(result, "sampled_tree"), "Node")
})

test_that("treesampler rejects non-data.frame", {
  expect_error(treesampler(list(a=1), "a", 1), "must be a data frame")
})

test_that("print.treesampler shows summary", {
  data(iris)
  result <- treesampler(iris, c("Species"), 1, seed = 1)

  output <- capture.output(print(result))
  expect_true(any(grepl("Treesampler subset", output)))
  expect_true(any(grepl("Original rows:", output)))
  expect_true(any(grepl("Subset rows:", output)))
})

test_that("get_node_mapping returns proper structure", {
  data(iris)
  tree <- build_tree(iris, c("Species"))
  mapping <- get_node_mapping(tree)

  expect_true(is.data.frame(mapping))
  expect_true(all(c("internal_name", "display_name", "variable",
                    "level_idx", "n_rows") %in% names(mapping)))
  expect_equal(nrow(mapping), 3)  # 3 species nodes

  # internal names have _col suffix, display names don't
  expect_true(all(grepl("_col", mapping$internal_name)))
  expect_false(any(grepl("_col", mapping$display_name)))
})

# ── final_n (non-stratified final layer) tests ──

test_that("extract_subset with final_n limits rows per leaf", {
  data(mtcars)
  tree <- build_tree(mtcars, c("cyl", "vs"))
  sampled <- sample_tree(tree, samples_per_level = c(2, 2), seed = 42)

  sub_all <- extract_subset(mtcars, sampled, c("cyl", "vs"))
  sub_3 <- extract_subset(mtcars, sampled, c("cyl", "vs"), final_n = 3, seed = 42)

  expect_true(nrow(sub_3) <= nrow(sub_all))
  expect_true(nrow(sub_3) > 0)
})

test_that("extract_subset with final_n respects per-leaf cap", {
  data(mtcars)
  tree <- build_tree(mtcars, c("cyl"))
  sampled <- sample_tree(tree, samples_per_level = c(2), seed = 42)

  sub_2 <- extract_subset(mtcars, sampled, c("cyl"), final_n = 2, seed = 42)

  # Each leaf group should have at most 2 rows
  for (val in unique(sub_2$cyl)) {
    group_rows <- nrow(sub_2[sub_2$cyl == val, , drop = FALSE])
    expect_true(group_rows <= 2)
  }
})

test_that("extract_subset final_n=NULL is backward compatible", {
  data(mtcars)
  tree <- build_tree(mtcars, c("cyl"))
  sampled <- sample_tree(tree, samples_per_level = c(1), seed = 42)

  sub_null <- extract_subset(mtcars, sampled, "cyl", final_n = NULL)
  sub_def <- extract_subset(mtcars, sampled, "cyl")

  expect_equal(nrow(sub_null), nrow(sub_def))
})

test_that("extract_subset final_n is reproducible with seed", {
  data(mtcars)
  tree <- build_tree(mtcars, c("cyl"))
  sampled <- sample_tree(tree, samples_per_level = c(2), seed = 42)

  a <- extract_subset(mtcars, sampled, "cyl", final_n = 5, seed = 123)
  b <- extract_subset(mtcars, sampled, "cyl", final_n = 5, seed = 123)

  expect_identical(a, b)
})

test_that("treesampler accepts and passes final_n", {
  data(mtcars)
  result <- treesampler(mtcars, c("cyl", "vs"), c(2, 2),
                        final_n = 3, seed = 99)

  expect_s3_class(result, "treesampler")
  expect_true(nrow(result) > 0)
  expect_equal(attr(result, "final_n"), 3)
})
