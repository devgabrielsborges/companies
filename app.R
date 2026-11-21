# ==============================================================================
# app.R — Aplicativo Shiny Interativo: Análise Exploratória de Empresas
# ==============================================================================

library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(readr)
library(stringr)
library(forcats)
library(scales)

source(file.path("R", "01_data_prep.R"))
source(file.path("R", "02_stats_engine.R"))
source(file.path("R", "03_plot_helpers.R"))

for (mod_file in sort(list.files("R", pattern = "^mod_tab_.*\\.R$", full.names = TRUE))) {
  source(mod_file)
}

# Carrega uma única vez no escopo global para garantir < 5s de inicialização
# e compartilhar memória entre sessões no shinyapps.io.
app_data <- get_prepared_data()
companies_df <- app_data$companies
domain_audit_df <- app_data$domain_audit

size_choices <- levels(companies_df$company_size)
legal_choices <- levels(companies_df$legal_nature)

app_theme <- bslib::bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#1B4965",
  secondary = "#5FA8D3",
  base_font = bslib::font_google("Inter"),
  heading_font = bslib::font_google("Inter")
)

ui <- bslib::page_navbar(
  title = "Panorama Empresarial — EDA",
  theme = app_theme,
  fillable = FALSE,
  header = shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  bslib::nav_panel("1. Panorama Geral", mod_tab_01_ui("tab01", size_choices)),
  bslib::nav_panel("2. Capital Social", mod_tab_02_ui("tab02")),
  bslib::nav_panel("3. Porte Empresarial", mod_tab_03_ui("tab03", size_choices)),
  bslib::nav_panel("4. Natureza Jurídica", mod_tab_04_ui("tab04", size_choices)),
  bslib::nav_panel("5. Qualificação Sócios", mod_tab_05_ui("tab05", legal_choices)),
  bslib::nav_panel("6. Associações", mod_tab_06_ui("tab06")),
  bslib::nav_panel("7. Concentração & Outliers", mod_tab_07_ui("tab07", size_choices)),
  bslib::nav_panel("8. Nomenclatura", mod_tab_08_ui("tab08", size_choices)),
  bslib::nav_panel("9. Testes Estatísticos", mod_tab_09_ui("tab09")),
  bslib::nav_panel("10. Explorador & Relatório", mod_tab_10_ui("tab10", size_choices, legal_choices))
)

server <- function(input, output, session) {
  mod_tab_01_server("tab01", companies_df)
  mod_tab_02_server("tab02", companies_df)
  mod_tab_03_server("tab03", companies_df)
  mod_tab_04_server("tab04", companies_df)
  mod_tab_05_server("tab05", companies_df)
  mod_tab_06_server("tab06", companies_df)
  mod_tab_07_server("tab07", companies_df)
  mod_tab_08_server("tab08", companies_df)
  mod_tab_09_server("tab09", companies_df)
  mod_tab_10_server("tab10", companies_df, domain_audit_df)
}

shiny::shinyApp(ui = ui, server = server)
