#!/usr/bin/env Rscript
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(script_arg)) {
  dirname(normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/"))
} else getwd()
set.seed(20261114)
n <- 7 * 24 * 4
t <- seq.POSIXt(as.POSIXct("2026-07-01 00:00:00", tz = ""),
                by = "15 min", length.out = n)
hour <- as.numeric(format(t, "%H")) + as.numeric(format(t, "%M")) / 60
outdoor <- 29 + 5 * sin(2 * pi * (hour - 9) / 24) + rnorm(n, 0, 0.6)
low_period <- hour < 7 | hour >= 22
flow <- ifelse(low_period, 46, 88) + rnorm(n, 0, 5)
delta <- ifelse(low_period, 3.0, 4.7) + rnorm(n, 0, 0.35)
cooling <- 1.163 * flow * delta
target_cop <- ifelse(low_period, 2.8, 4.55) - 0.025 * (outdoor - 29) +
  rnorm(n, 0, 0.23)
power <- cooling / target_cop
sample <- data.frame(
  timestamp = format(t, "%Y-%m-%d %H:%M:%S"), chiller_id = "CH-01",
  chw_supply_c = round(7 + rnorm(n, 0, 0.15), 2),
  chw_return_c = NA_real_, flow_m3h = round(flow, 2),
  power_kw = round(power, 2), outdoor_temp_c = round(outdoor, 2)
)
sample$chw_return_c <- round(sample$chw_supply_c + delta, 2)
sample$power_kw[c(31, 200)] <- 0
sample$flow_m3h[112] <- NA
sample$chw_return_c[420] <- sample$chw_supply_c[420]
second <- sample[1:96, ]
second$chiller_id <- "CH-02"
second$power_kw <- round(second$power_kw * 1.08, 2)
data <- rbind(sample, second)
dir.create(file.path(project_dir, "data"), recursive = TRUE,
           showWarnings = FALSE)
target <- file.path(project_dir, "data", "example_bms.csv")
write.csv(data, target, row.names = FALSE, na = "", fileEncoding = "UTF-8")
cat("Generated: ", target, "\n")
