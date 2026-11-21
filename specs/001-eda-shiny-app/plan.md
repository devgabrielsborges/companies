# Implementation Plan: EDA e Aplicativo Interativo Shiny (`001-eda-shiny-app`)

**Feature Branch**: `001-eda-shiny-app`
**Spec**: [spec.md](file:///home/bg/dev/studies/companies/specs/001-eda-shiny-app/spec.md)
**Tech Stack**: R 4.6.2, `shiny`, `bslib`, `plotly`, `DT`, `dplyr`, `ggplot2`, `readr`, `stringr`, `forcats`, `scales`, `testthat`, `lintr`, `rsconnect`, Quarto CLI.

## Architecture

Camada compartilhada (*single source of truth*) em `R/` alimentando simultaneamente o relatório Quarto (`docs/relatorio_eda.qmd`) e o aplicativo Shiny modular de 10 abas (`app.R` + `R/mod_tab_01.R`..`R/mod_tab_10.R`), com dados pré-processados em `data/processed/companies_prep.rds`.

## Directory Structure

- `data/raw/*.csv` — 4 arquivos brutos (141.332 empresas + 3 tabelas auxiliares)
- `data/processed/companies_prep.rds` — cache pré-processado
- `R/01_data_prep.R` — ingestão, validação de integridade e engenharia de atributos
- `R/02_stats_engine.R` — KPIs, quantis, Gini/Lorenz, Qui-quadrado/V de Cramér, Kruskal-Wallis/pós-hoc
- `R/03_plot_helpers.R` — paleta, formatadores BRL/PT-BR e helpers `plotly`/`DT`
- `R/mod_tab_01.R` .. `R/mod_tab_10.R` — 10 módulos Shiny independentes
- `app.R` & `www/custom.css` — aplicação `bslib::page_navbar()`
- `docs/relatorio_eda.qmd` & `docs/relatorio_eda.html` — relatório Quarto integrado
- `tests/testthat/` — suíte automatizada (`test_data_prep.R`, `test_stats_engine.R`, `test_shiny_smoke.R`)
