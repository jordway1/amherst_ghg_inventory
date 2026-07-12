library(tidyverse)
library(Microsoft365R)
library(readxl)

# connecting to Onedrive and reading waste inputs
if (!exists("od")) od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/waste_model_inputs.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)

item2 <- od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")
tmp2 <- tempfile(fileext = ".xlsx")
item2$download(dest = tmp2)

# reading sheets
solid_waste_inputs <- read_xlsx(tmp, sheet = "solid_waste_inputs")
solid_waste_composition <- read_xlsx(tmp, sheet = "solid_waste_composition") %>% select(-units, -source)
waste_method_composition <- read_xlsx(tmp, sheet = "waste_method_composition")
recycling_composition <- read_xlsx(tmp, sheet = "recycling_composition")
organic_waste_composition <- read_xlsx(tmp, sheet = "organic_waste_composition")
umass_disposal_methods <- read_xlsx(tmp, sheet = "umass_disposal_methods")

activity_emissions_key <- read_xlsx(tmp2, sheet = "activity_emissions_key") 
emissions_factors <- read_xlsx(tmp2, sheet = "emissions_factors")

wastewater_inputs <- read_xlsx(tmp, sheet = "wastewater_inputs")
wastewater_chemicals <- read_xlsx(tmp, sheet = "wastewater_chemicals")

# I'm initializing the data table here. I'll join the data from the input sheets and make calculations from here. 
# Hampshire college doesn't exist anymore, so that needs to be updated in future iterations
input_year <- c(2016, 2022)
entity <- c("community", "umass", "amherst_college", "hampshire_college")
waste_type <- c("paper", "plastic", "food_waste", "yard_waste", "metal", "glass", "construction_demo", "haz_waste", "electronics", "other_waste")
disposal_method <- c("recycle", "open_dump", "landfill", "compost", "incineration", "open_burning")

# this is a little complicated - it's based on Taylor's model in the "Wastewater Acitivy" sheets, which is based on something
# published in 2012 that there's no longer access to. ultimately, we're getting to the percent of total entity waste for each cross section
disposal_methods <- crossing(input_year, entity, waste_type, disposal_method) %>% 
  left_join(solid_waste_composition, by = c('input_year', 'entity', 'waste_type')) %>% 
  left_join(organic_waste_composition, by = c('input_year', 'entity', 'waste_type' = 'organic_waste_subtype')) %>%
  left_join(waste_method_composition, by = c('input_year', 'entity', 'disposal_method')) %>%
  left_join(recycling_composition, by = c('input_year', 'entity', 'waste_type')) %>%
  mutate(solid_waste_pct = case_when(
     disposal_method == "recycle" ~ total_recycling_pct * disposal_method_pct,
     disposal_method %in% c("landfill", "incineration") ~ total_waste_pct * disposal_method_pct,
     disposal_method == "compost" ~ organic_waste_pct * disposal_method_pct
   )) %>%
  select(input_year, entity, waste_type, disposal_method, percentage = solid_waste_pct) %>%
  filter(!is.na(percentage)) %>%
  bind_rows(umass_disposal_methods) %>% # umass provides their own waste decompositions, so this part has to be done separately and added on here
  filter(percentage>0)

# calculating community total waste in tonnes, derived from population and per capita daily lb estimation, see "Waste Activity Details" sheets
solid_waste_inputs <- solid_waste_inputs %>%
  mutate(total_annual_tonnes = population*per_capita_rate_daily_lbs*365/lbs_per_tonne,
         community_tonnes = total_annual_tonnes - umass_tonnes - amherst_college_tonnes - hampshire_college_tonnes)

# restructuring above so I can join it easily on to the disposal_methods sheet
tonnage_key <- solid_waste_inputs %>% 
  select(input_year, community_tonnes, umass_tonnes, amherst_college_tonnes, hampshire_college_tonnes) %>% 
  pivot_longer(cols = community_tonnes:hampshire_college_tonnes, names_to = "entity", values_to="total_tonnes") %>%
  mutate(entity = str_remove(entity, pattern = "_tonnes"))

# joining above table, calculating, formatting
solid_waste_output <- disposal_methods %>%
  left_join(tonnage_key, by = c("input_year", "entity")) %>%
  mutate(waste_tonnes = percentage*total_tonnes) %>%
  group_by(input_year, entity, disposal_method) %>%
  summarize(waste_tonnes = sum(waste_tonnes), .groups="drop") %>%
  # coercing into standard structure. note that recycling isn't counted toward emissions
  mutate(supercategory = "waste", 
         subcategory = case_when(
           disposal_method == "landfill" ~ "solid_waste_disposal",
           disposal_method == "compost" ~ "biological_treatment_of_waste",
           disposal_method == "incineration" ~ "incineration_and_open_burning"
         ),
         gpc_ref = case_when(
           disposal_method == "landfill" ~ "III.1.2",
           disposal_method == "compost" ~ "III.2.2",
           disposal_method == "incineration" ~ "III.3.2"
         ),
         unit = "tonnes",
         scope = as.integer(str_extract(gpc_ref, "\\d$"))) %>%
  rename(activity = disposal_method, amount = waste_tonnes) %>%
  left_join(activity_emissions_key, by = c('activity', 'input_year')) %>%
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = 'emissions_factor') %>%
  mutate(total_mtco2e = total_co2e_ef*amount) %>%
  select(supercategory, subcategory, gpc_ref, scope, activity, entity, amount, units = unit, input_year, total_co2e_ef, total_mtco2e)

# waste water 
liters_per_gallon <- 3.79

bod_key <- wastewater_chemicals %>% 
  group_by(input_year) %>%
  summarize(avg_influent_bod = mean(influent_bod_mg_l),
            avg_effluent_bod = mean(effluent_bod_mg_l))


wastewater_output <- wastewater_inputs %>% 
  group_by(input_year, entity) %>% 
  summarize(wastewater_gallons=sum(wastewater_gallons), .groups = "drop") %>%
  left_join(bod_key, by = 'input_year') %>%
  mutate(total_annual_bod_kg = wastewater_gallons*liters_per_gallon*avg_effluent_bod/1000000,
         supercategory = "waste",
         subcategory = "wastewater_treatment_and_discharge",
         gpc_ref = "III.4.1",
         scope = 1,
         activity = "wastewater_bod",
         amount = total_annual_bod_kg,
         units = "kg"
         ) %>%
  select(-c(wastewater_gallons, avg_influent_bod, avg_effluent_bod, total_annual_bod_kg)) %>%
  left_join(activity_emissions_key, by = c('activity', 'input_year')) %>%
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = 'emissions_factor') %>%
  mutate(total_mtco2e = total_co2e_ef*amount) %>%
  select(-emissions_factor)

# binding together
waste_final_output <- bind_rows(solid_waste_output, wastewater_output)



