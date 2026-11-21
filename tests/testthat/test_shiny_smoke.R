# ==============================================================================
# test_shiny_smoke.R — Smoke tests dos módulos Shiny
# ==============================================================================

library(testthat)
library(shiny)

source(file.path("..", "..", "R", "01_data_prep.R"))
source(file.path("..", "..", "R", "02_stats_engine.R"))
source(file.path("..", "..", "R", "03_plot_helpers.R"))
source(file.path("..", "..", "R", "mod_tab_01.R"))
source(file.path("..", "..", "R", "mod_tab_07.R"))
source(file.path("..", "..", "R", "mod_tab_09.R"))

test_that("módulos principais respondem corretamente via shiny::testServer", {
  prep <- get_prepared_data(
    rds_path = file.path("..", "..", "data", "processed", "companies_prep.rds"),
    raw_dir = file.path("..", "..", "data", "raw")
  )
  df <- prep$companies

  shiny::testServer(mod_tab_01_server, args = list(companies_df = df), {
    session$setInputs(sizes = c("micro-enterprise", "small-enterprise"), metric_mode = "pct")
    expect_true(grepl("98\\.812", output$kpi_n))
  })

  shiny::testServer(mod_tab_07_server, args = list(companies_df = df), {
    session$setInputs(scope_size = "ALL", outlier_rule = "tukey_log", top_outliers_n = 15)
    expect_true(as.numeric(output$kpi_gini) > 0.9)
  })

  shiny::testServer(mod_tab_09_server, args = list(companies_df = df), {
    session$setInputs(group_factor = "company_size", p_adjust = "holm", alpha = "0.05")
    expect_true(!is.null(output$omnibus_banner))
  })
})
