required_columns <- c(
  "timestamp", "chiller_id", "chw_supply_c", "chw_return_c",
  "flow_m3h", "power_kw", "outdoor_temp_c"
)

load_cop_data <- function(input, machine_id, rated_kw, low_cop = 3.5,
                          low_load = 0.30, water_factor = 1.163) {
  if (!file.exists(input)) stop("找不到输入文件：", input)
  if (!is.finite(rated_kw) || rated_kw <= 0) stop("额定制冷量 rated_kw 必须大于 0")
  if (!is.finite(low_cop) || low_cop <= 0) stop("low_cop 必须大于 0")
  if (!is.finite(low_load) || low_load <= 0 || low_load >= 1) {
    stop("low_load 必须在 0 与 1 之间")
  }
  raw <- read.csv(input, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE,
                  check.names = FALSE)
  missing <- setdiff(required_columns, names(raw))
  if (length(missing)) stop("CSV 缺少字段：", paste(missing, collapse = ", "))
  x <- raw[trimws(as.character(raw$chiller_id)) == machine_id, required_columns,
           drop = FALSE]
  if (!nrow(x)) stop("文件中没有机组：", machine_id)
  total <- nrow(x)
  x$timestamp <- as.POSIXct(x$timestamp, format = "%Y-%m-%d %H:%M:%S",
                            tz = "")
  numeric_cols <- c("chw_supply_c", "chw_return_c", "flow_m3h", "power_kw",
                    "outdoor_temp_c")
  for (column in numeric_cols) x[[column]] <- suppressWarnings(as.numeric(x[[column]]))
  complete <- !is.na(x$timestamp) & rowSums(!is.finite(as.matrix(x[numeric_cols]))) == 0
  x <- x[complete, , drop = FALSE]
  x$delta_t_c <- x$chw_return_c - x$chw_supply_c
  operating <- x$flow_m3h > 0 & x$power_kw > 0 & x$delta_t_c > 0
  x <- x[operating, , drop = FALSE]
  if (!nrow(x)) stop("没有有效运行记录；检查时间格式、流量、功率和供回水温差")
  x$cooling_kw <- water_factor * x$flow_m3h * x$delta_t_c
  x$cop <- x$cooling_kw / x$power_kw
  x$load_ratio <- x$cooling_kw / rated_kw
  x$low_efficiency <- x$cop < low_cop
  x$low_load <- x$load_ratio < low_load
  x$attention <- x$low_efficiency & x$low_load
  x <- x[order(x$timestamp), , drop = FALSE]
  list(data = x, total = total, excluded = total - nrow(x),
       machine_id = machine_id, rated_kw = rated_kw, low_cop = low_cop,
       low_load = low_load, water_factor = water_factor)
}

cop_summary <- function(result) {
  x <- result$data
  data.frame(
    metric = c("有效记录", "剔除记录", "平均 COP", "中位 COP",
               "低效时段占比", "低负荷且低效占比", "平均负荷率"),
    value = c(as.character(nrow(x)), as.character(result$excluded),
              sprintf("%.2f", mean(x$cop)), sprintf("%.2f", median(x$cop)),
              sprintf("%.1f%%", 100 * mean(x$low_efficiency)),
              sprintf("%.1f%%", 100 * mean(x$attention)),
              sprintf("%.1f%%", 100 * mean(x$load_ratio))),
    stringsAsFactors = FALSE
  )
}
