library(tidyverse)
library(Microsoft365R)
library(readxl)

# connecting to Onedrive and reading inputs
od <- get_business_onedrive()
item <- od$get_item("2026_GHG_update/livestock_agriculture_inputs.xlsx")
tmp <- tempfile(fileext = ".xlsx")
item$download(dest = tmp)

# reading input sheets
acreage_scaling <- read_xlsx(tmp, sheet = "acreage_scaling")
hampshire_livestock <- read_xlsx(tmp, sheet = "hampshire_livestock")
fertilization <- read_xlsx(tmp, sheet = "fertilization_pcts")

# calculating the percentage of Hampshire County (agricultural) acreage that is in Amherst
acreage_scaling <- acreage_scaling %>% 
  mutate(scaling_factor = amherst_acreage/hampshire_acreage)

# applying above percentage to Hampshire County livestock headcounts
amherst_headcounts <- hampshire_livestock %>%
  left_join(select(acreage_scaling, input_year, scaling_factor), by = 'input_year') %>%
  mutate(amherst_headcount = headcount*scaling_factor)

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


