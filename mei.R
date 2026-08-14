library(tidyverse)
library(Microsoft365R)
library(readxl)

if (!exists("onedrive_folder")) source("params.R")
if (!exists("od")) od <- get_business_onedrive()

# read reference tables from OneDrive spreadsheet
item <- od$get_item(paste0(onedrive_folder, "/clean_in_the_sheets.xlsx"))
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
    inventory_year = ifelse(fiscal_year %in% inventory_years, "1", "0"),
  ) %>%
  filter(fiscal_year <= current_year)

# Override MEI electricity emissions factors with spreadsheet values for consistency
# with the community pipeline (MEI has multiple factors per year; the spreadsheet has one)
elec_ef_lookup <- activity_emissions_key |>
  filter(activity == "electricity") |>
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = "emissions_factor") |>
  transmute(input_year, spreadsheet_ef_kwh = total_co2e_ef / 1000)

mei_clean <- mei_clean |>
  left_join(elec_ef_lookup, by = c("fiscal_year" = "input_year")) |>
  mutate(
    emission_mtco2e_factor = if_else(!is.na(spreadsheet_ef_kwh) & activity == "electricity",
                                      spreadsheet_ef_kwh, emission_mtco2e_factor),
    emission_mtco2e = if_else(!is.na(spreadsheet_ef_kwh) & activity == "electricity",
                               usage_use * emission_mtco2e_factor, emission_mtco2e)
  ) |>
  select(-spreadsheet_ef_kwh)

# transmission losses - this will need to be updated when new data arrives
# I'm generalizing the loss factors since I don't want to hunt down the data for every single year
transmission_losses <- mei_clean |> 
  mutate(loss_year = case_when(
    fiscal_year <= 2016 ~ 2016,
    fiscal_year <= 2022 ~ 2022,
    .default = current_year  # use most recent available factor for all later years
  )) |> 
  inner_join(transmission_loss_factors, by = c("activity" = "fuel_type", "loss_year" = "input_year")) |> 
  mutate(loss_amount = use_updated_units * loss_factor) |> 
  left_join(select(activity_emissions_key, activity, input_year, emissions_factor), by = c("activity" = "activity", "fiscal_year" = "input_year")) |> 
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = "emissions_factor") |> 
  mutate(emission_mtco2e = loss_amount * total_co2e_ef,
         activity = str_c(activity, "_", type)) |> 
  select(-c(total_co2e_ef, emissions_factor, loss_amount, loss_factor, type, loss_year))


mei_final <- bind_rows(mei_clean, transmission_losses) |> 
  filter(!is.na(emission_mtco2e))

write_csv(mei_final, "mei_final.csv")
