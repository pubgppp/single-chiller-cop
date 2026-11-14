# Single-Chiller COP Quick Check

This small R project reads a week of BMS data for one chiller, calculates cooling capacity, load ratio, and instantaneous coefficient of performance (COP), and creates a one-page PDF report. A parameterized R Markdown version uses ggplot2 for the charts.

## Quick start

Requires R 4.1 or later. The default script uses only base R and writes `report.pdf` in the project directory.

```powershell
Rscript generate_example.R
Rscript run.R
```

On Windows, use the full path to `Rscript.exe` if R is not on your PATH.

To analyze another chiller or CSV file:

```powershell
Rscript run.R --input=C:/data/bms_week.csv --machine=CH-02 --rated_kw=700 --low_cop=3.5 --low_load=0.30 --output=C:/data/CH-02-report.pdf
```

Use `--name=value` with no spaces around the equals sign. `rated_kw` is the chiller's rated cooling capacity in kW. `low_cop` and `low_load` are adjustable screening thresholds.

## Input CSV

The first row must contain the following column names. Save the file as UTF-8. One file may contain multiple chillers; the `machine` option selects one chiller ID.

| Column | Description | Unit or format |
|---|---|---|
| `timestamp` | Sample timestamp | `YYYY-MM-DD HH:MM:SS` |
| `chiller_id` | Chiller identifier | Text |
| `chw_supply_c` | Chilled-water supply temperature | °C |
| `chw_return_c` | Chilled-water return temperature | °C |
| `flow_m3h` | Chilled-water flow | m³/h |
| `power_kw` | Chiller electric power | kW |
| `outdoor_temp_c` | Outdoor air temperature | °C |

`data/example_bms.csv` contains **synthetic data** for demonstration only. Check that flow and power refer to the same chiller and sample time. The calculation is `cooling capacity (kW) = 1.163 × flow (m³/h) × (return - supply temperature) (°C)`, followed by `COP = cooling capacity / power`. The factor 1.163 is a common approximation for water. For glycol mixtures, adjust `water_factor` in `core.R` to match the fluid properties. Records with missing values, invalid timestamps, nonpositive flow or power, or nonpositive temperature difference are excluded.

## R Markdown and ggplot2 version

Install `ggplot2`, `rmarkdown`, `knitr`, and XeLaTeX (for example, through TinyTeX). Then run the following from the project directory:

```r
install.packages(c("ggplot2", "rmarkdown", "knitr", "tinytex"))
tinytex::install_tinytex()
rmarkdown::render("report.Rmd", params = list(
  input = "data/example_bms.csv", machine = "CH-01",
  rated_kw = 700, low_cop = 3.5, low_load = 0.30
))
```

You can also open `report.Rmd` in RStudio and use **Knit with Parameters**. On systems without Arial, change `mainfont` and `base_family` in the template to an installed font.

## Interpreting the results

Red points indicate both low load and low COP; orange points indicate low COP alone. Percentages are based on the **number of valid samples**. If sampling intervals vary, these percentages do not represent operating-time or energy shares. The report is a quick screening tool, not a substitute for a formal performance test or energy-savings calculation. Set thresholds using the chiller's performance data and site conditions.
