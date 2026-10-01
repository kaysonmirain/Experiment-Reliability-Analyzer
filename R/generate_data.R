set.seed(2026)

output_path <- "data/experiment_events.csv"
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

experiments <- data.frame(
  experiment = c("checkout_copy", "recommendation_ranker", "retention_email"),
  observations = c(9000, 7500, 6000),
  baseline_log_odds = c(-2.02, -2.32, -1.72),
  treatment_log_odds = c(0.22, 0.08, 0.31),
  stringsAsFactors = FALSE
)

frames <- lapply(seq_len(nrow(experiments)), function(index) {
  spec <- experiments[index, ]
  n <- spec$observations
  variant <- sample(c("control", "treatment"), n, replace = TRUE)
  device <- sample(c("desktop", "mobile", "tablet"), n, replace = TRUE, prob = c(0.38, 0.54, 0.08))
  returning_user <- rbinom(n, 1, 0.43)
  acquisition_channel <- sample(
    c("search", "social", "email", "direct"), n, replace = TRUE,
    prob = c(0.34, 0.27, 0.19, 0.20)
  )
  linear_predictor <- spec$baseline_log_odds +
    spec$treatment_log_odds * (variant == "treatment") +
    0.36 * returning_user - 0.18 * (device == "mobile") +
    0.15 * (acquisition_channel == "email")
  probability <- plogis(linear_predictor)
  converted <- rbinom(n, 1, probability)
  revenue <- ifelse(converted == 1, round(rlnorm(n, log(58), 0.48), 2), 0)

  data.frame(
    user_id = sprintf("%s-%05d", spec$experiment, seq_len(n)),
    assigned_at = format(
      as.POSIXct("2026-03-01 00:00:00", tz = "UTC") + sample.int(28 * 86400, n, replace = TRUE),
      "%Y-%m-%dT%H:%M:%SZ"
    ),
    experiment = spec$experiment,
    variant = variant,
    device = device,
    returning_user = returning_user,
    acquisition_channel = acquisition_channel,
    converted = converted,
    revenue = revenue,
    stringsAsFactors = FALSE
  )
})

data <- do.call(rbind, frames)
write.csv(data, output_path, row.names = FALSE)
cat(sprintf("generated %d randomized assignments at %s\n", nrow(data), output_path))
