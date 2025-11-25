devtools::load_all()

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
residuals(model)
