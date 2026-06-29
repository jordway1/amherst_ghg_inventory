library(tidyverse)
library(Microsoft365R)
library(readxl)

# connecting to Onedrive and reading stationary inputs, trans loss factors
if (!exists("od")) od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)

stationary_inputs <- read_xlsx(tmp, sheet = "stationary_inputs") 
transmission_loss_factors <- read_xlsx(tmp, sheet = "transmission_loss_factors")
heat_model_inputs <- read_xlsx(tmp, sheet = "res_heat_oil_model_inputs")
emissions_factors <- read_xlsx(tmp, sheet = "emissions_factors")
activity_emissions_key <- read_xlsx(tmp, sheet = "activity_emissions_key")
activity_map <- read_xlsx(tmp, sheet = "activity_map")


# recoding activity names for my own sanity
stationary_inputs_clean <- stationary_inputs %>%
  left_join(activity_map, by = 'activity')

# preparing in format for final output
stationary_hardcoded <- stationary_inputs_clean %>%
  select(supercategory, subcategory, gpc_ref, scope, activity=activity_recoded, entity, amount, units, input_year)

# electricity and natural gas have transmission losses that need to be calculated
transmission_loss_factors <- transmission_loss_factors %>% 
  select(fuel_type, type, loss_factor, input_year)

trans_emissions <- stationary_inputs_clean %>% 
  inner_join(transmission_loss_factors, by = c('activity_recoded' = 'fuel_type', 'input_year' = 'input_year')) %>%
  mutate(loss_amount = amount * loss_factor)

# reformatting transmission losses into the same format as the previous data
trans_emissions_final <- trans_emissions %>%
  mutate(activity_final = str_c(activity_recoded, type, sep = "_"),
         gpc_ref = case_when(
           activity_recoded == "electricity" ~ "I.2.3",
           activity_recoded == "natural_gas" ~ "I.8.1"
         ),
         scope = case_when(
           activity_recoded == "electricity" ~ 3,
           activity_recoded == "natural_gas" ~ 1
         )) %>%
  select(supercategory, subcategory, gpc_ref, scope, activity = activity_final, entity, amount=loss_amount, units, input_year)


# resident Heating Oil Model (gallons/year)
heating_model <- heat_model_inputs %>%
  mutate(households_heating = total_households*pct_using_heating_oil,
         total_community_space_heating = households_heating*avg_household_space_heating_gal_year,
         total_community_water_heating = households_heating*avg_household_water_heating_gal_year,
         total_comunity_heating_oil = households_heating*total_avg_household_heat_oil_use_gal_year)

final_heating_model_output <- tibble(
  supercategory = 'stationary_energy', 
  subcategory = 'residential_buildings',
  gpc_ref = "I.1.1", 
  scope = 1, 
  activity = "dist_oil", 
  entity = "community", 
  amount=heating_model$total_comunity_heating_oil, 
  units="gal(US)/year", 
  input_year = heating_model$input_year
)


# I need to join the appropriate emissions factors to calculate MTCO2e 
stationary_efs <- activity_emissions_key %>% 
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = 'emissions_factor') %>%
  select(activity, total_co2e_ef, input_year)

# Putting the three items together
stationary_final_output <- bind_rows(stationary_hardcoded, trans_emissions_final, final_heating_model_output) %>%
  left_join(stationary_efs, by = c('activity', 'input_year')) %>%
  mutate(total_mtco2e = amount*total_co2e_ef) %>%
  filter(!is.na(total_mtco2e))

stationary_final_output %>% group_by(input_year) %>% summarize(total_co2e = sum(total_mtco2e))

                                                               