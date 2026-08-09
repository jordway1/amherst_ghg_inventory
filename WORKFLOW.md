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

Add a new row (or new data column) for the current fiscal year in each relevant sheet. Refer to existing year entries as a template for structure and units.

------------------------------------------------------------------------

## Step 2 — Download the DOER CSV

The municipal energy inventory (`mei.R`) requires a CSV export from **Mass Energy Insights** (DOER):

1.  Log in at [Mass Energy Insights](https://www.massenergy.org/)
2.  Export the full usage report for the Town of Amherst
3.  Save the CSV to the project root directory (alongside `run_all.R`)

The filename will include the export date (e.g., `output_doer_report_2027-07-10.csv`). Note the exact filename — you will need it in Step 3.

------------------------------------------------------------------------

## Step 3 — Update `params.R`

All year-specific configuration is now centralized in `params.R`. This is the **only file** that needs year and path updates — all sector scripts read from it automatically.

``` r
current_year    <- 2025                # ← change to new fiscal year (e.g., 2026)
baseline_year   <- 2016                # ← only change if the baseline year is being redefined
inventory_years <- c(2016, 2022, 2025) # ← append the new fiscal year (e.g., c(2016, 2022, 2025, 2028))
onedrive_folder <- "2026_GHG_update"  # ← change to match the new OneDrive folder name
```

`current_year` automatically propagates to: - The MEI fiscal year filter (`mei.R`) - The transmission loss factor lookup in `mei.R` - Plot labels and targets calculations in the Quarto report

`inventory_years` automatically propagates to: - The waste model's crossing table (`waste.R`) - The MEI inventory year flag (`mei.R`)

`onedrive_folder` automatically propagates to all five sector scripts.

### Also update: DOER CSV filename in `mei.R`

One value still requires a manual update — the filename of the DOER CSV downloaded in Step 2. Find this line in `mei.R` and update it:

``` r
mei_clean <- read_csv("output_doer_report_2026-07-11.csv")   # ← update filename
```

------------------------------------------------------------------------

## Step 4 — Run `run_all.R`

Open `run_all.R` in RStudio and run the entire script (Ctrl+Shift+Enter / Cmd+Shift+Enter). This will:

1.  Load shared parameters from `params.R`
2.  Connect to OneDrive (a browser authentication window may open on first run)
3.  Source all five sector scripts in sequence
4.  Combine the outputs into a single `ghg_emissions` data frame
5.  Write `ghg_emissions.csv` and `mei_emissions.csv` to the project root
6.  Clear all intermediate objects from the environment, leaving only the two final data frames

If any script throws an error, check: - That the OneDrive folder name in `params.R` is spelled correctly and exists on OneDrive - That the DOER CSV filename in `mei.R` matches the file in the project root exactly - That the new fiscal year's data has been entered in all relevant OneDrive sheets (Step 1)

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

## Summary Checklist

- [ ] New fiscal year data entered in OneDrive spreadsheets
- [ ] DOER CSV downloaded and placed in project root
- [ ] `current_year`, `inventory_years`, and `onedrive_folder` updated in `params.R`
- [ ] DOER CSV filename updated in `mei.R`
- [ ] `run_all.R` run successfully; `ghg_emissions.csv` and `mei_emissions.csv` regenerated
- [ ] Book title updated in `report/_quarto.yml`
- [ ] Narrative text reviewed and updated in `.qmd` chapters
- [ ] Report rendered; output reviewed in `report/_book/`
