# Treesampler: Tree-Structured Stratified Sampling

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/LICENSE)
[![R](https://img.shields.io/badge/R-%3E=3.5.0-blue.svg)](https://www.r-project.org/)

Extract representative subsets from tabular data using **tree-structured stratified sampling** — ideal for fast code prototyping on large datasets.

## Why Treesampler?

When working with a large data frame (tens to hundreds of thousands of rows), every debugging cycle takes too long. Treesampler helps you:

1. **Auto-build a tree from nominal variables** — expand categorical columns into a hierarchical structure
2. **Control sampling at each level** — specify how many nodes to sample per parent
3. **Generate reproducible subsets** — preserve original distribution, reduce size by 10–100x
4. **Copy R code in one click** — sampling parameters are fully reproducible and shareable

## Installation

### From GitHub (recommended)

```r
# install.packages("remotes")
remotes::install_github("rcjhrpyt-droid/treesampler")
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
  final_n = 3,                       # random rows per leaf node
  seed = 42                          # reproducible seed
)

head(result)     # view the subset
nrow(result)    # subset row count
```

Or call each step separately:

```r
tree <- build_tree(mtcars, c("cyl", "vs"))                              # build tree
sampled <- sample_tree(tree, c(3, 2))                                   # stratified sampling
subset <- extract_subset(mtcars, sampled, c("cyl", "vs"), final_n = 5)  # extract subset
```

## Core Functions

| Function | Description |
|----------|-------------|
| `treesampler()` | All-in-one: build tree → sample → extract subset |
| `build_tree()` | Build a `data.tree` from nominal variables |
| `sample_tree()` | Perform per-level stratified sampling on the tree |
| `extract_subset()` | Extract sampled rows from original data |
| `run_treesampler_app()` | Launch the interactive Shiny application |

## Algorithm

1. **Tree Building**: Each row of data is mapped to a tree path according to user-selected nominal variables (max depth 10). If different columns share identical values, internal nodes get an automatic `_colN` suffix.
2. **Sampling**: At each non-leaf level, randomly select a specified number of child nodes under each parent.
3. **Extraction**: At the final level, randomly draw `final_n` rows from each leaf node's corresponding data.

Expected total ≈ `samples_per_level[1] * samples_per_level[2] * ... * final_n` (limited by actual data availability).

## Dependencies

- **R >= 3.5.0**
- data.tree, dplyr, shiny, DT, collapsibleTree, readxl, readr

## License

[MIT](LICENSE)
