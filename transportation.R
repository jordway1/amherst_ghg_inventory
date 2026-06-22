library(tidyverse)
library(Microsoft365R)
library(readxl)

# connecting to Onedrive and reading stationary inputs, trans loss factors
od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)

# reading the relevant input sheets
transportation_inputs <- read_xlsx(tmp, sheet = "transportation_inputs")
pvta_model_inputs <- read_xlsx(tmp, sheet = "pvta_model_inputs")
activity_emissions_key <- read_xlsx(tmp, sheet = "activity_emissions_key")
emissions_factors <- read_xlsx(tmp, sheet = "emissions_factors")

# this should probably be stored separately in a spreadsheet! it's a bit fragile in this state
activity_map <- tibble(activity = unique(transportation_inputs$activity),
                       activity_recoded = c("passenger_cars", "light_trucks", "motorcycles", "heavy_trucks",
                                            "other_vehicles", "gasoline", "diesel", "b100", "emission_sector_specific",
                                            "lpg"))

transportation_inputs_clean <- transportation_inputs %>%
  select(-c(input_type, data_quality, description_methods, quality_explanation, source)) %>%
  left_join(activity_map, by = 'activity')

transportation_hardcoded <- transportation_inputs_clean %>%
  select(supercategory, subcategory, gpc_ref, scope, activity=activity_recoded, description, amount, units, input_year)

# PVTA Model
regular_service_factor <- 8.5/12 # school year is ~8.5 months
irregular_service_factor <- (12-8.5)/12 # summer/winter schedule
irregular_service_pct <- 0.4 # estimated percentage of volume in off season schedule (not sure where Taylor got this)
weekdays <- 261
saturdays <- 52
sundays <- 52

# calculating fuel usage in gallons/year
pvta_model <- pvta_model_inputs %>% 
  mutate(
    fuel_usage = miles_per_route*(regular_service_factor*weekdays*avg_weekday_trips +
                                                      regular_service_factor*saturdays*avg_sat_trips +
                                                      regular_service_factor*sundays*avg_sun_trips +
                                                      irregular_service_pct * (irregular_service_factor*weekdays*avg_weekday_trips +
                                                                                 irregular_service_factor*saturdays*avg_sat_trips +
                                                                                 irregular_service_factor*sundays*avg_sun_trips))/avg_fuel_efficiency) %>%
  group_by(input_year) %>%
  summarize(total_fuel_usage = sum(fuel_usage))

# putting the PVTA data into the same format as the rest of the data, so I can bind the rows together
final_pvta_output <- tibble(
  supercategory = 'transportation', 
  subcategory = 'on_road_transportation',
  gpc_ref = "II.1.2", 
  scope = 2, 
  activity = "diesel", 
  description = "In-city bus transit fuel use", 
  amount=pvta_model$total_fuel_usage, 
  units="gallons/year", 
  input_year = pvta_model$input_year
)

# emissions factors
transportation_efs <- activity_emissions_key %>% 
  left_join(select(emissions_factors, emissions_factor, total_co2e), by = 'emissions_factor') %>%
  select(activity, total_co2e, input_year)

# joining the PVTA data with the other transportation data, and 
transportation_final_output <- bind_rows(transportation_hardcoded, final_pvta_output) %>%
  left_join(transportation_efs, by = c('activity', 'input_year')) %>%
  mutate(total_mtco2e = amount*total_co2e)

#transportation_final_output %>% group_by(input_year) %>% summarize(total_mtco2e_annual = sum(total_mtco2e, na.rm = TRUE))
