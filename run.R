#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (!l10n_info()[["UTF-8"]]) {
  invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
}
project_dir <- if (length(script_arg)) {
  dirname(normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/"))
} else getwd()
source(file.path(project_dir, "core.R"), encoding = "UTF-8")

options <- list(input = file.path(project_dir, "data", "example_bms.csv"),
                machine = "CH-01", rated_kw = 700, low_cop = 3.5,
                low_load = 0.30,
                output = file.path(project_dir, "report.pdf"))
if (length(args)) {
  for (arg in args) {
    if (!grepl("^--[^=]+=", arg)) stop("Use --name=value: ", arg)
    parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
    key <- parts[1]
    if (!(key %in% names(options))) stop("Unknown option: ", key)
    options[[key]] <- paste(parts[-1], collapse = "=")
  }
}
options$rated_kw <- as.numeric(options$rated_kw)
options$low_cop <- as.numeric(options$low_cop)
options$low_load <- as.numeric(options$low_load)
result <- load_cop_data(options$input, options$machine, options$rated_kw,
                        options$low_cop, options$low_load)
x <- result$data
dir.create(dirname(options$output), recursive = TRUE, showWarnings = FALSE)

grDevices::cairo_pdf(options$output, width = 11.69, height = 8.27,
                     family = "Arial", onefile = TRUE)
on.exit(grDevices::dev.off(), add = TRUE)
par(family = "Arial", mar = c(4.1, 4.2, 3.2, 1.2),
    oma = c(0, 0, 0, 0))
layout(matrix(c(1, 1, 2, 3, 4, 4), nrow = 3, byrow = TRUE),
       heights = c(0.9, 3.4, 1.5))

plot.new()
title_text <- sprintf("Single-Chiller COP Quick Check  |  %s", result$machine_id)
text(0.01, 0.78, title_text, adj = 0, cex = 1.55, font = 2)
text(0.01, 0.38,
     sprintf("Period: %s to %s    Rated capacity: %.0f kW    Valid records: %d / %d",
             format(min(x$timestamp), "%Y-%m-%d"),
             format(max(x$timestamp), "%Y-%m-%d"), result$rated_kw,
             nrow(x), result$total), adj = 0, cex = 0.95, col = "#405064")

point_cols <- ifelse(x$attention, "#d94841",
                     ifelse(x$low_efficiency, "#e49c31", "#2878a9"))
plot(x$load_ratio * 100, x$cop, pch = 16, col = adjustcolor(point_cols, 0.65),
     xlab = "Load ratio (%)", ylab = "Instantaneous COP", main = "COP vs Load Ratio")
abline(h = result$low_cop, lty = 2, col = "#b94440", lwd = 1.4)
abline(v = result$low_load * 100, lty = 3, col = "#b94440", lwd = 1.2)
grid(col = "#e6e9ee")

plot(x$outdoor_temp_c, x$cop, pch = 16,
     col = adjustcolor(point_cols, 0.65), xlab = "Outdoor temperature (°C)",
     ylab = "Instantaneous COP", main = "COP vs Outdoor Temperature")
abline(h = result$low_cop, lty = 2, col = "#b94440", lwd = 1.4)
grid(col = "#e6e9ee")
legend("topright", legend = c("Normal", "Low COP", "Low load + low COP"),
       col = c("#2878a9", "#e49c31", "#d94841"), pch = 16,
       bty = "n", cex = 0.73)

plot.new()
stats <- cop_summary(result)
text(0.01, 0.89,
     sprintf("Mean COP  %.2f       Median COP  %.2f       Low-COP points  %.1f%%       Low-load + low-COP  %.1f%%",
             mean(x$cop), median(x$cop), 100 * mean(x$low_efficiency),
             100 * mean(x$attention)), adj = 0, cex = 1.02, font = 2)
suggestion <- if (any(x$attention)) {
  "Low-load, low-COP points found. Check operating duration, staging strategy, and chilled-water flow."
} else if (any(x$low_efficiency)) {
  "Low-COP points found. Review operating settings against load ratio and outdoor temperature."
} else {
  "No points fell below the COP threshold. Continue monitoring load and outdoor temperature."
}
text(0.01, 0.52, suggestion, adj = 0, cex = 0.89)
text(0.01, 0.23,
     sprintf("Cooling (kW) = %.3f × flow (m³/h) × (return - supply) (°C); COP = cooling / power.",
             result$water_factor),
     adj = 0, cex = 0.76, col = "#596579")
text(0.01, 0.05,
     sprintf("Screening thresholds: COP < %.2f; load ratio < %.0f%%. Excluded records: %d.",
             result$low_cop, 100 * result$low_load, result$excluded),
     adj = 0, cex = 0.76, col = "#596579")
cat("Generated: ", normalizePath(options$output, winslash = "/"), "\n")
