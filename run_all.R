library(tidyverse)
library(Microsoft365R)
library(readxl)

od <- get_business_onedrive()

source("stationary.R")
source("waste.R")
source("transportation.R")
source("agriculture.R")
source("mei.R")

ghg_emissions <- bind_rows(
  stationary_final_output,
  waste_final_output,
  transportation_final_output,
  afolu_final_output
) %>%
  mutate(fiscal_year = factor(str_c("FY ", as.character(input_year))),
         supercategory = case_when(
           supercategory == "stationary_energy" ~ "Stationary Energy",
           supercategory == "transportation" ~ "Transportation",
           .default = supercategory
         )
  )

write_csv(ghg_emissions, "ghg_emissions.csv")
write_csv(mei_final, "mei_emissions.csv")
rm(list = setdiff(ls(), c("ghg_emissions", "mei_final")))

# ghg_emissions %>% 
#   filter(entity == "municipal") %>% 
#   group_by(input_year, activity, total_co2e_ef) %>% 
#   summarize(total = sum(total_mtco2e, na.rm = TRUE))
# 
# mei_final %>%
#   group_by(fiscal_year, account_fuel, emission_mtco2e_factor) %>%
#   summarize(total = sum(emission_mtco2e))
# 
# 
# ghg_emissions %>% 
#   filter(entity == "municipal", str_detect(activity, "_loss")) %>% 
#   group_by(input_year) %>% 
#   summarize(total = sum(total_mtco2e, na.rm = TRUE))


