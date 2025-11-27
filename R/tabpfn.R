#' Fit a TabPFN classifier via reticulate
#'
#' @importFrom stats fitted nobs predict
#' @param x A data frame or matrix of predictors.
#' @param y A vector or factor of class labels (same length as `nrow(x)`).
#' @param device Device passed to the Python `TabPFNClassifier` (e.g., `"cpu"` or `"cuda"`). Defaults to `"cpu"`.
#' @param n_estimators Number of estimators/ensembles (`TabPFNClassifier$n_estimators`).
#' @param seed Optional seed forwarded as `random_state` to the Python model.
#' @param categorical_features Optional column names or indices identifying categorical features.
#'   Column indices are translated to zero-based indices expected by Python.
#' @param return_fitted If `TRUE`, retains training data and fitted values for helpers such as
#'   `fitted()`, `plot()`, and `summary()`.
#' @param ... Additional arguments reserved for future expansion.
#'
#' @return An object of class `tabpfn_model`.
#' @export
tabpfn <- function(x,
                   y,
                   device = "cpu",
                   n_estimators = 8L,
                   seed = NULL,
                   categorical_features = NULL,
                   return_fitted = TRUE,
                   ...) {
  ensure_hf_token()
  if (missing(x) || missing(y)) {
    stop("Both 'x' and 'y' must be supplied.", call. = FALSE)
  }

  data <- as.data.frame(x)
  if (nrow(data) == 0L) {
    stop("'x' must have at least one row.", call. = FALSE)
  }

  y <- as.factor(y)
  if (nrow(data) != length(y)) {
    stop("'x' and 'y' must have the same number of rows.", call. = FALSE)
  }

  levels_y <- levels(y)
  cat_idx <- resolve_categorical_features(categorical_features, data)

  module <- tabpfn_import()
  classifier <- module$TabPFNClassifier(
    device = device,
    n_estimators = as.integer(n_estimators),
    random_state = seed,
    categorical_features_indices = cat_idx
  )

  data_mat <- as.matrix(data)
  model_py <- classifier$fit(data_mat, as.character(y))

  fitted_class <- normalize_predictions(
    py_to_r_safe(model_py$predict(data_mat)),
    levels_y
  )

  fitted_prob <- NULL
  if (py_has_attr_safe(model_py, "predict_proba")) {
    fitted_prob <- convert_probabilities(
      py_to_r_safe(model_py$predict_proba(data_mat)),
      levels_y
    )
  }

  structure(
    list(
      model = model_py,
      call = match.call(),
      params = list(
        device = device,
        seed = seed,
        n_estimators = as.integer(n_estimators),
        categorical_features = cat_idx
      ),
      training_data = if (return_fitted) data else NULL,
      training_y = if (return_fitted) y else NULL,
      fitted = fitted_class,
      fitted_prob = fitted_prob,
      levels = levels_y,
      n_features = ncol(data)
    ),
    class = "tabpfn_model"
  )
}

#' Check whether TabPFN is available in the active Python environment
#'
#' @return Logical indicating if the Python module `tabpfn` is discoverable.
#' @export
tabpfn_available <- function() {
  py_module_available_safe("tabpfn")
}

#' @param object A fitted `tabpfn_model` object.
#' @param newdata Optional data frame or matrix with the same structure as the training data.
#'   If `NULL`, uses training data.
#' @param type Character; either `"class"` for predicted classes or `"prob"` for predicted probabilities.
#' @export
#' @method predict tabpfn_model
#' @rdname tabpfn
predict.tabpfn_model <- function(object,
                                 newdata = NULL,
                                 type = c("class", "prob"),
                                 ...) {
  type <- match.arg(type)
  data <- prepare_newdata(object, newdata)
  data_mat <- as.matrix(data)

  if (type == "class") {
    preds <- py_to_r_safe(object$model$predict(data_mat))
    return(normalize_predictions(preds, object$levels))
  }

  if (!py_has_attr_safe(object$model, "predict_proba")) {
    stop("The underlying model does not expose predict_proba.", call. = FALSE)
  }

  prob <- convert_probabilities(
    py_to_r_safe(object$model$predict_proba(data_mat)),
    object$levels
  )
  prob
}

#' @export
#' @method fitted tabpfn_model
#' @rdname tabpfn
fitted.tabpfn_model <- function(object, ...) {
  if (!is.null(object$fitted)) {
    return(object$fitted)
  }
  if (is.null(object$training_data)) {
    stop("No training data stored; refit with return_fitted = TRUE.", call. = FALSE)
  }
  predict(object, newdata = object$training_data, type = "class", ...)
}

#' @export
#' @method residuals tabpfn_model
#' @rdname tabpfn
residuals.tabpfn_model <- function(object, ...) {
  if (is.null(object$training_y)) {
    stop("No training data stored; refit with return_fitted = TRUE.", call. = FALSE)
  }
  preds <- fitted(object, ...)
  res <- as.numeric(preds != object$training_y)
  res
}

#' @export
#' @method summary tabpfn_model
#' @rdname tabpfn
summary.tabpfn_model <- function(object, ...) {
  class_counts <- if (!is.null(object$training_y)) table(object$training_y) else NULL
  n_obs <- if (!is.null(object$training_y)) length(object$training_y) else NA_integer_
  preds <- object$fitted
  if (is.null(preds) && !is.null(object$training_data)) {
    preds <- tryCatch(
      predict(object, newdata = object$training_data, type = "class"),
      error = function(e) NULL
    )
  }

  accuracy <- if (!is.null(preds) && !is.null(object$training_y)) {
    mean(preds == object$training_y)
  } else {
    NA_real_
  }

  confusion <- if (!is.null(preds) && !is.null(object$training_y)) {
    table(
      predicted = factor(preds, levels = object$levels),
      observed = factor(object$training_y, levels = object$levels)
    )
  } else {
    NULL
  }

  prob_summary <- NULL
  if (!is.null(object$fitted_prob)) {
    prob_summary <- apply(object$fitted_prob, 2, summary)
    if (is.null(dim(prob_summary))) {
      prob_summary <- matrix(
        prob_summary,
        ncol = 1L,
        dimnames = list(names(prob_summary), colnames(object$fitted_prob))
      )
    }
  }

  out <- list(
    call = object$call,
    params = object$params,
    n_obs = n_obs,
    n_features = object$n_features,
    class_levels = object$levels,
    class_counts = class_counts,
    training_accuracy = accuracy,
    confusion = confusion,
    prob_summary = prob_summary,
    has_probabilities = !is.null(object$fitted_prob)
  )
  class(out) <- "summary.tabpfn_model"
  out
}

#' @export
#' @method print tabpfn_model
#' @rdname tabpfn
print.tabpfn_model <- function(x, ...) {
  cat("TabPFN model\n")
  if (!is.null(x$call)) {
    cat("Call:\n")
    print(x$call)
  }
  obs <- nobs(x)
  if (!is.na(obs)) {
    cat("Observations:", obs, "\n")
  }
  if (!is.null(x$n_features)) {
    cat("Features:", x$n_features, "\n")
  }
  if (!is.null(x$levels)) {
    cat("Classes:", paste(x$levels, collapse = ", "), "\n")
  }
  if (!is.null(x$params$device)) {
    cat("Device:", x$params$device, "\n")
  }
  if (!is.null(x$params$n_estimators)) {
    cat("Estimators:", x$params$n_estimators, "\n")
  }
  cat("Fitted values stored:", if (!is.null(x$fitted)) "yes" else "no", "\n")
  cat("Probabilities stored:", if (!is.null(x$fitted_prob)) "yes" else "no", "\n")
  invisible(x)
}

#' @export
#' @method print summary.tabpfn_model
#' @rdname tabpfn
print.summary.tabpfn_model <- function(x, ...) {
  cat("TabPFN model summary\n")
  if (!is.null(x$call)) {
    cat("Call:\n")
    print(x$call)
  }
  if (!is.na(x$n_obs)) {
    cat("\nObservations:", x$n_obs, "\n")
  }
  if (!is.null(x$n_features)) {
    cat("Features:", x$n_features, "\n")
  }
  if (!is.null(x$class_levels)) {
    cat("Classes:", paste(x$class_levels, collapse = ", "), "\n")
  }
  if (!is.null(x$class_counts)) {
    cat("Class distribution:\n")
    print(x$class_counts)
  }
  if (!is.null(x$training_accuracy) && !is.na(x$training_accuracy)) {
    cat("Training accuracy:", sprintf("%.3f", x$training_accuracy), "\n")
  }
  if (!is.null(x$confusion)) {
    cat("\nConfusion matrix (predicted x observed):\n")
    print(x$confusion)
  }
  if (!is.null(x$prob_summary)) {
    cat("\nProbability summary (per class):\n")
    print(x$prob_summary)
  }
  cat("Probabilities stored:", if (isTRUE(x$has_probabilities)) "yes" else "no", "\n")
  invisible(x)
}

#' @export
#' @method plot tabpfn_model
#' @rdname tabpfn
plot.tabpfn_model <- function(x, ...) {
  if (!is.null(x$fitted_prob)) {
    mean_prob <- colMeans(x$fitted_prob, na.rm = TRUE)
    graphics::barplot(mean_prob, ylab = "Mean predicted probability", main = "TabPFN class probabilities", ...)
    return(invisible(x))
  }

  if (!is.null(x$fitted)) {
    counts <- table(x$fitted)
    graphics::barplot(counts, ylab = "Count", main = "TabPFN predictions", ...)
    return(invisible(x))
  }

  stop("No fitted values stored; refit with return_fitted = TRUE.", call. = FALSE)
}

#' @export
#' @method coef tabpfn_model
#' @rdname tabpfn
coef.tabpfn_model <- function(object, ...) {
  warning("TabPFN does not expose coefficients; returning an empty vector.", call. = FALSE)
  numeric(0)
}

#' @export
#' @method nobs tabpfn_model
#' @rdname tabpfn
nobs.tabpfn_model <- function(object, ...) {
  if (is.null(object$training_y)) {
    return(NA_integer_)
  }
  length(object$training_y)
}

prepare_newdata <- function(object, newdata) {
  if (is.null(newdata)) {
    if (is.null(object$training_data)) {
      stop("newdata is missing and training data was not retained.", call. = FALSE)
    }
    return(object$training_data)
  }

  data <- as.data.frame(newdata)
  if (!is.null(object$n_features) && ncol(data) != object$n_features) {
    stop(
      sprintf(
        "newdata has %s columns but model expects %s.",
        ncol(data), object$n_features
      ),
      call. = FALSE
    )
  }
  data
}

tabpfn_import <- function() {
  importer <- getOption("tabpfn.importer")
  if (is.function(importer)) {
    return(importer())
  }

  ensure_reticulate()

  if (!py_module_available_safe("tabpfn")) {
    stop(
      "Python module 'tabpfn' is not available. Install it with `pip install tabpfn` ",
      "or point reticulate to a Python environment where it is installed.",
      call. = FALSE
    )
  }

  reticulate::import("tabpfn", delay_load = TRUE)
}

ensure_reticulate <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Package 'reticulate' must be installed to use TabPFN.", call. = FALSE)
  }
}

ensure_hf_token <- function() {
  if (nzchar(Sys.getenv("HF_TOKEN")) || nzchar(Sys.getenv("HUGGINGFACEHUB_API_TOKEN"))) {
    return(invisible(NULL))
  }
  candidates <- c(".hf_token", file.path("..", ".hf_token"))
  for (path in candidates) {
    if (file.exists(path)) {
      token <- trimws(readLines(path, warn = FALSE))
      token <- token[nzchar(token)]
      if (length(token)) {
        Sys.setenv(HF_TOKEN = token[1])
        Sys.setenv(HUGGINGFACEHUB_API_TOKEN = token[1])
      }
      break
    }
  }
  invisible(NULL)
}

py_module_available_safe <- function(module) {
  custom <- getOption("tabpfn.py_module_available")
  if (is.function(custom)) {
    return(isTRUE(custom(module)))
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(FALSE)
  }
  reticulate::py_module_available(module)
}

py_to_r_safe <- function(x) {
  converter <- getOption("tabpfn.py_to_r")
  if (is.function(converter)) {
    return(converter(x))
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(x)
  }
  reticulate::py_to_r(x)
}

py_has_attr_safe <- function(x, name) {
  checker <- getOption("tabpfn.py_has_attr")
  if (is.function(checker)) {
    return(isTRUE(checker(x, name)))
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(!is.null(x[[name]]))
  }
  reticulate::py_has_attr(x, name)
}

normalize_predictions <- function(preds, levels) {
  if (is.null(preds)) {
    return(NULL)
  }
  preds <- as.vector(preds)
  factor(preds, levels = levels)
}

convert_probabilities <- function(prob, levels) {
  if (is.null(prob)) {
    return(NULL)
  }
  prob <- as.matrix(prob)
  if (ncol(prob) == length(levels)) {
    colnames(prob) <- levels
  }
  prob
}

resolve_categorical_features <- function(categorical_features, data) {
  if (is.null(categorical_features)) {
    return(NULL)
  }

  if (is.character(categorical_features)) {
    missing_cols <- setdiff(categorical_features, colnames(data))
    if (length(missing_cols)) {
      stop(
        sprintf(
          "categorical_features contains unknown columns: %s",
          paste(missing_cols, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    categorical_features <- match(categorical_features, colnames(data))
  }

  if (!is.numeric(categorical_features)) {
    stop("categorical_features must be indices or column names.", call. = FALSE)
  }

  categorical_features <- unique(as.integer(categorical_features))
  zero_based <- categorical_features - 1L
  if (any(zero_based < 0L)) {
    stop("categorical_features indices must start at 1.", call. = FALSE)
  }
  zero_based
}
