if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

if (dir.exists("builds/library")) {
  .libPaths(c(normalizePath("builds/library"), .libPaths()))
}

# Prefer project-local Python if available
if (dir.exists(".venv") && nzchar(Sys.getenv("RETICULATE_PYTHON", unset = "")) == FALSE) {
  Sys.setenv(RETICULATE_PYTHON = normalizePath(".venv/bin/python"))
}

# Note: Connection pool cleanup is handled automatically by the pool package's
# internal finalizers. Explicit cleanup in .Last can interfere with proper
# connection lifecycle management.
