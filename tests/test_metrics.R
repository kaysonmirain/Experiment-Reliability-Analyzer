source("R/metrics.R")

control <- c(rep(0, 80), rep(1, 20))
treatment <- c(rep(0, 70), rep(1, 30))

stopifnot(abs(conversion_rate(control) - 0.20) < 1e-9)
stopifnot(abs(conversion_rate(treatment) - 0.30) < 1e-9)
stopifnot(abs(risk_difference(control, treatment) - 0.10) < 1e-9)
stopifnot(abs(relative_lift(control, treatment) - 0.50) < 1e-9)

interval <- bootstrap_risk_difference(control, treatment, repetitions = 500, seed = 7)
stopifnot(interval$estimate > 0)
stopifnot(interval$probability_positive > 0.8)
stopifnot(sample_ratio_p_value(rep(c("control", "treatment"), 100)) > 0.9)

cat("experiment reliability tests passed\n")
