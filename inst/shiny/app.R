## Treesampler Shiny Application
# Full workflow: Upload -> Variable Select & Reorder -> Tree Build -> Sampling -> Download

# Source core package functions (needed when running standalone via shiny::runApp)
# Try to locate the package root relative to this file
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE)),
  error = function(e) NULL
)
if (is.null(script_dir) || !nzchar(script_dir)) {
  script_dir <- normalizePath("inst/shiny", mustWork = FALSE)
}
pkg_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = FALSE)
r_dir <- file.path(pkg_root, "R")
if (!dir.exists(r_dir)) pkg_root <- getwd()
invisible(lapply(
  list.files(file.path(pkg_root, "R"), pattern = "\\.R$", full.names = TRUE),
  source
))

library(shiny)
library(DT)
library(collapsibleTree)
library(data.tree)
library(readr)

# ──────────────────────────────────────────────────────
# UI
# ──────────────────────────────────────────────────────

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .sidebar-section { margin-bottom: 20px; }
      .sampling-input { margin-top: 8px; }
      .well { background-color: #f8f9fa; }
      .level-badge {
        display: inline-block;
        min-width: 28px;
        padding: 2px 6px;
        margin-right: 4px;
        border-radius: 10px;
        background: #3498db;
        color: white;
        font-size: 11px;
        font-weight: bold;
        text-align: center;
      }
      .sortable-list {
        min-height: 40px;
        padding: 8px;
        border-radius: 6px;
        background: #f9f9f9;
        border: 1px dashed #bdc3c7;
      }
      .sortable-list .list-group-item {
        cursor: grab;
        font-size: 13px;
        padding: 8px 12px;
        margin-bottom: 4px;
        border-radius: 4px;
        background: #fff;
        border: 1px solid #ddd;
      }
      .sortable-list .list-group-item:hover { background: #ecf0f1; }
      .sortable-list .list-group-item.ui-sortable-helper {
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        transform: rotate(1deg);
      }
      .suffix-note {
        font-size: 11px;
        color: #7f8c8d;
        font-style: italic;
        margin-top: 4px;
      }
    "))
  ),
  tags$script(HTML("
    Shiny.addCustomMessageHandler('copy_to_clipboard', function(msg) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(msg.text).catch(function(err) {
          fallbackCopy(msg.text);
        });
      } else {
        fallbackCopy(msg.text);
      }
      function fallbackCopy(text) {
        var ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
      }
    });
  ")),

  titlePanel(
    div("Treesampler: \u6811\u72b6\u5206\u5c42\u62bd\u6837\u5de5\u5177",
        style = "font-weight: 300; color: #2c3e50;")
  ),
  hr(),

  sidebarLayout(
    sidebarPanel(width = 4,

      # ── Step 1: Data upload ──
      div(class = "sidebar-section",
        h4("1. \u4e0a\u4f20\u6570\u636e"),
        radioButtons("data_source", NULL,
          choices = c("\u4e0a\u4f20\u6587\u4ef6" = "file",
                      "\u793a\u4f8b\u6570\u636e (mtcars)" = "example"),
          selected = "example"
        ),
        conditionalPanel(
          condition = "input.data_source == 'file'",
          fileInput("file", "\u4e0a\u4f20\u6587\u4ef6\uff08\u6700\u592750MB\uff09",
            accept = c(".csv",".tsv",".xlsx",".xls",".rds",".rda"),
            placeholder = "CSV / TSV / Excel / RDS / RDA"
          )
        )
      ),

      hr(),

      # ── Step 2: Variable selection & drag-to-reorder ──
      div(class = "sidebar-section",
        h4("2. \u9009\u62e6 & \u62d6\u52a8\u6392\u5e8f"),
        uiOutput("var_select_ui"),

        conditionalPanel(condition = "input.nominal_vars_raw && input.nominal_vars_raw.length > 0",
          br(),
          p(strong("\u5c42\u7ea7\u987a\u5e8f\uff08\u62d6\u52a8\u8c03\u6574\uff09"), style="margin-bottom:6px;"),

          # Sortable rank list for drag-and-drop reordering
          uiOutput("var_order_ui"),

          helpText("\u62d6\u52a8\u9879\u76ee\u6539\u53d8\u5c42\u7ea7\u987a\u5e8f\u3002\u9876\u90e8 = \u6811\u7684\u7b2c1\u5c42\u3002",
                   class = "suffix-note")
        ),

        actionButton("build_tree", "\u6784\u5efa\u6811\u7ed3\u6784",
          icon = icon("sitemap"), class = "btn-primary btn-block", width = "100%"
        )
      ),

      # ── Step 3: Sampling config ──
      conditionalPanel(condition = "output.tree_built == '1'",
        hr(),
        div(class = "sidebar-section",
          h4("3. \u914d\u7f6e\u62bd\u6837\u53c2\u6570"),
          radioButtons("sample_method", "\u62bd\u6837\u7b56\u7565",
            choices = c(
              "\u6bcf\u7236\u8282\u70b9\u62bd N \u4e2a\u5b50\u8282\u70b9" = "per-parent",
              "\u6574\u5c42\u5747\u5300\u62bd N \u4e2a\u8282\u70b9" = "level-wise"
            ), selected = "per-parent"
          ),
          br(), uiOutput("sample_size_ui"),
          br(), numericInput("seed", "\u968f\u673a\u79cd\u5b50 (seed, \u7559\u7a7a\u4e3a\u968f\u673a)", value = NULL,
                             min = 0, step = 1),
          br(),
          actionButton("run_sampling", "\u6267\u884c\u62bd\u6837",
            icon = icon("play"), class = "btn-success btn-block", width = "100%"
          )
        )
      ),

      # ── Step 4: Download ──
      conditionalPanel(condition = "output.sampling_done == '1'",
        hr(),
        div(class = "sidebar-section",
          h4("4. \u4e0b\u8f7d\u7ed3\u679c"), br(),
          downloadButton("download_csv", "\u4e0b\u8f7d CSV",
            class = "btn-info btn-block", style = "width:100%"),
          br(), br(),
          downloadButton("download_rds", "\u4e0b\u8f7d RDS",
            class = "btn-info btn-block", style = "width:100%"),
          br(), br(),
          uiOutput("code_download_ui")
        )
      )
    ),

    # ── Main panel ──
    mainPanel(width = 8,
      tabsetPanel(id = "main_tabs", type = "tabs",

        tabPanel("\u6570\u636e\u9884\u89c8", icon = icon("table"),
          br(), verbatimTextOutput("data_info"),
          br(), DTOutput("data_preview")),

        tabPanel("\u6811\u7ed3\u6784", icon = icon("tree"),
          br(),
          conditionalPanel(condition = "output.tree_built == '1'",
            # Suffix info banner
            uiOutput("suffix_info_banner"),
            collapsibleTreeOutput("tree_plot", height = "500px"),
            br(),
            div(style = "text-align:center;",
              actionButton("confirm_tree", "\u786e\u8ba4\u6811\u7ed3\u6784",
                icon = icon("check"), class = "btn-success")
            )
          ),
          conditionalPanel(condition = "output.tree_built != '1'",
            div(style = "text-align:center; padding:60px; color:#95a5a6;",
              icon("sitemap", "fa-4x"), br(), br(),
              p("\u8bf7\u5728\u5de6\u4fa7\u9009\u62e9\u53d8\u91cf\u540e\u70b9\u51fb\u201c\u6784\u5efa\u6811\u7ed3\u6784\u201d"))
          )
        ),

        tabPanel("\u62bd\u6837\u7ed3\u679c", icon = icon("clipboard-list"),
          br(),
          conditionalPanel(condition = "output.sampling_done == '1'",
            wellPanel(uiOutput("summary_info"), uiOutput("sampling_warnings")),
            br(), DTOutput("subset_preview")),
          conditionalPanel(condition = "output.sampling_done != '1'",
            div(style = "text-align:center; padding:60px; color:#95a5a6;",
              icon("play-circle", "fa-4x"), br(), br(),
              p("\u8bf7\u5728\u5de6\u4fa7\u914d\u7f6e\u62bd\u6837\u53c2\u6570\u540e\u70b9\u51fb\u201c\u6267\u884c\u62fd\u6837\u201d"))
          )
        )
      )
    )
  ),

  hr(),
  div(style = "text-align:center; color:#95a5a6; font-size:12px;",
      "Treesampler v0.1.0 | \u7528\u4e8e\u6570\u636e\u5206\u6790\u4e2d\u7684\u5feb\u901f\u539f\u578b\u6d4b\u8bd5")
)

# ──────────────────────────────────────────────────────
# Server
# ──────────────────────────────────────────────────────

server <- function(input, output, session) {
  options(shiny.maxRequestSize = 50 * 1024^2)

  values <- reactiveValues(
    tree = NULL, sampled_tree = NULL, subset = NULL,
    sampling_done = FALSE, tree_built = FALSE, warnings = NULL,
    ordered_vars = character(0)
  )

  output$tree_built <- reactive({ if (values$tree_built) "1" else "0" })
  outputOptions(output, "tree_built", suspendWhenHidden = FALSE)

  output$sampling_done <- reactive({ if (values$sampling_done) "1" else "0" })
  outputOptions(output, "sampling_done", suspendWhenHidden = FALSE)

  # ── Read data ──
  user_data <- reactive({
    if (input$data_source == "example") return(mtcars)

    req(input$file)
    ext <- tools::file_ext(input$file$name)

    dat <- switch(ext,
      csv  = read.csv(input$file$datapath, stringsAsFactors = FALSE),
      tsv  = read.delim(input$file$datapath, stringsAsFactors = FALSE),
      xlsx = readxl::read_excel(input$file$datapath),
      xls  = readxl::read_excel(input$file$datapath),
      rds  = readRDS(input$file$datapath),
      rda  = { env <- new.env(); load(input$file$datapath, envir=env); env[[ls(env)[1]]] },
      stop("\u4e0d\u652f\u6301\u7684\u6587\u4ef6\u683c\u5f0f: ", ext, call. = FALSE)
    )
    as.data.frame(dat)
  })

  # ── Data info ──
  output$data_info <- renderPrint({
    dat <- user_data()
    cat("\u884c\u6570:", nrow(dat), "\n")
    cat("\u5217\u6570:", ncol(dat), "\n")
    cat("\u5217\u540d:", paste(names(dat), collapse = ", "), "\n")
    if (nrow(dat) == 0) cat("\n[!] \u6570\u636e\u4e3a\u7a7a\n")
  })

  # ── Variable selection checkbox group ──
  output$var_select_ui <- renderUI({
    dat <- user_data()
    is_nominal <- sapply(dat, function(col) {
      is.character(col) || is.factor(col) || (is.numeric(col) && length(unique(col)) <= 12)
    })
    nominal_cols <- names(dat)[is_nominal]

    if (length(nominal_cols) == 0) {
      return(helpText("\u672a\u68c0\u6d4b\u5230 nominal \u53d8\u91cf\u3002",
               style = "color: #e74c3c;"))
    }

    # Show up to 50 nominal variables, warn if more
    n_show <- min(length(nominal_cols), 50)
    choices <- nominal_cols[seq_len(n_show)]
    if (length(nominal_cols) > 50) {
      choices <- c(choices, paste0("... (\u8fd8\u6709 ", length(nominal_cols) - 50, " \u4e2a)"))
    }

    tagList(
      checkboxGroupInput("nominal_vars_raw",
        "\u52fe\u9009\u53d8\u91cf (\u6700\u591a\u900910\u4e2a)",
        choices = choices,
        selected = character(0),
        choiceNames = NULL,
        choiceValues = NULL
      ),
      tags$script(HTML("
        // Enforce max 10 selections on nominal_vars_raw
        $(document).on('shiny:inputchanged', function(e) {
          if (e.name === 'nominal_vars_raw' && e.value !== undefined && e.value.length > 10) {
            e.preventDefault();
            var prev = $('#nominal_vars_raw input:checked');
            var current = $.makeArray(prev.map(function(){return this.value;}));
            // Keep only first 10 that were already checked
            Shiny.setInputValue('nominal_vars_raw', current.slice(0, 10), {priority: 'event'});
          }
        });
      "))
    )
  })

  # ── Drag-and-drop reorder UI (pure HTML5, no extra package) ──
  output$var_order_ui <- renderUI({
    vars <- values$ordered_vars
    if (length(vars) == 0) return(NULL)

    # Build draggable items with level badges
    items <- lapply(seq_along(vars), function(i) {
      tags$li(
        class = "list-group-item",
        id = paste0("var_item_", i),
        draggable = "true",
        tags$span(class = "level-badge", paste0("L", i)),
        vars[i],
        style = "display:flex; align-items:center;"
      )
    })

    tagList(
      # Native HTML5 drag-and-drop handler script (idempotent — guarded by data attribute)
      tags$script(HTML('
        (function() {
          var list = document.getElementById("var_rank_list");
          if (!list || list.getAttribute("data-dnd-bound") === "true") return;
          list.setAttribute("data-dnd-bound", "true");

          var draggingItem = null;
          var placeholder = null;

          function createPlaceholder(item) {
            var ph = document.createElement("li");
            ph.className = "list-group-item";
            ph.style.opacity = "0.3";
            ph.style.border = "2px dashed #3498db";
            ph.style.height = item.offsetHeight + "px";
            return ph;
          }

          function _onDragStart(e) {
            if (!e.target.classList.contains("list-group-item")) return;
            draggingItem = e.target;
            placeholder = createPlaceholder(draggingItem);
            e.dataTransfer.effectAllowed = "move";
            setTimeout(function() { draggingItem.style.display = "none"; }, 0);
          }

          function _onDragOver(e) {
            e.preventDefault();
            e.dataTransfer.dropEffect = "move";
            var target = e.target.closest ? e.target.closest(".list-group-item") : null;
            if (!target || target === placeholder || target === draggingItem) return;
            var rect = target.getBoundingClientRect();
            var midY = rect.top + rect.height / 2;
            if (e.clientY < midY) {
              list.insertBefore(placeholder, target);
            } else {
              list.insertBefore(placeholder, target.nextSibling);
            }
          }

          function _onDrop(e) {
            e.preventDefault();
            if (!draggingItem) return;
            list.insertBefore(draggingItem, placeholder);
            if (placeholder.parentNode) list.removeChild(placeholder);
            draggingItem.style.display = "";
            var order = [];
            var children = list.querySelectorAll(".list-group-item");
            for (var i = 0; i < children.length; i++) {
              order.push(children[i].textContent.trim());
            }
            Shiny.setInputValue("var_rank_list", order, {priority: "event"});
            draggingItem = null;
            placeholder = null;
          }

          function _onDragEnd(e) {
            if (placeholder && placeholder.parentNode) list.removeChild(placeholder);
            if (draggingItem) { draggingItem.style.display = ""; draggingItem = null; }
            placeholder = null;
          }

          list.addEventListener("dragstart", _onDragStart);
          list.addEventListener("dragover", _onDragOver);
          list.addEventListener("drop", _onDrop);
          list.addEventListener("dragend", _onDragEnd);
        })();
      ')),
      tags$ul(id = "var_rank_list", class = "sortable-list list-group",
              items, style = "padding-left:0;")
    )
  })

  # Sync ordered_vars when raw selection changes or on init
  observeEvent(input$nominal_vars_raw, {
    req(input$nominal_vars_raw)
    values$ordered_vars <- input$nominal_vars_raw
  }, priority = 1)

  # Listen to sortablejs reordering events
  observeEvent(input$var_rank_list, {
    new_order <- input$var_rank_list
    if (!is.null(new_order) && length(new_order) > 0) {
      # Strip the "L1 ", "L2 "... prefix to get clean variable names
      clean_names <- gsub("^L\\d+\\s+", "", new_order)
      values$ordered_vars <- clean_names
    }
  }, ignoreNULL = TRUE, ignoreInit = TRUE)

  # ── Data preview ──
  output$data_preview <- renderDT({
    dat <- user_data()
    if (nrow(dat) == 0) return(datatable(data.frame()))
    datatable(dat, options = list(pageLength = 10, scrollX = TRUE,
                                  searching = FALSE,
                                  lengthMenu = c(5,10,25,50)),
              rownames = FALSE)
  })

  # ── Build tree ──
  observeEvent(input$build_tree, {
    vars <- values$ordered_vars
    if (length(vars) == 0) {
      showNotification("\u8bf7\u81f3\u5c11\u9009\u62e9\u4e00\u4e2a\u53d8\u91cf", type = "error"); return()
    }
    dat <- user_data()
    if (nrow(dat) == 0) {
      showNotification("\u6570\u636e\u4e3a\u7a7a\uff0c\u65e0\u6cd5\u6784\u5efa\u6811", type = "error"); return()
    }

    tryCatch({
      values$tree <- build_tree(dat, vars)
      values$tree_built <- TRUE
      values$sampling_done <- FALSE
      values$subset <- NULL
      updateTabsetPanel(session, "main_tabs", selected = "\u6811\u7ed3\u6784")

      showNotification(
        sprintf("\u6811\u7ed3\u6784\u5df2\u6784\u5efa: %d \u4e2a\u8282\u70b9, %d \u5c42",
                values$tree$totalCount, length(vars)),
        type = "message", duration = 5)
    }, error = function(e) {
      showNotification(paste("\u6784\u5efa\u5931\u8d25:", e$message), type = "error", duration = 10)
    })
  })

  # ── Suffix info banner (shown above tree plot) ──
  output$suffix_info_banner <- renderUI({
    vars <- values$ordered_vars
    n_vars <- length(vars)

    if (n_vars >= 1) {
      # Show column names with _colN suffix
      suffixed_names <- paste0(vars, "_col", seq_along(vars), collapse = " > ")

      div(class = "alert alert-info", style = "font-size:12px; padding:8px;",
          icon("info-circle"),
          HTML(paste0(
            "<b>\u540e\u7f00\u8bf4\u660e:</b> \u67d0\u4e9b\u5217\u540d\u53ef\u80fd\u5b58\u5728\u76f8\u540c\u7684\u540d\u5b57\uff0c",
            "\u5217\u540d\u81ea\u52a8\u6dfb\u52a0 <code>_colN</code> \u540e\u7f00\u4ee5\u533a\u5206\u3002",
            "<br><b>\u5e26\u540e\u7f00\u5217\u540d:</b> <code>", suffixed_names, "</code>"
          ))
        )
    } else {
      NULL
    }
  })

  # ── Tree plot (always strips _colN for display) ──
  output$tree_plot <- renderCollapsibleTree({
    req(values$tree)
    tree <- values$tree
    vars <- values$ordered_vars

    # Guard: refuse to render trees that are too large for the browser
    if (tree$totalCount > 50000) {
      showNotification(
        sprintf("\u6811\u8282\u70b9\u6570 (%d) \u8fc7\u591a\uff0c\u53ef\u80fd\u5bfc\u81f6\u6d4f\u89c8\u5668\u5361\u987f\u3002\u8bf7\u51cf\u5c11\u5206\u7c7b\u53d8\u91cf\u6570\u3002",
                tree$totalCount),
        type = "warning", duration = 10)
      return(NULL)
    }

    leaf_nodes <- data.tree::Traverse(tree, filterFun = function(n) n$isLeaf)
    if (length(leaf_nodes) == 0) return(NULL)

    rows <- lapply(leaf_nodes, function(leaf) {
      path_vals <- leaf$path[-1]  # remove Root
      # Always strip _colN suffixes for user-facing display
      display_vals <- gsub("_col[0-9]+$", "", path_vals)
      row_vals <- character(length(vars))
      for (i in seq_along(vars)) {
        row_vals[i] <- if (i <= length(display_vals)) display_vals[i] else ""
      }
      c(row_vals, "\u968f\u673a\u62bd\u6837", n_rows = leaf$n_rows)
    })

    plot_df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
    names(plot_df) <- c(vars, "\u4e0d\u5206\u5c42", "n_rows")
    plot_df$n_rows <- as.numeric(plot_df$n_rows)

    hierarchy_cols <- c(vars, "\u4e0d\u5206\u5c42")

    collapsibleTree(plot_df, hierarchy = hierarchy_cols,
                    width = 800, zoomable = TRUE,
                    collapsed = FALSE,
                    tooltipHtml = function(node) {
                      paste0("<b>", node$name, "</b><br>n = ",
                             if (is.null(node$n_rows)) "?" else node$n_rows)
                    }, fill = "#1abc9c", fontSize = 11, nodeSize = "n_rows")
  })

  # ── Tree confirmation ──
  observeEvent(input$confirm_tree, {
    showNotification("\u6811\u7ed3\u6784\u5df2\u786e\u8ba4\uff0c\u8bf7\u914d\u7f6e\u62bd\u6837\u53c2\u6570",
                     type = "message", duration = 5)
  })

  # ── Dynamic sample size inputs per level ──
  output$sample_size_ui <- renderUI({
    req(values$tree_built); req(values$ordered_vars)

    vars <- values$ordered_vars
    dat <- user_data()

    inputs <- lapply(seq_along(vars), function(i) {
      var_name <- vars[i]
      n_unique <- length(unique(dat[[var_name]]))
      n_selected <- min(3, n_unique)

      div(class = "sampling-input",
        numericInput(paste0("n_level_", i),
          label = sprintf("L%d: %s (\u5171 %d \u79cd)", i, var_name, n_unique),
          value = n_selected, min = 1, max = n_unique, step = 1, width = "100%"
        )
      )
    })

    # Add final "不区分层" (non-stratified random sampling per leaf)
    final_input <- div(class = "sampling-input",
      numericInput("n_final",
        label = paste0("L", length(vars)+1, ": \u4e0d\u5206\u5c42 (\u6bcf\u53f6\u8282\u70b9\u968f\u673a\u62bd N \u884c)"),
        value = 3, min = 1, step = 1, width = "100%"
      ),
      helpText("\u6b64\u5c42\u5728\u6811\u7ed3\u6784\u672b\u7aef\uff0c\u5bf9\u6bcf\u4e2a\u53f6\u8282\u70b9\u5185\u7684\u884c\u8fdb\u884c\u968f\u673a\u62bd\u6837\u3002",
               style = "font-size:11px; color:#7f8c8d;")
    )

    do.call(tagList, c(inputs, list(final_input)))
  })

  # ── Run sampling ──
  observeEvent(input$run_sampling, {
    req(values$tree); req(values$ordered_vars)

    vars <- values$ordered_vars
    samples_per_level <- integer(0)
    for (i in seq_along(vars)) {
      n <- input[[paste0("n_level_", i)]]
      if (is.null(n) || is.na(n)) n <- length(unique(user_data()[[vars[i]]]))
      samples_per_level <- c(samples_per_level, n)
    }

    # Final non-stratified layer: random sample N rows per leaf
    n_final <- input$n_final
    if (is.null(n_final) || is.na(n_final)) n_final <- 3

    seed_val <- if (is.null(input$seed) || is.na(input$seed)) NULL else input$seed

    tryCatch({
      values$sampled_tree <- sample_tree(values$tree, samples_per_level,
                                          method = input$sample_method, seed = seed_val)
      values$subset <- extract_subset(user_data(), values$sampled_tree, vars,
                                       final_n = n_final, seed = seed_val)
      values$sampling_done <- TRUE
      values$warnings <- NULL

      updateTabsetPanel(session, "main_tabs", selected = "\u62bd\u6837\u7ed3\u679c")

      showNotification(
        sprintf("\u62bd\u6837\u5b8c\u6210! \u5b50\u8868 %d \u884c (%.1f%%)",
                nrow(values$subset),
                nrow(values$subset)/nrow(user_data())*100),
        type = "message", duration = 8)
    }, error = function(e) {
      values$warnings <- paste("\u9519\u8bef:", e$message)
      showNotification(paste("\u62bd\u6837\u5931\u8d25:", e$message),
                       type = "error", duration = 10)
    })
  })

  # ── Summary info (shows clean names only) ──
  output$summary_info <- renderUI({
    req(values$sampling_done); req(values$subset)
    orig <- nrow(user_data()); sub <- nrow(values$subset)
    pct <- round(sub / orig * 100, 1)

    vars <- values$ordered_vars
    level_labels <- paste0("L", seq_along(vars), ":", vars, collapse = " > ")
    final_n <- input$n_final
    if (is.null(final_n) || is.na(final_n)) final_n <- 3

    HTML(sprintf(
      "<b>\u62bd\u6837\u7ed3\u679c</b><br>
       \u539f\u59cb: <b>%d</b> \u884c | \u5b50\u96c6: <b>%d</b> \u884c (<b>%.1f%%</b>)<br>
       \u7b56\u7565: <b>%s</b><br>
       \u5206\u5c42: %s > L%d:\u4e0d\u5206\u5c42(%d)<br>
       seed: %s",
      orig, sub, pct,
      input$sample_method,
      level_labels, length(vars)+1, final_n,
      if (is.null(input$seed)||is.na(input$seed)) "\u968f\u673a" else as.character(input$seed)
    ))
  })

  output$sampling_warnings <- renderUI({
    if (!is.null(values$warnings)) div(class = "alert alert-warning", values$warnings)
  })

  # ── Subset preview (clean column values, no suffixes) ──
  output$subset_preview <- renderDT({
    req(values$subset)
    datatable(values$subset,
      options = list(pageLength=10, scrollX=TRUE, searching=FALSE, lengthMenu=c(5,10,25,50)),
      rownames = FALSE)
  })

  # ── Downloads ──
  output$download_csv <- downloadHandler(
    filename = function() paste0("treesampler_subset_", format(Sys.time(), "%y_%m_%d_%H_%M"), ".csv"),
    content = function(file) readr::write_csv(values$subset, file)
  )

  output$download_rds <- downloadHandler(
    filename = function() paste0("treesampler_subset_", format(Sys.time(), "%y_%m_%d_%H_%M"), ".rds"),
    content = function(file) saveRDS(values$subset, file)
  )

  output$code_download_ui <- renderUI({
    req(values$sampling_done)
    actionButton("copy_code", "\u590d\u5236 R \u4ee3\u7801",
      class = "btn-warning btn-block", style = "width:100%",
      icon = icon("clipboard"))
  })

  # Generate R code string (shared by copy + display)
  code_str <- reactive({
    req(values$sampling_done)
    vars <- values$ordered_vars
    samples_per_level <- sapply(seq_along(vars), function(i) {
      input[[paste0("n_level_", i)]]
    })
    final_n <- if (is.null(input$n_final) || is.na(input$n_final)) 3 else input$n_final
    seed_txt <- if (is.null(input$seed)||is.na(input$seed)) "NULL" else as.character(input$seed)

    sprintf(
      "# Treesampler: reproducible sampling code\n# Generated: %s\n\nlibrary(treesampler)\n\n# Read your data (uncomment and modify as needed)\n# data <- read.csv('your_file.csv')\nyour_data <- mtcars  # <-- Replace this with your actual data\n\nresult <- treesampler(\n  data = your_data,   # <-- Replace with your data frame\n  nominal_vars = c(%s),\n  samples_per_level = c(%s),\n  method = \"%s\",\n  final_n = %d,\n  seed = %s\n)\n\nprint(result)\nhead(result)\n",
      format(Sys.time(), "%y_%m_%d_%H_%M"),
      paste(shQuote(vars), collapse = ", "),
      paste(samples_per_level, collapse = ", "),
      input$sample_method,
      final_n, seed_txt
    )
  })

  observeEvent(input$copy_code, {
    session$sendCustomMessage(type = "copy_to_clipboard", message = list(text = code_str()))
    showNotification("\u4ee3\u7801\u5df2\u590d\u5236\u5230\u526a\u8d34\u677f\uff01", type = "message", duration = 3)
  })

  # ── Reset on data change ──
  observeEvent(c(input$data_source, input$file), {
    values$tree <- NULL; values$sampled_tree <- NULL
    values$subset <- NULL; values$sampling_done <- FALSE
    values$tree_built <- FALSE; values$warnings <- NULL
    values$ordered_vars <- character(0)
  })
}

# ── Helper: Check if any value strings overlap across variables ──
# Returns TRUE if different columns share identical value strings.
# Used to decide whether to show the suffix info banner.
check_value_overlap <- function(data, var_cols) {
  if (length(var_cols) <= 1) return(FALSE)

  val_sets <- lapply(var_cols, function(v) unique(as.character(data[[v]])))
  all_vals <- unlist(val_sets)
  length(all_vals) != length(unique(all_vals))
}

# ── Launch ──
shinyApp(ui = ui, server = server)
