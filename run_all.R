library(tidyverse)
library(Microsoft365R)
library(readxl)

od <- get_business_onedrive()

source("stationary.R")
source("waste.R")
source("transportation.R")
source("agriculture.R")

ghg_emissions <- bind_rows(
  stationary_final_output,
  waste_final_output,
  transportation_final_output,
  afolu_final_output
)

rm(list = setdiff(ls(), "ghg_emissions"))
write_csv(ghg_emissions, "ghg_emissions.csv")