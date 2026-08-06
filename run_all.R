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
           supercategory == "agriculture_forestry_other_land_use" ~ "AFOLU",
           supercategory == "waste" ~ "Waste"
         )
  )

write_csv(ghg_emissions, "ghg_emissions.csv")
write_csv(mei_final, "mei_emissions.csv")
rm(list = setdiff(ls(), c("ghg_emissions", "mei_final")))