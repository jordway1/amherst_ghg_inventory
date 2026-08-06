# Annual Update Workflow

This document describes the full process for updating the Amherst GHG Inventory for a new fiscal year. Follow the steps in order.

------------------------------------------------------------------------

## Step 1 — Enter Data in the OneDrive Spreadsheets

Before running any code, the underlying activity data must be updated for the new fiscal year. The pipeline reads from three Excel workbooks stored in a OneDrive folder:

| Workbook | Contents |
|------------------------------------|------------------------------------|
| `clean_in_the_sheets.xlsx` | Stationary energy inputs, transportation inputs, emissions factors, transmission loss factors, PVTA model inputs, activity map, activity emissions key |
| `waste_model_inputs.xlsx` | Solid waste tonnages, composition, and disposal method breakdown |
| `livestock_agriculture_inputs.xlsx` | Livestock counts, acreage, and fertilization percentages |

Add a new row for the current fiscal year in each relevant sheet. Refer to existing year entries and associated comments as a template for structure and units.

------------------------------------------------------------------------

## Step 2 — Download the DOER CSV

The municipal energy inventory (`mei.R`) requires a CSV export from **Mass Energy Insights** (DOER):

1.  Log in at [Mass Energy Insights](https://www.massenergy.org/)
2.  Export the full usage report for the Town of Amherst
3.  Save the CSV to the project root directory (alongside `run_all.R`)

The filename will include the export date (e.g., `output_doer_report_2027-07-10.csv`). Note the exact filename — you will need it in Step 4.

------------------------------------------------------------------------

## Step 3 — Update Year References in the R Scripts

Several files have the fiscal year or the OneDrive folder path hardcoded. Update all of the following before running the pipeline.

### `params.R` — line 9

``` r
current_year  <- 2025   # ← change to new fiscal year (e.g., 2026)
baseline_year <- 2016   # ← only change if the baseline year is being redefined (it won't be)
```

### OneDrive folder path — five scripts

The folder name on OneDrive (e.g., `"2026_GHG_update/"`) must match the folder where the new spreadsheets are stored. Update the path in each of the following files:

| File | Line | What to change |
|------------------------|------------------------|------------------------|
| `stationary.R` | 7 | `od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")` |
| `transportation.R` | 7 | `od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")` |
| `waste.R` | 7 | `od$get_item("2026_GHG_update/waste_model_inputs.xlsx")` |
| `waste.R` | 11 | `od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")` |
| `agriculture.R` | 7 | `od$get_item("2026_GHG_update/livestock_agriculture_inputs.xlsx")` |
| `agriculture.R` | 11 | `od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")` |
| `mei.R` | 7 | `od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")` |

Replace `"2026_GHG_update"` with the name of the new OneDrive folder for the current year.

### `mei.R` — line 16

Update the filename to match the DOER CSV downloaded in Step 2:

``` r
mei_clean <- read_csv("output_doer_report_2026-07-11.csv")   # ← update filename
```

------------------------------------------------------------------------

## Step 4 — Run `run_all.R`

Open `run_all.R` in RStudio and run the entire script (Ctrl+Shift+Enter / Cmd+Shift+Enter). This will:

1.  Connect to OneDrive (you will need administrator permission from IT)
2.  Source all five sector scripts in sequence
3.  Combine the outputs into a single `ghg_emissions` data frame
4.  Write `ghg_emissions.csv` and `mei_emissions.csv` to the project root
5.  Clear all intermediate objects from the environment, leaving only the two final data frames

If any script throws an error, check: - That the OneDrive folder path is spelled correctly (Step 3) - That the DOER CSV filename matches exactly (Step 3) - That the new fiscal year's data has been entered in all relevant OneDrive sheets (Step 1)

------------------------------------------------------------------------

## Step 5 — Update the Quarto Book

### Book title (`report/_quarto.yml`, line 16)

``` yaml
title: "Greenhouse Gas Inventory FY 2025"   # ← update year
```

### Narrative text (`.qmd` files)

Review each chapter for year-specific commentary that will need updating:

| File | What to review |
|------------------------------------|------------------------------------|
| `report/index.qmd` | Introduction, inventory year statement |
| `report/municipal/overview.qmd` | Year-over-year summary, targets progress |
| `report/municipal/key_findings.qmd` | Key findings narrative |
| `report/community/overview.qmd` | Community-level summary |
| `report/final_summary.qmd` | Overall conclusions, emissions trajectory |

The data visualizations and tables in the chapters are generated programmatically from `ghg_emissions.csv` and `mei_emissions.csv`, so they will update automatically once the CSVs are regenerated. Only hand-written narrative text needs to be revised.

------------------------------------------------------------------------

## Step 6 — Render the Report

In RStudio, open any file inside `report/` and click **Render Book**, or run the following in the terminal from the project root:

``` bash
cd report
quarto render
```

The rendered HTML book will be output to `report/_book/`. Open `report/_book/index.html` to preview.

------------------------------------------------------------------------
