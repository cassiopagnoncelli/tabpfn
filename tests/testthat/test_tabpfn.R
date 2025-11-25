make_stub_module <- function(pred_sequence, prob_mat = NULL) {
  function() {
    list(
      TabPFNClassifier = function(device,
                                  n_estimators,
                                  random_state,
                                  categorical_features_indices) {
        model <- new.env(parent = emptyenv())
        model$device <- device
        model$seed <- random_state
        model$configs <- n_estimators
        model$categorical_features <- categorical_features_indices

        model$fit <- function(x, y) {
          model$x <- x
          model$y <- y
          model
        }

        model$predict <- function(newdata) {
          rep(pred_sequence, length.out = nrow(as.data.frame(newdata)))
        }

        if (!is.null(prob_mat)) {
          model$predict_proba <- function(newdata) {
            prob_mat[seq_len(nrow(as.data.frame(newdata))), , drop = FALSE]
          }
        }

        model
      }
    )
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x

with_stubbed_options <- function(importer, has_attr = NULL, py_to_r = NULL, expr) {
  has_attr <- has_attr %||% function(x, name) !is.null(x[[name]])
  py_to_r <- py_to_r %||% identity

  withr::local_options(
    tabpfn.importer = importer,
    tabpfn.py_has_attr = has_attr,
    tabpfn.py_to_r = py_to_r
  )
  force(expr)
}

test_that("tabpfn fits and predicts with stubbed python", {
  prob_mat <- matrix(
    c(0.7, 0.3,
      0.2, 0.8,
      0.6, 0.4),
    ncol = 2,
    byrow = TRUE
  )
  preds <- c("A", "B", "A")
  importer <- make_stub_module(pred_sequence = preds, prob_mat = prob_mat)

  with_stubbed_options(importer, expr = {
    x <- data.frame(a = 1:3, b = 3:1)
    y <- factor(c("A", "B", "A"))
    colnames(prob_mat) <- levels(y)

    model <- tabpfn(x, y, device = "cpu", seed = 11, n_estimators = 3)
    expect_s3_class(model, "tabpfn_model")
    expect_equal(model$levels, levels(y))
    expect_equal(model$params$seed, 11)
    expect_equal(fitted(model), factor(preds, levels = levels(y)))
    expect_equal(predict(model, x, type = "class"), factor(preds, levels = levels(y)))
    expect_identical(residuals(model), c(0, 0, 0))

    prob <- predict(model, x, type = "prob")
    expect_equal(prob, prob_mat)
    expect_equal(colnames(prob), levels(y))
  })
})

test_that("summary, plot, and coef behave", {
  importer <- make_stub_module(pred_sequence = "X")

  with_stubbed_options(importer, expr = {
    x <- data.frame(a = 1:2, b = 1:2)
    y <- factor(c("X", "X"))

    model <- tabpfn(x, y, return_fitted = TRUE)
    s <- summary(model)
    expect_s3_class(s, "summary.tabpfn_model")
    expect_equal(s$n_obs, 2)
    expect_false(isTRUE(s$has_probabilities))
    expect_output(print(s), "TabPFN model summary")

    tmp <- tempfile(fileext = ".pdf")
    grDevices::pdf(tmp)
    expect_invisible(plot(model))
    grDevices::dev.off()
    unlink(tmp)

    expect_warning(coef_val <- coef(model), "does not expose")
    expect_identical(coef_val, numeric(0))
  })
})

test_that("categorical features are normalized to zero-based indices", {
  captured <- list()
  importer <- function() {
    list(
      TabPFNClassifier = function(device,
                                  n_estimators,
                                  random_state,
                                  categorical_features_indices) {
        captured <<- append(captured, list(categorical_features_indices))
        model <- new.env(parent = emptyenv())
        model$fit <- function(x, y) model
        model$predict <- function(newdata) rep("a", nrow(as.data.frame(newdata)))
        model
      }
    )
  }

  with_stubbed_options(importer, has_attr = function(x, name) FALSE, expr = {
    x <- data.frame(cat = c("x", "y"), num = 1:2)
    y <- factor(c("c1", "c2"))

    tabpfn(x, y, categorical_features = "cat")
    tabpfn(x, y, categorical_features = 2)
    expect_equal(captured[[1]], 0L)
    expect_equal(captured[[2]], 1L)
    expect_error(tabpfn(x, y, categorical_features = "missing"), "unknown columns")
  })
})

test_that("tabpfn_available uses module availability hook", {
  withr::local_options(tabpfn.py_module_available = function(module) FALSE)
  expect_false(tabpfn_available())

  withr::local_options(tabpfn.py_module_available = function(module) TRUE)
  expect_true(tabpfn_available())
})
