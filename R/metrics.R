conversion_rate <- function(outcomes) {
  stopifnot(length(outcomes) > 0, all(outcomes %in% c(0, 1)))
  mean(outcomes)
}

risk_difference <- function(control, treatment) {
  conversion_rate(treatment) - conversion_rate(control)
}

relative_lift <- function(control, treatment) {
  baseline <- conversion_rate(control)
  if (baseline == 0) return(NA_real_)
  risk_difference(control, treatment) / baseline
}

bootstrap_risk_difference <- function(control, treatment, repetitions = 2000, seed = 2026) {
  stopifnot(length(control) > 1, length(treatment) > 1, repetitions > 10)
  set.seed(seed)
  deltas <- replicate(repetitions, {
    sampled_control <- sample(control, length(control), replace = TRUE)
    sampled_treatment <- sample(treatment, length(treatment), replace = TRUE)
    risk_difference(sampled_control, sampled_treatment)
  })
  data.frame(
    estimate = risk_difference(control, treatment),
    lower_95 = unname(quantile(deltas, 0.025)),
    upper_95 = unname(quantile(deltas, 0.975)),
    probability_positive = mean(deltas > 0)
  )
}

sample_ratio_p_value <- function(variants, expected_treatment_share = 0.5) {
  observed <- table(factor(variants, levels = c("control", "treatment")))
  stats::chisq.test(observed, p = c(1 - expected_treatment_share, expected_treatment_share))$p.value
}
