# Repository Guidelines

## Project Structure & Module Organization
- `R/` holds exported feature pipelines and helpers; `fe.R` orchestrates modules such as `macro.R`, `transformations.R`, `dates.R`, `decompose.R`, `configs.R`, and `utils.R`.
- `tests/testthat/` stores unit tests (`test_*.R`) driven by `tests/testthat.R`.
- `man/` contains roxygen2-generated Rd files; `DESCRIPTION` and `NAMESPACE` define package metadata; `builds/` captures built tarballs and local library installs; `dev/` includes maintenance scripts (e.g., dependency refresh); `renv/` and `renv.lock` pin the environment; `rd/` carries ancillary R resources; `README.md` summarizes available features.

## Environment & Dependencies
- Requires R >= 4.4.0. Run `renv::restore()` to sync dependencies from `renv.lock`; keep `renv/` under version control.
- Core runtime packages include `data.table`, `RcppRoll`, `DBI`, `TTR`, `ggplot2`, `lubridate`, `dplyr`, and `stringr`. Install missing CRAN deps with `install.packages()`; update bundled qetl tarballs with `Rscript dev/update_deps.R` when needed.

## Build, Test, and Development Commands
- `make docs` regenerates `man/` and `NAMESPACE` via `devtools::document()`.
- `make build` cleans then builds a package tarball into `builds/`; `make install` installs the latest tarball into `builds/library` (prints `.libPaths()`).
- `make check` runs `R CMD check` and should be clean before publishing.
- `make test` (alias `make tests`) runs `devtools::test()`; `make lint` runs `lintr::lint_dir('.')`; `make style` formats with `styler::style_dir('.')`; `make clean` removes build artifacts; `make stats` reports current LOC.

## Coding Style & Naming Conventions
- Follow tidyverse/data.table style: snake_case for objects and functions, 2-space indents, no tabs. Favor explicit `:=` assignments with `by =` where grouping is required.
- Keep functions pure and parameterized; validate inputs early with clear `stop()` messages; return modified data.tables invisibly when mutating in place.
- Document exported functions with roxygen blocks; keep examples minimal, runnable, and aligned with current arguments.

## Testing Guidelines
- Use `testthat` (edition 3). Add suites under `tests/testthat/` as `test_<topic>.R` with descriptive `test_that()` blocks.
- Cover edge cases: missing required columns, NA handling, multi-symbol grouping, parameter validation, and cleanup of temporary columns.
- Run `make test` for quick checks; prefer `make check` before releases to surface R CMD warnings/notes.

## Commit & Pull Request Guidelines
- Commit messages: concise, imperative summaries (e.g., “Add wavelet smoothing guard”); avoid long bodies unless necessary for context.
- PRs should explain intent, list commands executed (tests/check/lint/style), link related issues, and call out API or data-shape changes.
- Include screenshots only when visual outputs change; otherwise attach reproducible commands and small input/output samples where helpful.
