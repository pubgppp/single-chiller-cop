# 单台冷机 COP 快速体检表

输入一周 BMS 导出的 CSV，计算单台冷机每个采样点的制冷量、负荷率和 COP，生成一页 PDF 体检表。项目也提供可参数化的 R Markdown 版本，使用 ggplot2 绘图。

## 直接运行

要求 R 4.1 或更新版本。默认 PDF 路径为项目目录下的 `report.pdf`，这条方式只用 R 自带包。

```powershell
Rscript generate_example.R
Rscript run.R
```

如果 Windows 上没有把 R 加入 PATH，可用 Rscript.exe 的完整路径运行。

更换机组和数据文件：

```powershell
Rscript run.R --input=C:/data/bms_week.csv --machine=CH-02 --rated_kw=700 --low_cop=3.5 --low_load=0.30 --output=C:/data/CH-02-report.pdf
```

参数名后使用等号，不加空格。`rated_kw` 是这台机组的额定制冷量，单位 kW；`low_cop` 和 `low_load` 是可调整的筛查阈值。

## CSV 字段

第一行应包含以下英文列名，编码为 UTF-8；多台机组可放在同一个文件中。

| 列名 | 含义 | 单位或格式 |
|---|---|---|
| `timestamp` | 采样时间 | `YYYY-MM-DD HH:MM:SS` |
| `chiller_id` | 机组编号 | 文本 |
| `chw_supply_c` | 冷冻水供水温度 | °C |
| `chw_return_c` | 冷冻水回水温度 | °C |
| `flow_m3h` | 冷冻水流量 | m³/h |
| `power_kw` | 机组电功率 | kW |
| `outdoor_temp_c` | 室外温度 | °C |

示例文件在 `data/example_bms.csv`，是**模拟数据**，只用于演示。请确认现场流量和电功率均对应同一台机组、同一采样时刻。计算式为 `制冷量(kW) = 1.163 × 流量(m³/h) × (回水温度 - 供水温度)(°C)`，适用于以水为介质的常见近似计算；含乙二醇的系统应修改 `core.R` 的 `water_factor`。功率为非正、流量为非正、温差为非正、缺值或时间格式不符的记录会剔除。

## R Markdown + ggplot2 版本

安装 `ggplot2`、`rmarkdown`、`knitr`，并安装 XeLaTeX（例如 TinyTeX）后，在项目目录运行：

```r
install.packages(c("ggplot2", "rmarkdown", "knitr", "tinytex"))
tinytex::install_tinytex()
rmarkdown::render("report.Rmd", params = list(
  input = "data/example_bms.csv", machine = "CH-01",
  rated_kw = 700, low_cop = 3.5, low_load = 0.30
))
```

也可以在 RStudio 中打开 `report.Rmd`，使用 Knit with Parameters 修改参数并生成 PDF。若使用非 Windows 系统，需把模板中的 `mainfont` 和 `base_family` 改为本机支持中文的字体。

## 结果解读

图中红点表示低负荷且低 COP，橙点表示低 COP。低效时段占比按**有效采样点数**统计；若采样间隔不一致，不应把它直接当作耗电时长占比。体检表用于定位值得排查的工况，不代替设备性能测试或节能量核算。
