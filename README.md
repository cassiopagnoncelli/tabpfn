# TabPFN for R <img src="https://img.shields.io/badge/R-%E2%89%A5%204.4.0-blue" alt="R Version"/> <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>

> **Transformer-based probabilistic classification for tabular data in R**

An R interface to [TabPFN](https://github.com/PriorLabs/TabPFN), a powerful transformer-based classifier that leverages prior-data fitted networks for efficient and accurate tabular data classification. TabPFN delivers competitive performance without hyperparameter tuning, making it ideal for rapid prototyping and small-to-medium sized datasets.

---

## ✨ Features

- **Zero Hyperparameter Tuning** — Competitive performance out-of-the-box
- **Fast Training** — Efficient fitting even on CPU
- **Probabilistic Predictions** — Get class probabilities alongside predictions
- **Standard R Interface** — Familiar methods: `predict()`, `summary()`, `plot()`, `fitted()`
- **Categorical Features** — Native support for categorical variables
- **Ensemble Support** — Configure multiple estimators for improved accuracy

---

## 📦 Installation

### Prerequisites

1. **R** >= 4.4.0
2. **Python** environment with `tabpfn` package
3. **reticulate** R package

### Install from Source

```r
# Install reticulate if not already installed
install.packages("reticulate")

# Install TabPFN Python package
reticulate::py_install("tabpfn")

# Install this package (adjust path as needed)
install.packages("path/to/tabpfn_1.2.1.tar.gz", repos = NULL, type = "source")
```

### Quick Setup Check

```r
library(tabpfn)

# Verify TabPFN is available
tabpfn_available()
#> [1] TRUE
```

---

## 🚀 Quick Start

### Basic Classification

```r
library(tabpfn)

# Prepare data
data(iris)
train_idx <- 1:100
X_train <- iris[train_idx, 1:4]
y_train <- iris[train_idx, 5]
X_test <- iris[-train_idx, 1:4]
y_test <- iris[-train_idx, 5]

# Fit model
model <- tabpfn(
  x = X_train,
  y = y_train,
  device = "cpu",
  n_estimators = 8
)

# Make predictions
predictions <- predict(model, X_test, type = "class")
probabilities <- predict(model, X_test, type = "prob")

# Evaluate
mean(predictions == y_test)
#> [1] 0.96
```

### Model Summary

```r
# View model summary
summary(model)
#> TabPFN model summary
#> 
#> Call:
#> tabpfn(x = X_train, y = y_train, device = "cpu", n_estimators = 8)
#> 
#> Observations: 100 
#> Features: 4 
#> Classes: setosa, versicolor, virginica 
#> Training accuracy: 0.980
```

### Visualization

```r
# Plot probability distributions
plot(model)
```

---

## 💡 Usage Examples

### Working with Categorical Features

```r
# Specify categorical columns by name
model <- tabpfn(
  x = data,
  y = target,
  categorical_features = c("color", "size", "category")
)

# Or by column indices
model <- tabpfn(
  x = data,
  y = target,
  categorical_features = c(2, 5, 7)
)
```

### GPU Acceleration

```r
# Use CUDA if available
model <- tabpfn(
  x = X_train,
  y = y_train,
  device = "cuda"
)
```

### Ensemble Configuration

```r
# Increase ensemble size for potentially better performance
model <- tabpfn(
  x = X_train,
  y = y_train,
  n_estimators = 16  # Default is 8
)
```

### Reproducible Results

```r
# Set random seed for reproducibility
model <- tabpfn(
  x = X_train,
  y = y_train,
  seed = 42
)
```

### Memory-Efficient Mode

```r
# Don't store training data if memory is constrained
model <- tabpfn(
  x = X_train,
  y = y_train,
  return_fitted = FALSE
)
```

---

## 📚 API Reference

### Main Functions

#### `tabpfn()`

Fit a TabPFN classifier.

**Parameters:**
- `x` — Data frame or matrix of predictors
- `y` — Vector or factor of class labels
- `device` — Device for computation: `"cpu"` (default) or `"cuda"`
- `n_estimators` — Number of ensemble members (default: 8)
- `seed` — Random seed for reproducibility (optional)
- `categorical_features` — Column names or indices for categorical variables (optional)
- `return_fitted` — Store training data and fitted values (default: `TRUE`)

**Returns:** Object of class `tabpfn_model`

#### `predict.tabpfn_model()`

Generate predictions from fitted model.

**Parameters:**
- `object` — Fitted `tabpfn_model`
- `newdata` — New data for prediction (optional, uses training data if `NULL`)
- `type` — Prediction type: `"class"` (default) or `"prob"`

**Returns:** Factor (for `type = "class"`) or matrix (for `type = "prob"`)

#### `tabpfn_available()`

Check if TabPFN Python module is available.

**Returns:** Logical value

### S3 Methods

The package provides standard S3 methods for model objects:

- `summary(model)` — Detailed model summary with accuracy and confusion matrix
- `print(model)` — Concise model information
- `plot(model)` — Visualize predictions or probability distributions
- `fitted(model)` — Extract fitted values from training data
- `residuals(model)` — Extract residuals (binary: correct/incorrect)
- `nobs(model)` — Number of training observations
- `coef(model)` — Returns empty vector (TabPFN is not a linear model)

---

## 🔧 Configuration

### Hugging Face Authentication

TabPFN requires a Hugging Face token for model downloads. Set it via:

**Option 1: Environment variable**
```r
Sys.setenv(HF_TOKEN = "your_token_here")
```

**Option 2: File-based** (recommended)
Create a `.hf_token` file in your working directory containing your token.

---

## 📊 Performance Notes

TabPFN is optimized for:
- **Small to medium datasets** (< 10,000 rows recommended)
- **Tabular data** with mixed feature types
- **Multi-class classification** tasks
- **Scenarios requiring fast iteration** without extensive hyperparameter tuning

For very large datasets or when maximum accuracy is critical, consider traditional methods like XGBoost or LightGBM alongside TabPFN.

---

## 🛠️ Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/cassiopagnoncelli/tabpfn.git
cd tabpfn

# Restore R dependencies
R -e "renv::restore()"

# Build package
make build

# Run tests
make test

# Check package
make check
```

### Testing

```bash
# Run unit tests
make test

# Run lint checks
make lint

# Format code
make style
```

---

## 📖 Citation

If you use TabPFN in your research, please cite:

```bibtex
@article{hollmann2022tabpfn,
  title={TabPFN: A Transformer That Solves Small Tabular Classification Problems in a Second},
  author={Hollmann, Noah and M{\"u}ller, Samuel and Eggensperger, Katharina and Hutter, Frank},
  journal={arXiv preprint arXiv:2207.01848},
  year={2022}
}
```

---

## 📄 License

This package is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

---

## 🔗 Resources

- **TabPFN Paper:** [arXiv:2207.01848](https://arxiv.org/abs/2207.01848)
- **Python TabPFN:** [github.com/PriorLabs/TabPFN](https://github.com/PriorLabs/TabPFN)
- **Package Repository:** [github.com/cassiopagnoncelli/tabpfn](https://github.com/cassiopagnoncelli/tabpfn)
- **Report Issues:** [github.com/cassiopagnoncelli/tabpfn/issues](https://github.com/cassiopagnoncelli/tabpfn/issues)

---

<p align="center">
  <i>Built with ❤️ using R and Python</i>
</p>
