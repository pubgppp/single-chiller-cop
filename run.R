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
    if (!grepl("^--[^=]+=", arg)) stop("参数应为 --名称=值：", arg)
    parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
    key <- parts[1]
    if (!(key %in% names(options))) stop("未知参数：", key)
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
                     family = "Microsoft YaHei", onefile = TRUE)
on.exit(grDevices::dev.off(), add = TRUE)
par(family = "Microsoft YaHei", mar = c(4.1, 4.2, 3.2, 1.2),
    oma = c(0, 0, 0, 0))
layout(matrix(c(1, 1, 2, 3, 4, 4), nrow = 3, byrow = TRUE),
       heights = c(0.9, 3.4, 1.5))

plot.new()
title_text <- sprintf("单台冷机 COP 快速体检表  |  %s", result$machine_id)
text(0.01, 0.78, title_text, adj = 0, cex = 1.55, font = 2)
text(0.01, 0.38,
     sprintf("数据期间：%s 至 %s    额定制冷量：%.0f kW    有效记录：%d / %d",
             format(min(x$timestamp), "%Y-%m-%d"),
             format(max(x$timestamp), "%Y-%m-%d"), result$rated_kw,
             nrow(x), result$total), adj = 0, cex = 0.95, col = "#405064")

point_cols <- ifelse(x$attention, "#d94841",
                     ifelse(x$low_efficiency, "#e49c31", "#2878a9"))
plot(x$load_ratio * 100, x$cop, pch = 16, col = adjustcolor(point_cols, 0.65),
     xlab = "负荷率 (%)", ylab = "实时 COP", main = "COP 与负荷率")
abline(h = result$low_cop, lty = 2, col = "#b94440", lwd = 1.4)
abline(v = result$low_load * 100, lty = 3, col = "#b94440", lwd = 1.2)
grid(col = "#e6e9ee")

plot(x$outdoor_temp_c, x$cop, pch = 16,
     col = adjustcolor(point_cols, 0.65), xlab = "室外温度 (°C)",
     ylab = "实时 COP", main = "COP 与室外温度")
abline(h = result$low_cop, lty = 2, col = "#b94440", lwd = 1.4)
grid(col = "#e6e9ee")
legend("topright", legend = c("正常", "低 COP", "低负荷且低 COP"),
       col = c("#2878a9", "#e49c31", "#d94841"), pch = 16,
       bty = "n", cex = 0.73)

plot.new()
stats <- cop_summary(result)
text(0.01, 0.89,
     sprintf("平均 COP  %.2f       中位 COP  %.2f       低效时段  %.1f%%       低负荷且低效  %.1f%%",
             mean(x$cop), median(x$cop), 100 * mean(x$low_efficiency),
             100 * mean(x$attention)), adj = 0, cex = 1.08, font = 2)
suggestion <- if (any(x$attention)) {
  "观察到低负荷且低 COP 时段；建议核对低负荷运行时长、启停策略及水流量。"
} else if (any(x$low_efficiency)) {
  "观察到低 COP 时段；建议结合室外温度和负荷率核对运行设定。"
} else {
  "样本中没有低于设定 COP 阈值的时段；持续观察负荷与室外温度变化。"
}
text(0.01, 0.52, suggestion, adj = 0, cex = 0.89)
text(0.01, 0.20,
     sprintf("计算：制冷量 = %.3f × 流量(m³/h) × 回水-供水(°C)；COP = 制冷量/功率。阈值：COP < %.2f，负荷率 < %.0f%%。",
             result$water_factor, result$low_cop, 100 * result$low_load),
     adj = 0, cex = 0.76, col = "#596579")
cat("已生成：", normalizePath(options$output, winslash = "/"), "\n")
