library(tidyverse)
library(scales)
library(gt)
library(plotly)

theme_set(theme_minimal(base_family = "Georgia"))
theme_update(plot.title = element_text(hjust = 0.5))
current_year  <- 2025
baseline_year <- 2016
amherst_colors <- c("#8B2635", "#2E7D8C", "#5A7A5E", "#C9A040", "#5B6F7E", "#B08050")
scale_fill_amherst <- function(...) scale_fill_manual(values = amherst_colors, ...)
scale_color_amherst <- function(...) scale_color_manual(values = amherst_colors, ...)
