# Town of Amherst GHG Inventory

This repository contains the data pipeline and Quarto report for the Town of Amherst's annual Greenhouse Gas (GHG) Inventory. It covers both the **Municipal Inventory** (town government operations) and the **Community Inventory** (town-wide emissions), and produces an interactive HTML book as its final output.

The project was originally built during the 2025–26 Amherst Fellowship, replacing a 213-sheet Excel workbook with a reproducible, code-driven pipeline.

---

## Repository Structure

```
.
├── run_all.R                   # Master script: sources all sector scripts, writes output CSVs
├── params.R                    # Shared parameters (fiscal year, colors, ggplot theme)
├── stationary.R                # Stationary energy emissions
├── transportation.R            # Transportation emissions
├── waste.R                     # Waste emissions
├── agriculture.R               # AFOLU emissions
├── mei.R                       # Municipal Energy Inventory (DOER/Mass Energy Insights)
├── output_doer_report_*.csv    # Raw DOER CSV export (manually downloaded each year)
├── ghg_emissions.csv           # Output: community + municipal GHG emissions
├── mei_emissions.csv           # Output: municipal energy inventory
└── report/
    ├── _quarto.yml             # Quarto book configuration
    ├── index.qmd               # Introduction chapter
    ├── final_summary.qmd       # Summary chapter
    ├── municipal/              # Municipal inventory chapters
    └── community/              # Community inventory chapters
```

---

## Data Sources

| Source | Format | Access | Used by |
|---|---|---|---|
| `clean_in_the_sheets.xlsx` | Excel (OneDrive) | Microsoft 365 account | `stationary.R`, `transportation.R`, `waste.R`, `agriculture.R`, `mei.R` |
| `waste_model_inputs.xlsx` | Excel (OneDrive) | Microsoft 365 account | `waste.R` |
| `livestock_agriculture_inputs.xlsx` | Excel (OneDrive) | Microsoft 365 account | `agriculture.R` |
| DOER report CSV | CSV (local) | Downloaded from Mass Energy Insights | `mei.R` |

The OneDrive spreadsheets are the primary data entry point. A future user should populate these with updated activity data before running the pipeline.

---

## Prerequisites

- **R** (≥ 4.1) with the following packages:
  - `tidyverse`, `Microsoft365R`, `readxl`, `gt`, `plotly`, `scales`
- **Quarto** (for rendering the report)
- A **Microsoft 365 account** with access to the shared OneDrive folder
- The **DOER CSV export** downloaded from [Mass Energy Insights](https://www.massenergy.org/) and placed in the project root

---

## Quick Start

See [WORKFLOW.md](WORKFLOW.md) for the full step-by-step annual update process, including every file that needs to be changed.

In brief:
1. Enter new fiscal year's data into the OneDrive spreadsheets
2. Download the new DOER CSV from Mass Energy Insights and place it in the project root
3. Update year references in `params.R` and the five sector/MEI scripts
4. Run `run_all.R`
5. Update the Quarto book title and narrative text, then render

---

## Output

Running `run_all.R` produces two CSV files used by the report:

- **`ghg_emissions.csv`** — all community and municipal emissions by sector, subcategory, scope, and activity
- **`mei_emissions.csv`** — municipal energy usage and emissions from Mass Energy Insights (used for the municipal section of the report due to its richer detail)

The Quarto book is rendered from the `report/` directory and outputs an HTML book to `report/_book/`.
