#' Initialize the TabPFN runtime (Python env, HF token, local libs)
#'
#' This helper is called automatically on package load, and can also be invoked
#' manually when working in development environments. It attempts to:
#' - prepend a project-local `builds/library` to `.libPaths()` if present;
#' - set `RETICULATE_PYTHON` to a nearby `.venv/bin/python` when one exists
#'   and no Python has been chosen yet;
#' - ensure Hugging Face tokens are surfaced from a `.hf_token` file.
#'
#' @param search_paths Character vector of directories to scan for `.venv` and
#'   `builds/library`. Defaults to the working directory and its parent.
#' @param prefer_venv Logical; if `TRUE`, prefer a `.venv/bin/python` when choosing Python for reticulate.
#' @param force Logical; if `TRUE`, override an existing `RETICULATE_PYTHON` when a matching
#'   `.venv/bin/python` is found.
#' @param quiet Suppress messages when `TRUE`.
#' @return Invisibly returns `TRUE` on completion.
#' @export
tabpfn_init <- function(search_paths = NULL, prefer_venv = TRUE, force = FALSE, quiet = FALSE) {
  search_paths <- search_paths %||% unique(c(getwd(), dirname(getwd())))

  # Add local R library if present
  for (root in search_paths) {
    lib_dir <- file.path(root, "builds", "library")
    if (dir.exists(lib_dir) && !lib_dir %in% .libPaths()) {
      .libPaths(c(lib_dir, .libPaths()))
      if (!quiet) message("Using local R library: ", lib_dir)
      break
    }
  }

  # Prefer project-local Python
  if (prefer_venv) {
    current_py <- Sys.getenv("RETICULATE_PYTHON", "")
    for (root in search_paths) {
      venv_py <- file.path(root, ".venv", "bin", "python")
      if (file.exists(venv_py)) {
        if (force || !nzchar(current_py) || normalizePath(current_py) != normalizePath(venv_py)) {
          if (!quiet) message("Using project Python: ", venv_py)
          Sys.setenv(RETICULATE_PYTHON = venv_py)
          if (requireNamespace("reticulate", quietly = TRUE)) {
            try(reticulate::use_python(venv_py, required = FALSE), silent = TRUE)
          }
        }
        break
      }
    }
  }

  ensure_hf_token()
  invisible(TRUE)
}

.onLoad <- function(...) {
  tabpfn_init(force = TRUE, quiet = TRUE)
}
