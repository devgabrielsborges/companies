# Companies — Análise Exploratória de Dados e Aplicativo Shiny

Análise Exploratória de Dados (EDA) completa sobre **141.332 empresas** (`data/raw/companies.csv`) e tabelas auxiliares (`legal_nature.csv`, `qualifications.csv`, `size.csv`), integrada a um **relatório Quarto** e a um **aplicativo Shiny modular de 10 abas**.

- **Aplicativo Online (`shinyapps.io`)**: https://gabrielsborges.shinyapps.io/companies-eda/
- **Relatório Analítico**: [docs/relatorio_eda.html](docs/relatorio_eda.html) (gerado a partir de [docs/relatorio_eda.qmd](docs/relatorio_eda.qmd))

## Arquitetura do Projeto

Toda a lógica de preparação e estatística reside em módulos compartilhados em `R/` (*single source of truth*), garantindo consistência numérica absoluta entre o relatório Quarto e as 10 abas do aplicativo Shiny:

```text
data/raw/*.csv                  # Dados brutos (141.332 empresas + 3 tabelas auxiliares)
data/processed/companies_prep.rds # Cache pré-processado para inicialização < 5s
R/01_data_prep.R                # Ingestão, validação de integridade e engenharia de atributos
R/02_stats_engine.R             # Motor estatístico (KPIs, quantis, Gini/Lorenz, Kruskal-Wallis, Qui²)
R/03_plot_helpers.R             # Paleta, formatadores BRL/PT-BR e helpers plotly/DT
R/mod_tab_01.R .. mod_tab_10.R  # 10 módulos Shiny independentes (gráfico + tabela + seletores)
app.R                           # Ponto de entrada Shiny (bslib theme)
docs/relatorio_eda.qmd          # Relatório Quarto integrado
tests/testthat/                 # Testes unitários e smoke tests Shiny
```

## As 10 Abas do Aplicativo Shiny

1. **Panorama Geral**: KPIs executivos e composição por porte (`company_size`).
2. **Capital Social**: Distribuição univariada com escala `log10`/linear, ECDF e tabela de quantis P1–P99.9.
3. **Porte Empresarial**: Violin + Boxplot comparativo e estatísticas estratificadas.
4. **Natureza Jurídica**: Ranking interativo das 22 naturezas jurídicas presentes (de 91 possíveis).
5. **Qualificação Sócios**: Perfil das 13 qualificações observadas (de 68 possíveis) e porte modal.
6. **Associações**: Mapa de calor de resíduos padronizados de Pearson, teste $\chi^2$ e V de Cramér.
7. **Concentração & Outliers**: Curva de Lorenz, índice de Gini, participação Top 1% e tabela de outliers.
8. **Nomenclatura**: Sufixos societários (`LTDA`, `S/A`, `EIRELI`, etc.) e termos frequentes em `company_name`.
9. **Testes Estatísticos**: Kruskal-Wallis ($\epsilon^2$) e comparações pareadas pós-hoc (Holm/Bonferroni/BH).
10. **Explorador & Relatório**: Busca granular em `DT` server-side, auditoria de domínio e exportação CSV.

## Como Executar Localmente

### Pré-requisitos
- **R >= 4.2** (testado em R 4.6.2) com pacotes: `shiny`, `bslib`, `dplyr`, `ggplot2`, `plotly`, `DT`, `readr`, `stringr`, `forcats`, `scales`, `testthat`, `lintr`.
- **Quarto CLI** (para compilar `docs/relatorio_eda.qmd`).

### Comandos

```bash
# 1. Executar testes automatizados
Rscript -e "testthat::test_dir('tests/testthat', stop_on_failure = TRUE)"

# 2. Verificar estilo de código R
Rscript -e "lintr::lint_dir('R')"

# 3. Renderizar relatório integrado
quarto render docs/relatorio_eda.qmd

# 4. Iniciar aplicativo Shiny localmente
Rscript -e "shiny::runApp('.', port = 3838, launch.browser = TRUE)"
```

## Publicação no `shinyapps.io`

Após configurar sua conta e token via `rsconnect::setAccountInfo(...)`:

```r
rsconnect::deployApp(
  appFiles = c("app.R", "R", "www", "data/processed/companies_prep.rds"),
  appName = "companies-eda"
)
```
