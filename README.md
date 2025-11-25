# tabpfn

R wrapper around the Python [TabPFN](https://github.com/PriorLabs/TabPFN) classifier via `reticulate`.

## Requirements

- R >= 4.4.0
- `reticulate` installed in R
- A Python environment with the `tabpfn` package available (`pip install tabpfn`)

## Usage

```r
library(tabpfn)

# Basic fit
model <- tabpfn(
  x = iris[1:100, 1:4],
  y = iris[1:100, 5],
  device = "cpu",
  n_estimators = 8
)

# Predictions
predict(model, head(iris[1:100, 1:4]), type = "class")
predict(model, head(iris[1:100, 1:4]), type = "prob")

# Helpers
summary(model)
plot(model)
fitted(model)
```

Use `tabpfn_available()` to quickly confirm whether the Python module can be found from `reticulate`.
