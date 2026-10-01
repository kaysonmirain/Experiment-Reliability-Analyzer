source("R/metrics.R")

input_path <- "data/experiment_events.csv"
output_dir <- "results"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

data <- read.csv(input_path, stringsAsFactors = FALSE)
data$variant <- factor(data$variant, levels = c("control", "treatment"))
data$device <- factor(data$device)
data$acquisition_channel <- factor(data$acquisition_channel)

results <- lapply(sort(unique(data$experiment)), function(experiment_name) {
  frame <- data[data$experiment == experiment_name, ]
  control <- frame$converted[frame$variant == "control"]
  treatment <- frame$converted[frame$variant == "treatment"]
  test <- prop.test(
    x = c(sum(control), sum(treatment)),
    n = c(length(control), length(treatment)),
    correct = FALSE
  )
  interval <- bootstrap_risk_difference(control, treatment, repetitions = 2000)
  control_rate <- conversion_rate(control)
  treatment_rate <- conversion_rate(treatment)
  required_per_arm <- if (abs(treatment_rate - control_rate) < 1e-6) {
    NA_real_
  } else {
    ceiling(power.prop.test(
      p1 = control_rate, p2 = treatment_rate, sig.level = 0.05, power = 0.8,
      alternative = "two.sided"
    )$n)
  }

  data.frame(
    experiment = experiment_name,
    control_n = length(control),
    treatment_n = length(treatment),
    control_rate = control_rate,
    treatment_rate = treatment_rate,
    absolute_lift = interval$estimate,
    relative_lift = relative_lift(control, treatment),
    lower_95 = interval$lower_95,
    upper_95 = interval$upper_95,
    probability_positive = interval$probability_positive,
    p_value = test$p.value,
    sample_ratio_p_value = sample_ratio_p_value(frame$variant),
    future_required_per_arm = required_per_arm,
    revenue_per_user_control = mean(frame$revenue[frame$variant == "control"]),
    revenue_per_user_treatment = mean(frame$revenue[frame$variant == "treatment"]),
    stringsAsFactors = FALSE
  )
})

inference <- do.call(rbind, results)
inference$adjusted_p_value <- p.adjust(inference$p_value, method = "BH")
inference$decision <- ifelse(
  inference$adjusted_p_value < 0.05 & inference$lower_95 > 0,
  "ship treatment",
  "collect more evidence"
)

arm_summary <- do.call(rbind, lapply(
  split(data, list(data$experiment, data$variant), drop = TRUE),
  function(frame) {
    data.frame(
      experiment = frame$experiment[1],
      variant = as.character(frame$variant[1]),
      assignments = nrow(frame),
      conversions = sum(frame$converted),
      conversion_rate = mean(frame$converted),
      revenue = sum(frame$revenue),
      revenue_per_user = mean(frame$revenue),
      stringsAsFactors = FALSE
    )
  }
))
row.names(arm_summary) <- NULL
model <- glm(
  converted ~ experiment * variant + device + returning_user + acquisition_channel,
  data = data,
  family = binomial()
)

write.csv(inference, file.path(output_dir, "experiment_inference.csv"), row.names = FALSE)
write.csv(arm_summary, file.path(output_dir, "arm_summary.csv"), row.names = FALSE)
capture.output(summary(model), file = file.path(output_dir, "adjusted_logistic_model.txt"))

png(file.path(output_dir, "lift_forest_plot.png"), width = 1400, height = 700)
par(mar = c(5, 12, 4, 2) + 0.1)
positions <- seq_len(nrow(inference))
plot(
  inference$absolute_lift, positions,
  xlim = range(c(inference$lower_95, inference$upper_95, 0)),
  yaxt = "n", pch = 19, col = "#0f766e",
  xlab = "Absolute conversion-rate lift", ylab = "", main = "Experiment lift with bootstrap 95% intervals"
)
segments(inference$lower_95, positions, inference$upper_95, positions, lwd = 3, col = "#0f766e")
abline(v = 0, lty = 2, col = "#64748b")
axis(2, at = positions, labels = inference$experiment, las = 1)
dev.off()

print(inference, row.names = FALSE)
