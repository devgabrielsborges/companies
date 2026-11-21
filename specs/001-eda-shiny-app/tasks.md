---
description: "Task list for EDA e Aplicativo Interativo Shiny (001-eda-shiny-app)"
---

# Tasks: EDA e Aplicativo Interativo Shiny (`001-eda-shiny-app`)

**Input**: Design documents from `/specs/001-eda-shiny-app/`
**Prerequisites**: `plan.md`, `spec.md`, `.specify/memory/constitution.md`

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Configure R/Shiny/Quarto ignore rules in `.gitignore`
- [x] T002 [P] Configure R style linting rules in `.lintr`
- [x] T003 [P] Install required R packages (`shiny`, `plotly`, `DT`, `testthat`, `rsconnect`) and verify Quarto CLI

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared data pipeline, statistical engine (*single source of truth*), and visual helpers required by both the Shiny app and Quarto report.

- [x] T004 Implement raw CSV ingestion, referential validation, and feature engineering in `R/01_data_prep.R`
- [x] T005 [P] Implement shared statistical engine (KPIs, quantiles, Gini/Lorenz, Chi-squared, Kruskal-Wallis/pairwise) in `R/02_stats_engine.R`
- [x] T006 [P] Implement institutional color palette, BRL/PT-BR formatters, and `plotly`/`DT` helpers in `R/03_plot_helpers.R`
- [x] T007 Generate pre-processed cache artifact in `data/processed/companies_prep.rds`

**Checkpoint**: Foundation ready — Shiny modules, Quarto report, and tests can proceed in parallel.

---

## Phase 3: User Story 1 - Aplicativo Shiny Modular com 10 Abas (Priority: P1) 🎯 MVP

**Goal**: Entregar aplicativo Shiny funcional e esteticamente coeso com 10 abas distintas, cada uma contendo >= 1 gráfico interativo, >= 1 tabela e seletores próprios.

**Independent Test**: Executar `shiny::runApp('.', port = 3838)` (HTTP 200) e validar reatividade dos módulos via `shiny::testServer()` em `tests/testthat/test_shiny_smoke.R`.

- [x] T008 [P] [US1] Create custom institutional styling in `www/custom.css`
- [x] T009 [P] [US1] Implement Tab 1 (Panorama Geral) module in `R/mod_tab_01.R`
- [x] T010 [P] [US1] Implement Tab 2 (Distribuição de Capital) module in `R/mod_tab_02.R`
- [x] T011 [P] [US1] Implement Tab 3 (Comparação por Porte) module in `R/mod_tab_03.R`
- [x] T012 [P] [US1] Implement Tab 4 (Natureza Jurídica) module in `R/mod_tab_04.R`
- [x] T013 [P] [US1] Implement Tab 5 (Qualificação dos Sócios) module in `R/mod_tab_05.R`
- [x] T014 [P] [US1] Implement Tab 6 (Associações Categóricas) module in `R/mod_tab_06.R`
- [x] T015 [P] [US1] Implement Tab 7 (Concentração e Outliers) module in `R/mod_tab_07.R`
- [x] T016 [P] [US1] Implement Tab 8 (Padrões de Nomenclatura) module in `R/mod_tab_08.R`
- [x] T017 [P] [US1] Implement Tab 9 (Testes Estatísticos) module in `R/mod_tab_09.R`
- [x] T018 [P] [US1] Implement Tab 10 (Explorador e Relatório) module in `R/mod_tab_10.R`
- [x] T019 [US1] Assemble 10-tab `bslib::page_navbar()` application in `app.R`

**Checkpoint**: All 10 Shiny tabs operational and passing HTTP 200 smoke test.

---

## Phase 4: User Story 2 - Relatório Analítico Quarto Integrado (Priority: P2)

**Goal**: Produzir relatório Quarto HTML autocontido refletindo exatamente os mesmos resultados do motor estatístico compartilhado.

**Independent Test**: Executar `quarto render docs/relatorio_eda.qmd` sem erros e conferir métricas contra `R/02_stats_engine.R`.

- [x] T020 [US2] Author integrated Quarto EDA report consuming `R/01_data_prep.R` and `R/02_stats_engine.R` in `docs/relatorio_eda.qmd`
- [x] T021 [US2] Render self-contained HTML report to `docs/relatorio_eda.html`

**Checkpoint**: Report renders cleanly and matches Shiny app metrics.

---

## Phase 5: User Story 3 - Qualidade, Testes Automatizados e Fluxo GitHub (Priority: P2)

**Goal**: Garantir cobertura de testes `testthat`, conformidade de estilo e histórico disciplinado no GitHub (branches, commits atômicos com staging explícito e PR).

**Independent Test**: Executar `Rscript -e "testthat::test_dir('tests/testthat', stop_on_failure = TRUE)"` com 0 falhas.

- [x] T022 [P] [US3] Add data preparation unit tests in `tests/testthat/test_data_prep.R`
- [x] T023 [P] [US3] Add statistical engine unit tests in `tests/testthat/test_stats_engine.R`
- [x] T024 [P] [US3] Add Shiny module server smoke tests in `tests/testthat/test_shiny_smoke.R`
- [x] T025 [US3] Push feature branch `001-eda-shiny-app` with atomic commits and open PR #1 on GitHub

---

## Phase 6: Polish, Online Deploy & Final Release

**Purpose**: Publicação online no `shinyapps.io`, atualização da URL pública e merge do Pull Request.

- [x] T026 Configure `rsconnect::setAccountInfo()` credentials and deploy bundle (`app.R`, `R/`, `www/`, `data/processed/companies_prep.rds`) to `shinyapps.io`
- [x] T027 Update public `shinyapps.io` URL in `README.md` after deploy verification
- [x] T028 Commit `specs/001-eda-shiny-app/plan.md`, `specs/001-eda-shiny-app/tasks.md`, and `README.md` update via explicit `git add <file>` and merge PR #1 into `main`

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 2 (Foundational)** → **Phases 3, 4, 5** (podem executar em paralelo após Phase 2) → **Phase 6 (Deploy & Release)**.
- Dentro da Phase 3, `T009`–`T018` são 100% paralelizáveis por estarem isoladas em módulos `R/mod_tab_XX.R` distintos.

## Implementation Strategy

- **MVP First**: Phase 1 + Phase 2 + Phase 3 (`app.R` com 10 abas) entregam o aplicativo interativo completo.
- **Incremental Delivery**: Phase 4 (relatório Quarto), Phase 5 (testes e PR) e Phase 6 (deploy `shinyapps.io` e merge).
