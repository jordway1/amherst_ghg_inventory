library(tidyverse)
library(Microsoft365R)
library(readxl)

# read reference tables from OneDrive spreadsheet
if (!exists("od")) od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)
activity_emissions_key    <- read_xlsx(tmp, sheet = "activity_emissions_key")
emissions_factors         <- read_xlsx(tmp, sheet = "emissions_factors")
transmission_loss_factors <- read_xlsx(tmp, sheet = "transmission_loss_factors") %>%
  select(fuel_type, type, loss_factor, input_year)


mei_clean <- read_csv("output_doer_report_2026-07-11.csv") %>%
  mutate(
    usage_usage_start = coalesce(usage_usage_start, usage_usage_end - days(usage_days)),
    fiscal_year = if_else(month(usage_usage_end) >= 7,
                          year(usage_usage_end) + 1,
                          year(usage_usage_end)),
    activity = case_when(
      account_fuel == "Electric"  ~ "electricity",
      account_fuel == "Oil"       ~ "dist_oil",
      account_fuel == "Gas"       ~ "natural_gas",
      account_fuel == "Diesel"    ~ "diesel",
      account_fuel == "Gasoline"  ~ "gasoline",
      account_fuel == "Propane"   ~ "lpg"
    ),
    use_updated_units = case_when(
      account_fuel == "Electric" ~ usage_use / 1000,
      .default = usage_use
    ),
    updated_units = case_when(             #shockingly, they don't include units in their document... ridiculous
      account_fuel == "Electric" ~ "MWh",
      account_fuel == "Oil" ~ "gallons",
      account_fuel == "Gas" ~ "therms",
      account_fuel == "Diesel" ~ "gallons",
      account_fuel == "Gasoline" ~ "gallons",
      account_fuel == "Propane" ~ "gallons"
    ),
    supercategory = case_when(
      account_fuel %in% c("Electric", "Gas", "Oil", "Propane") ~ "stationary_energy",
      account_fuel %in% c("Diesel", "Gasoline") ~ "transportation"
    ),
    fiscal_year_string = str_c("FY ", fiscal_year),
    building = case_when(
      building == "pump stations" ~ "Pump Stations",
      .default = building
    ),
    inventory_year = ifelse(fiscal_year %in% c(2016,2022,2025), "1", "0")
  ) %>%
  filter(fiscal_year < 2026)


write_csv(mei_clean, "mei_final.csv")
