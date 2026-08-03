# Town of Amherst GHG Inventory


## Introduction

Welcome to the back end of the Amherst GHG report. I inherited this project as a massive excel document with 213 sheets, which I found to be unacceptable, if sufficiently effective. 
My goals during this fellowship were to rework this process into a reproducible format that abides by data hygiene standards, and to produce a final report that utilizes reporting 
tools with R (ggplot2, markdown books, etc.) that will be more insightful and be itself more reproducible than the existing long pdf format. 

## Data Pipeline

This should be the biggest improvement on the existing excel-based framework. There are four scripts, one for each emission sector (stationary.R, transportation.R, waste.R, and 
agriculture.R) that reproduce the logic found in the existing workbook. These numbers do not exactly match the figures published in the previous inventories, but these differences
are due to changes I made, whether it be updating emissions factors or finding minor errors in the previous inventories. I made these changes after successfully replicating the exact
figures previously published, to ensure that the new process was consistent with the previous. The four aforementioned scripts can be run independently, but each are called in the 
"run_all.R" script that outputs two files: "ghg_emissions.csv" and "mei_emissions.csv". "mei_emissions.csv" refers to data downloaded from Mass Energy Insights, which only contains 
municipal emissions and fuel usage information. The actual emissions reported by MEI should match the municipal emissions in "ghg_emissions.csv" except for transmission and 
distribution losses. I use this dataset for the municipal section of the report because it contains much more information. 

The four previously mentioned emissions sector scripts pull data from spreadsheets that I created. In their current form, they pull directly form Onedrive sheets for convenience, but
I will be sure to save static csvs once I finalize this report.

To summarize, the "run_all.R" script produces two csv files 
that all of the analysis is based off of. If a future user of the report 