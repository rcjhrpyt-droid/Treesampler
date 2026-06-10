# Treesampler: Tree-Structured Stratified Sampling

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/LICENSE)
[![R](https://img.shields.io/badge/R-%3E=3.5.0-blue.svg)](https://www.r-project.org/)

Extract representative subsets from tabular data using **tree-structured stratified sampling** — ideal for fast code prototyping on large datasets.

## Why Treesampler?

When working with a large data frame (tens to hundreds of thousands of rows), every debugging cycle takes too long. Treesampler helps you:

1. **Auto-build a tree from categorical variables** — expand nominal columns into a hierarchical structure
2. **Control sampling at each level** — specify how many nodes to sample, with two strategies
3. **Generate reproducible subsets** — preserve original distribution, reduce size by 10–100x
4. **Copy R code in one click** — sampling parameters are fully reproducible and shareable

## Installation

### From GitHub (recommended)

```r
# install.packages("remotes")
remotes::install_github("rcjhrpyt-droid/Treesampler")
```

## Quick Start

### Option 1: Interactive Shiny App

```r
library(treesampler)
run_treesampler_app()
```

A browser window opens automatically with full support for:

- Upload CSV / TSV / Excel / RDS files (max 50 MB)
- Drag-and-drop variable reordering
- Visual tree confirmation
- Choose sampling strategy: **per-parent** or **level-wise**
- Per-level sample size configuration
- Preview & download results (CSV / RDS)
- One-click copy of reproducible R code

### Option 2: Function Call

```r
library(treesampler)

result <- treesampler(
  data = mtcars,
  nominal_vars = c("cyl", "vs", "am"),
  samples_per_level = c(2, 2, 2),   # nodes per parent at each level
  method = "per-parent",             # "per-parent" or "level-wise"
  final_n = 3,                       # random rows per leaf node
  seed = 42                          # reproducible seed
)

head(result)     # view the subset
nrow(result)    # subset row count
print(result)   # summary with metadata
```

Or call each step separately for finer control:

```r
tree <- build_tree(mtcars, c("cyl", "vs"))                                      # Step 1: build tree
sampled <- sample_tree(tree, c(3, 2), method = "per-parent")                   # Step 2: stratified sampling
subset <- extract_subset(mtcars, sampled, c("cyl", "vs"), final_n = 5)         # Step 3: extract subset
```

## Two Sampling Strategies

Treesampler offers two strategies that control **how nodes are selected at each tree level**:

### `method = "per-parent"` (default)

For each parent node selected at the previous level, independently sample N child nodes from its own children.

- Every selected branch gets downstream representation
- Tree stays balanced across branches

### `method = "level-wise"`

Pool all nodes at each level together, then uniformly sample N regardless of which parent they belong to.

- Simpler control over total node count per level
- Some branches may end up empty
- Use when you only care about total coverage, not balance

## Core Functions

| Function | Description |
|----------|-------------|
| `treesampler()` | All-in-one: build tree -> sample -> extract subset |
| `build_tree()` | Build a `data.tree::Node` from nominal variables |
| `sample_tree()` | Perform stratified sampling on the tree (`"per-parent"` or `"level-wise"`) |
| `extract_subset()` | Extract sampled rows from original data, with optional `final_n` cap |
| `run_treesampler_app()` | Launch the interactive Shiny application |

## Algorithm

1. **Tree Building**: Each row of data is mapped to a tree path according to user-selected nominal variables (max depth 10). If different columns share identical values, internal nodes get an automatic `_colN` suffix.
2. **Sampling**: At each non-root level, select child nodes according to the chosen strategy:
   - `"per-parent"`: under each surviving parent, pick N children
   - `"level-wise"`: from all nodes at this depth, pick N uniformly
3. **Extraction**: At the leaf level, randomly draw up to `final_n` rows from each leaf group.

Expected total rows ~ `samples_per_level[1] * samples_per_level[2] * ... * final_n` (limited by actual data availability).

## Documentation

For detailed usage examples, parameter explanations, and a full walkthrough, see the package vignette:

```r
vignette("treesampler-manual", package = "treesampler")
```

## Dependencies

- **R >= 3.5.0**
- data.tree, dplyr, shiny, DT, collapsibleTree, readxl, readr

## License

[MIT](LICENSE)
