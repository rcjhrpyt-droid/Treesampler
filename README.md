# Treesampler: 树状分层抽样工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R](https://img.shields.io/badge/R-%3E=3.5.0-blue.svg)](https://www.r-project.org/)

从表格数据中按**树状分层结构**抽取代表性子集，用于代码测试和快速迭代。

## 为什么需要 Treesampler？

当你面对一个大型数据框（几万到几十万行）时，每次调试代码都要等很久。Treesampler 帮你：

1. **按分类变量自动建树** — 将 nominal 变量展开为层级结构
2. **逐层控制抽样量** — 每层指定抽取多少个节点
3. **生成可复现的子表** — 保留原始分布特征，体积缩小 10-100 倍
4. **一键复制 R 代码** — 抽样参数可复现，方便分享

## 安装

### 从 GitHub 安装（推荐）

```r
# install.packages("remotes")
remotes::install_github("your-username/Treesampler")
```

### 本地安装

```r
# install.packages("devtools")
devtools::install_local("Treesampler")
```

## 快速开始

### 方式一：交互式界面（Shiny App）

```r
library(treesampler)
run_treesampler_app()
```

浏览器会自动打开，支持：
- 上传 CSV / TSV / Excel / RDS 文件（最大 50MB）
- 拖拽排序变量层级
- 可视化确认树结构
- 配置每层抽样参数
- 预览并下载结果（CSV / RDS）
- 一键复制可复现的 R 代码

### 方式二：函数调用

```r
library(treesampler)

result <- treesampler(
  data = mtcars,
  nominal_vars = c("cyl", "vs", "am"),
  samples_per_level = c(2, 2, 2),   # 每层每个父节点抽几个
  final_n = 3,                       # 最终叶节点随机抽几行
  seed = 42                          # 随机种子（可复现）
)

head(result)     # 查看子表
nrow(result)    # 子表行数
```

也可以分步调用：

```r
tree <- build_tree(mtcars, c("cyl", "vs"))      # 构建树
sampled <- sample_tree(tree, c(3, 2))            # 分层抽样
subset <- extract_subset(mtcars, sampled, c("cyl", "vs"), final_n = 5)  # 提取子表
```

## 核心函数

| 函数 | 说明 |
|------|------|
| `treesampler()` | 一站式：建树 → 抽样 → 提取子表 |
| `build_tree()` | 从数据和 nominal 变量构建 `data.tree` |
| `sample_tree()` | 在树上执行逐层分层抽样 |
| `extract_subset()` | 根据抽样结果从原数据提取行 |
| `run_treesampler_app()` | 启动 Shiny 交互应用 |

## 算法说明

1. **建树阶段**：按用户选择的 nominal 变量顺序，将数据的每一行映射为树的一条路径（最多 10 层）。若不同列存在同名值，内部节点自动添加 `_colN` 后缀区分。
2. **抽样阶段**：在每个非叶层，对每个父节点随机抽取指定数量的子节点。
3. **提取阶段**：到达最终层后，从每个叶节点对应的数据行中随机抽取 `final_n` 行。

总抽样量 ≈ `samples_per_level[1] * samples_per_level[2] * ... * final_n`（受实际数据量限制）。

## 开发

```bash
git clone https://github.com/your-username/Treesampler.git
cd Treesampler
Rscript run_app.R          # 启动 Shiny 开发模式
devtools::test()           # 运行测试
devtools::document()       # 更新文档
```

## 依赖

- **R >= 3.5.0**
- data.tree, dplyr, shiny, DT, collapsibleTree, readxl, readr

## 许可证

[MIT](LICENSE)

## 作者

wenzhe Huang ([51280155097@stu.ecnu.edu.cn](mailto:51280155097@stu.ecnu.edu.cn))
