#' Launch the Treesampler Shiny Application
#'
#' Starts the interactive Shiny app for tree-structured sampling. The app
#' provides a four-step workflow:
#' \enumerate{
#'   \item Upload tabular data or use built-in example datasets
#'   \item Select and reorder nominal variables; build and confirm tree structure
#'   \item Configure per-level sample sizes; execute stratified sampling
#'   \item Preview results and download as CSV / RDS / reusable R script
#' }
#'
#' This function automatically detects whether the package is installed or
#' being used in development mode, and launches accordingly.
#'
#' @param ... Additional arguments passed to \code{\link[shiny]{runApp}}.
#'
#' @return Invisibly returns the Shiny app object. Called primarily for its
#'   side effect of launching the app in the browser.
#'
#' @examples
#' \dontrun{
#' # Works in both development mode and after installation
#' run_treesampler_app()
#' run_treesampler_app(launch.browser = TRUE, port = 8080)
#' }
#'
#' @importFrom shiny runApp
#' @export
run_treesampler_app <- function(...) {
  # Try installed package first
  app_dir <- system.file("shiny", package = "treesampler")

  if (app_dir == "" || !dir.exists(app_dir)) {
    # Development mode: search upward for inst/shiny/
    candidate <- normalizePath("inst/shiny", mustWork = FALSE)
    if (!dir.exists(candidate)) {
      # Try walking up from current working directory
      wd <- getwd()
      for (i in 1:5) {
        test_path <- file.path(wd, "inst", "shiny")
        if (dir.exists(test_path)) { candidate <- test_path; break }
        wd <- normalizePath(file.path(wd, ".."), mustWork = FALSE)
      }
    }

    if (!dir.exists(candidate)) {
      stop(
        "Could not find Shiny app directory. ",
        "Make sure you're in the Treesampler project root ",
        "or run: shiny::runApp('inst/shiny')",
        call. = FALSE
      )
    }
    app_dir <- candidate
  }

  message("Launching Treesampler Shiny app from: ", app_dir)
  shiny::runApp(app_dir, ...)
}
