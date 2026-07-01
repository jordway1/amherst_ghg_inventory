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

mei_efs <- activity_emissions_key %>%
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = "emissions_factor") %>%
  select(activity, total_co2e_ef, input_year)

# read and clean local MEI export
mei_clean <- read_csv("use_and_costs-export.csv") %>%
  mutate(
    year = year(usage_end),
    activity = case_when(
      account_fuel == "Electric"  ~ "electricity",
      account_fuel == "Oil"       ~ "dist_oil",
      account_fuel == "Gas"       ~ "natural_gas",
      account_fuel == "Diesel"    ~ "diesel",
      account_fuel == "Gasoline"  ~ "gasoline",
      account_fuel == "Propane"   ~ "lpg"
    ),
    use = case_when(
      account_fuel == "Electric" ~ use / 1000,
      .default = use
    ),
    units = case_when(
      account_fuel == "Electric" ~ "MWh",
      .default = default_units
    )
  ) %>%
  filter(year %in% c(2016, 2022, 2025))

# direct emissions
mei_direct <- mei_clean %>%
  left_join(mei_efs, by = c("activity", "year" = "input_year")) %>%
  mutate(total_mtco2e = use * total_co2e_ef)

# transmission/distribution losses for electricity and natural gas
mei_losses <- mei_clean %>%
  inner_join(transmission_loss_factors, by = c("activity" = "fuel_type", "year" = "input_year")) %>%
  mutate(
    use      = use * loss_factor,
    activity = str_c(activity, type, sep = "_")
  ) %>%
  select(-loss_factor, -type) %>%
  left_join(mei_efs, by = c("activity", "year" = "input_year")) %>%
  mutate(total_mtco2e = use * total_co2e_ef)

mei_final <- bind_rows(mei_direct, mei_losses) %>%
  mutate(fiscal_year = factor(str_c("FY ", as.character(year))),
         department = case_when(
           facility %in% c("Amherst Bangs (Senior Ctr.)", "AmherstTown Hall") ~ "Administration",
           facility == "Parking" ~ "Parking",
           .default = department
         ))

