library(tidyverse)
library(Microsoft365R)
library(readxl)

# connecting to Onedrive and reading inputs
od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/livestock_agriculture_inputs.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)

item2 <- od$get_item("2026_GHG_update/clean_in_the_sheets.xlsx")
tmp2 <- tempfile(fileext = ".xlsx")
item2$download(dest = tmp2)

# reading input sheets
acreage_scaling <- read_xlsx(tmp, sheet = "acreage_scaling")
hampshire_livestock <- read_xlsx(tmp, sheet = "hampshire_livestock")
fertilization <- read_xlsx(tmp, sheet = "fertilization_pcts")

activity_emissions_key <- read_xlsx(tmp2, sheet = "activity_emissions_key") 
emissions_factors <- read_xlsx(tmp2, sheet = "emissions_factors")

# calculating the percentage of Hampshire County (agricultural) acreage that is in Amherst
acreage_scaling <- acreage_scaling %>% 
  mutate(scaling_factor = amherst_acreage/hampshire_acreage)

# applying above percentage to Hampshire County livestock headcounts
amherst_headcounts <- hampshire_livestock %>%
  left_join(select(acreage_scaling, input_year, scaling_factor), by = 'input_year') %>%
  mutate(amherst_headcount = headcount*scaling_factor)

fermentation <- amherst_headcounts %>%
  mutate(activity = str_c(animal, "_enteric_fermentation"))
manure <- amherst_headcounts %>%
  mutate(activity = str_c(animal, "_manure"))

livestock_output <- bind_rows(fermentation, manure) %>%
  rename(amount = amherst_headcount) %>%
  left_join(activity_emissions_key, by = c('activity', 'input_year')) %>%
  left_join(select(emissions_factors, emissions_factor, total_co2e_ef), by = 'emissions_factor') %>%
  mutate(total_mtco2e = total_co2e_ef*amount,
         supercategory = "agriculture_forestry_other_land_use",
         subcategory = "livestock",
         gpc_ref = "V.1",
         scope = "1",
         entity = "community",
         units = "animals") %>%
  select(supercategory, subcategory, gpc_ref, scope, activity, entity, amount, units, input_year, total_co2e_ef, total_mtco2e)


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
# I suppose these are percentages of agricultural acreage that are fertilized by crop,
# this assumes an equal distribution of crops, which is faulty, but this is a tiny
# fraction of overall emissions anyway
fertilization_pcts <- fertilization %>%
  group_by(input_year) %>%
  summarize(fertilization_pct = mean(pct_fertilized),
            application_rate = mean(application_rate_lb_N_acre))

lb_per_kg <- 0.4536

total_fertilization <- acreage_scaling %>%
  select(input_year, amherst_acreage) %>%
  left_join(fertilization_pcts, by = 'input_year') %>%
  mutate(total_fertilization = amherst_acreage*fertilization_pct*application_rate*lb_per_kg) # final unit is kg/year


