# Feature Specification: EDA e Aplicativo Interativo Shiny — Análise de Empresas

**Created**: 2026-11-21
**Status**: Draft
**Author**: devgabrielsborges
**Spec ID**: COMPANIES-001
**Feature Branch**: `001-eda-shiny-app`

## Clarifications

### Session 2026-11-21

- Q: Which format should be used for the integrated analytical report? → A: Quarto (`.qmd`) rendered to self-contained HTML.
- Q: Which hosting platform should be targeted for the live online deployment of the Shiny application? → A: `shinyapps.io` via `rsconnect` (requires user account/token at deploy time).
- Q: What language should be used for the Shiny interface, chart labels, and analytical report? → A: Portuguese (PT-BR) UI and report, keeping original English category values from `data/raw/` for traceability.

---

## 1. Problem Statement

Os dados brutos em [data/raw](file:///home/bg/dev/studies/companies/data/raw) reúnem **141.332 registros de empresas** (`companies.csv`) e três tabelas auxiliares de domínio (`legal_nature.csv`, `qualifications.csv`, `size.csv`), oriundos do conjunto TidyTuesday 2026-01-27. Atualmente, o repositório conta apenas com um script inicial de extração em [1_data_extraction.ipynb](file:///home/bg/dev/studies/companies/notebooks/1_data_extraction.ipynb) e um rascunho exploratório parcial em [2_eda.ipynb](file:///home/bg/dev/studies/companies/notebooks/2_eda.ipynb), sem uma análise estatística consolidada, sem relatório técnico estruturado e sem aplicação interativa publicada.

- **Quem é afetado?** Avaliadores, analistas de dados e usuários interessados em explorar a estrutura societária, porte, qualificação de responsáveis e distribuição de capital social das empresas brasileiras presentes na base.
- **Comportamento atual vs. desejado:** Atualmente existem apenas 2 gráficos exploratórios isolados em notebook Python, sem testes estatísticos, sem integração com relatório e sem interface web. O comportamento desejado é uma **Análise Exploratória de Dados (EDA) completa e reproduzível em R**, integrada a um **relatório analítico** e a um **aplicativo Shiny interativo com 10 abas temáticas**, publicado online (ex.: `shinyapps.io`) e versionado no GitHub segundo boas práticas de engenharia.
- **Por que isso importa agora?** A avaliação do projeto exige entrega funcional online, consistência estrita entre aplicativo e relatório, rigor estatístico, estética coerente, 10 abas completas (cada uma com gráfico, tabela e seletores próprios) e evidência de fluxo profissional no GitHub (branches, PRs e commits atômicos).

## 2. Research Context

A inspeção direta de [data/raw](file:///home/bg/dev/studies/companies/data/raw) e dos notebooks existentes fundamenta as escolhas metodológicas desta especificação:

| Fonte | Achado Principal | Relevância para a Especificação |
|-------|------------------|---------------------------------|
| `data/raw/companies.csv` | 141.332 linhas, 6 colunas (`company_id`, `company_name`, `legal_nature`, `owner_qualification`, `capital_stock`, `company_size`), 0 valores ausentes (`NA`). | Dispensa imputação de nulos, mas exige validação de domínio e tratamento de duplicidade nominal (`company_name`: 140.739 únicos para 141.332 `company_id`). |
| Perfil de `capital_stock` | Mínimo R$ 150.000,10; Q1 R$ 210.000; Mediana R$ 400.000; Q3 R$ 1.000.000; Média R$ 353.697.000; Máximo R$ 1,00e+12 (DP R$ 1,46e+10). | Assimetria extrema à direita (razão média/mediana ≈ 884×). Torna obrigatórios escala `log10`, estatísticas robustas (mediana, IQR, Gini) e testes não paramétricos (Kruskal-Wallis, Dunn, Spearman). |
| Tabelas auxiliares (`legal_nature.csv`, `qualifications.csv`, `size.csv`) | `legal_nature.csv` possui 91 códigos (22 presentes em `companies.csv`); `qualifications.csv` possui 68 códigos (13 presentes); `size.csv` possui 4 níveis (3 presentes: `micro-enterprise` 46,84%, `other` 30,09%, `small-enterprise` 23,07%; `not-informed` tem 0 registros). | Exige auditoria explícita de cobertura de domínio e agrupamento inteligente de cauda longa (ex.: LLC representa 84,40% das empresas). |
| [notebooks/1_data_extraction.ipynb](file:///home/bg/dev/studies/companies/notebooks/1_data_extraction.ipynb) | Base originada do TidyTuesday (`2026-01-27`) via `readr::read_csv`. | Define a linhagem dos dados e o contexto semântico (dados cadastrais empresariais). |
| Constituição do Projeto ([constitution.md](file:///home/bg/dev/studies/companies/.specify/memory/constitution.md)) | Exige criatividade, funcionalidade consistente, estética, integração relatório-app, boas práticas em R e fluxo GitHub (sem `git add .` / `git add -A`). | Governa toda a arquitetura modular em R, testes, tema visual e fluxo de entrega. |

## 3. Proposed Solution

### 3.1 Approach

Construir um pipeline analítico unificado em **R** onde uma camada compartilhada de preparação e estatística alimenta simultaneamente o **relatório analítico (Quarto / R Markdown)** e o **aplicativo Shiny modular (`bslib` + `plotly` + `DT`/`reactable`)**. Essa abordagem de *single source of truth* garante que todas as métricas, cortes, testes de hipótese e definições exibidas nas 10 abas do aplicativo reflitam exatamente os resultados apresentados no relatório.

Dada a assimetria severa de `capital_stock` e a natureza categórica das demais variáveis (`company_size`, `legal_nature`, `owner_qualification`), a metodologia estatística combina:
- **Estatísticas descritivas robustas**: mediana, intervalo interquartil (IQR), quantis extremos (P1–P99.9), índice de Gini e curva de Lorenz.
- **Transformações adaptativas**: suporte nativo a alternância entre escala `log10` e linear com controle de quantis.
- **Inferência não paramétrica e categórica**: Kruskal-Wallis ($\epsilon^2$ como tamanho de efeito), pós-hoc de Dunn com ajuste de p-valor (Holm/Bonferroni/BH), teste $\chi^2$ de independência com V de Cramér e resíduos padronizados de Pearson.

### 3.2 Alternatives Considered

| Alternativa | Prós | Contras | Motivo da Rejeição |
|-------------|------|---------|--------------------|
| Dash / Plotly em Python (usando `pyproject.toml` existente) | Dependências Python já listadas no `pyproject.toml`. | Requisito explícito de entregar o aplicativo em **Shiny** publicado (ex.: `shinyapps.io`) e seguir **boas práticas de R**. | Não atende ao requisito de stack Shiny em R nem à diretriz constitucional de boas práticas em R. |
| App Shiny monolítico em `app.R` único | Prototipagem rápida inicial. | Dificulta manutenção, testes unitários, legibilidade e revisão em PRs com 10 abas complexas. | Viola o Princípio V da Constituição (modularidade e organização de código). |
| Pré-computar apenas imagens estáticas (`ggplot2` PNG) | Baixo custo de CPU em runtime. | Perde interatividade de tooltips, zoom e resposta fluida aos seletores específicos de cada aba. | Reduz criatividade, usabilidade e experiência interativa exigidas. |

### 3.3 Technical Design

```text
data/raw/*.csv
   │
   ▼
R/01_data_prep.R (leitura, validação de schema, padronização de fatores, derivação de features)
   │
   ├──► R/02_stats_engine.R (descritivas robustas, Gini/Lorenz, Kruskal-Wallis, Dunn, Chi2/Cramér's V)
   │         │
   │         ├──► docs/relatorio_eda.qmd (Relatório técnico reproduzível com os achados)
   │         │
   │         └──► app.R + R/mod_tab_*.R (10 módulos Shiny independentes + tema bslib compartilhado)
   │                   │
   │                   └──► shinyapps.io (deploy público)
```

**Arquitetura das 10 Abas (Módulos Shiny)**:

| # | Aba | Foco Analítico | Seletores Específicos da Aba | Gráfico (>= 1) | Tabela (>= 1) |
|---|-----|----------------|------------------------------|----------------|---------------|
| 1 | **Panorama Geral** | Visão macro dos 141.332 registros, KPIs e composição por porte | Filtro de `company_size`; modo de exibição (contagem vs. %) | Barras horizontais / composição de porte e top naturezas | Sumário executivo geral (N, %, mediana, IQR, média, DP) |
| 2 | **Distribuição de Capital** | Assimetria extrema de `capital_stock` | Escala (`log10` vs. linear); tipo (histograma, densidade, ECDF); recorte quantílico (95%, 99%, 100%) | Histograma + densidade ou ECDF com marcadores de mediana/Q1/Q3 | Tabela completa de quantis (P1 a P99.9) e assimetria/curtose |
| 3 | **Comparação por Porte** | Diferenças de capital entre `micro-enterprise`, `small-enterprise` e `other` | Escala (`log10` vs. linear); visualização (violin+boxplot vs. boxplot); estatística destacada | Violin + Boxplot interativo por porte | Estatísticas descritivas estratificadas por `company_size` |
| 4 | **Natureza Jurídica** | Concentração societária (22 de 91 categorias) e perfil de capital | Top-N categorias (5–22); ordenação (frequência vs. capital mediano); filtro de porte | Lollipop/barras de frequência e capital mediano (com IQR) | Ranking de naturezas jurídicas (N, %, mediana, IQR, % acumulado) |
| 5 | **Qualificação dos Sócios** | Perfil dos responsáveis (13 de 68 qualificações) | Top-N qualificações (3–13); métrica (contagem vs. capital mediano); filtro de natureza jurídica | Dotplot/barras comparativas por qualificação | Sumário estatístico por `owner_qualification` e porte modal |
| 6 | **Associações Categóricas** | Dependência entre `company_size`, `legal_nature` e `owner_qualification` | Par de variáveis categóricas; corte Top-K + "Outros"; métrica (proporção linha/coluna vs. resíduo de Pearson) | Heatmap de resíduos padronizados / barras 100% empilhadas | Tabela de contingência + estatística $\chi^2$, p-valor e V de Cramér |
| 7 | **Concentração e Outliers** | Desigualdade de capital (Lorenz/Gini) e extremos acima do P99 | Escopo (geral, por porte ou por natureza); critério de outlier (Tukey 1.5×IQR em `log10` vs. P99/P99.9) | Curva de Lorenz interativa com valor de Gini anotado | Top outliers identificados + métricas de concentração (Gini, Top 1%, Top 10%) |
| 8 | **Padrões de Nomenclatura** | Mineração textual básica em `company_name` (sufixos `LTDA`, `SA`, homônimos, comprimento) | Filtro por sufixo/termo; Top-N termos (10–30); filtro de porte | Frequência de sufixos/termos e distribuição de tamanho de nome | Tabela de sufixos/termos e nomes duplicados com capital mediano |
| 9 | **Testes Estatísticos** | Rigor inferencial (Kruskal-Wallis, Dunn post-hoc, $\chi^2$) | Fator de agrupamento; ajuste de p-valor (Holm, Bonferroni, BH); nível $\alpha$ (0,01 / 0,05 / 0,10) | Gráfico de diferenças/intervalos ou $-\log_{10}(p_{adj})$ por par | Tabela de resultados dos testes (estatística, gl, p-bruto, p-ajustado, tamanho de efeito) |
| 10 | **Explorador e Relatório** | Consulta granular de empresas, auditoria de qualidade e sincronia com o relatório | Busca textual (`company_name`); faixa de `capital_stock`; filtros de porte, natureza e qualificação | Mini-distribuição comparativa (subconjunto filtrado vs. base global) | Tabela paginada (`DT`/`reactable`) com botão de download CSV e auditoria de domínio |

## 4. Requirements

### Functional Requirements

- [ ] **FR-1**: O sistema DEVE ingerir e validar os 4 arquivos em [data/raw](file:///home/bg/dev/studies/companies/data/raw) (`companies.csv`, `legal_nature.csv`, `qualifications.csv`, `size.csv`), verificando colunas esperadas, tipos e integridade antes de renderizar qualquer análise.
- [ ] **FR-2**: O aplicativo Shiny DEVE conter exatamente **10 abas temáticas distintas**, cobrindo panorama geral, distribuição univariada, comparação por porte, natureza jurídica, qualificação de sócios, associações categóricas, concentração/outliers, padrões textuais de nomes, testes estatísticos e explorador de dados.
- [ ] **FR-3**: Cada uma das 10 abas DEVE conter **ao menos 1 gráfico interativo**, **ao menos 1 tabela formatada** e **seletores de filtro/parametrização específicos da aba** que atualizem dinamicamente tanto o gráfico quanto a tabela correspondentes.
- [ ] **FR-4**: Todas as 10 abas DEVEM compartilhar um sistema visual unificado (`bslib` theme, paleta de cores consistente para `company_size` e categorias, tipografia legível e layout responsivo em cards).
- [ ] **FR-5**: Todos os cálculos estatísticos, quantis, índices de Gini, testes não paramétricos (Kruskal-Wallis, Dunn) e métricas categóricas ($\chi^2$, V de Cramér) DEVEM residir em módulo R compartilhado e produzir resultados idênticos entre o aplicativo Shiny e o relatório analítico.
- [ ] **FR-6**: A Aba 10 (Explorador) DEVE permitir filtrar registros combinados e exportar o subconjunto filtrado em CSV, além de exibir auditoria de cobertura frente às tabelas auxiliares (`legal_nature.csv`, `qualifications.csv`, `size.csv`).
- [ ] **FR-7**: O aplicativo DEVE ser empacotado e publicado online em serviço acessível publicamente (ex.: `shinyapps.io`), com URL funcional documentada no `README.md`.
- [ ] **FR-8**: O código-fonte completo (pipeline R, módulos Shiny, relatório e testes) DEVE estar versionado no GitHub usando branches dedicadas, Pull Requests e commits atômicos, sem uso de `git add .` ou `git add -A`.
- [ ] **FR-9**: Toda a interface do aplicativo Shiny, títulos/eixos de gráficos e o relatório Quarto DEVEM ser redigidos em Português (PT-BR), preservando os valores originais em inglês das categorias de `data/raw/` para rastreabilidade direta.

### Non-Functional Requirements

- [ ] **NFR-1 (Latência)**: A inicialização do aplicativo (carga de dados pré-processados/RDS ou CSV otimizado) DEVE ocorrer em `< 5 segundos`; a atualização reativa de gráficos e tabelas após mudança de seletor em qualquer aba DEVE ocorrer em `< 1,5 segundo` (p95).
- [ ] **NFR-2 (Consistência e Precisão)**: 100% dos valores numéricos exibidos nas tabelas e KPIs do Shiny DEVEM coincidir com os valores do relatório até a casa decimal exibida (tolerância `0` para contagens e `< 1e-6` para estatísticas contínuas).
- [ ] **NFR-3 (Escalabilidade em Memória)**: O aplicativo DEVE operar confortavelmente dentro do limite gratuito do `shinyapps.io` (1 GB RAM), utilizando objetos pré-agregados ou formatos eficientes (`qs`/`rds` ou `data.table`) para os 141.332 registros.
- [ ] **NFR-4 (Qualidade de Código R)**: O código R DEVE seguir guia de estilo consistente (`snake_case`, modularização em `R/`, funções com responsabilidade única, comentários explicando o *porquê*, ausência de caminhos absolutos locais e aprovação em linter `lintr`/testes `testthat`).
- [ ] **NFR-5 (Usabilidade e Estética)**: Nenhuma aba pode apresentar texto sobreposto, legendas cortadas, erros vermelhos de Shiny na interface em estados de filtro vazio (usar `validate(need(...))` com mensagens amigáveis).

## 5. Metrics & Evaluation

### Offline Metrics (Desenvolvimento e Qualidade)

| Métrica | Baseline | Target | Método de Medição |
|---------|----------|--------|-------------------|
| Cobertura de abas completas | 0 / 10 abas | 10 / 10 abas (cada uma com >= 1 gráfico, >= 1 tabela, >= 2 seletores) | Inspeção automatizada via `shinytest2` / checklist de UI |
| Divergência App vs. Relatório | N/A | 0 divergências numéricas | Testes `testthat` comparando saídas de `R/02_stats_engine.R` usadas no relatório e no app |
| Cobertura de testes unitários | 0% | >= 80% nas funções de preparação e motor estatístico (`R/`) | `testthat` + `covr` |
| Violações de estilo R (`lintr`) | Não medido | 0 erros críticos / 0 caminhos absolutos | Execução de `lintr::lint_dir()` |

### Online Metrics (Aplicativo Publicado)

| Métrica | Baseline | Target | Método de Medição |
|---------|----------|--------|-------------------|
| Disponibilidade da URL pública (`shinyapps.io`) | Indisponível | HTTP 200 contínuo e sessão ativa sem crash | Verificação HTTP + teste manual ponta a ponta nas 10 abas |
| Tempo de carregamento inicial | N/A | < 5s até renderização da Aba 1 | DevTools / logs do `shinyapps.io` |
| Tempo de resposta por interação | N/A | < 1,5s por alteração de filtro (p95) | Profiling com `profvis` / medição de reatividade |

### Guardrail Metrics

- **Integridade de Dados**: Total de empresas sem filtros ativos DEVE permanecer exatamente `141.332`, sem perda silenciosa de linhas durante joins com tabelas auxiliares.
- **Uso de Memória no Deploy**: Pico de memória RSS no `shinyapps.io` DEVE permanecer `< 750 MB` (margem de segurança abaixo do teto de 1 GB do plano gratuito).
- **Segurança no Versionamento**: 0 ocorrências de arquivos temporários, credenciais (`rsconnect/documents` tokens) ou caches commitados no repositório.

## 6. Data Requirements

- **Dados de Origem (`data/raw/`)**:
  - `companies.csv`: 141.332 registros, 6 colunas úteis (`company_id` inteiro único, `company_name` texto, `legal_nature` categórico com 22 níveis, `owner_qualification` categórico com 13 níveis, `capital_stock` numérico > 0, `company_size` categórico com 3 níveis).
  - `legal_nature.csv`: 91 definições de natureza jurídica (`id`, `legal_nature`).
  - `qualifications.csv`: 68 definições de qualificação de sócios (`id`, `owner_qualification`).
  - `size.csv`: 4 definições de porte (`id`, `company_size`).
- **Pipeline de Dados**:
  - Leitura explícita descartando a coluna de índice sem nome (`""`) gerada na exportação original.
  - Conversão de `company_size` em fator ordenado (`micro-enterprise` < `small-enterprise` < `other`).
  - Derivação de variáveis auxiliares: `log10_capital`, faixas de capital, sufixo societário extraído de `company_name`, flag de nome duplicado e indicador de outlier.
  - Serialização opcional de artefato pré-processado (`.rds`) para carregamento rápido no `shinyapps.io`.
- **Verificações de Qualidade de Dados**:
  - Asserção de unicidade de `company_id` (141.332 únicos).
  - Asserção de `capital_stock > 0` e ausência de `NA`/`NaN`/`Inf`.
  - Verificação de integridade referencial: 100% dos valores de `legal_nature`, `owner_qualification` e `company_size` em `companies.csv` devem existir nas respectivas tabelas auxiliares.

## 7. Risks & Mitigations

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Estouro de memória (1 GB) ou lentidão no `shinyapps.io` ao renderizar 141.332 pontos em gráficos interativos (`plotly`) | Alta | Alta | Renderizar gráficos agregados/densidade/amostragem estratificada para dispersões e usar `server = TRUE` no `DT` na Aba 10; pré-computar estatísticas pesadas no startup. |
| Divergência entre números do relatório e do aplicativo Shiny | Média | Alta | Centralizar toda a lógica de cálculo em `R/02_stats_engine.R` consumido tanto pelo relatório Quarto/Rmd quanto pelos módulos Shiny. |
| Erros em filtros combinados que retornam 0 linhas | Alta | Média | Aplicar `validate(need(nrow(df) > 0, ...))` em todos os `renderPlotly` e `renderDT`/`renderTable`. |
| Vazamento de credenciais do `rsconnect` / `shinyapps.io` no GitHub | Média | Alta | Garantir `.gitignore` cobrindo `.Renviron`, `rsconnect/` sensível e usar staging explícito (`git add <arquivo>`), nunca `git add .`. |
| Atraso ou falha na publicação no `shinyapps.io` por incompatibilidade de pacotes R | Média | Alta | Fixar dependências com `renv` e validar deploy incremental cedo (com estrutura mínima antes de completar todas as 10 abas). |

## 8. Dependencies

- [ ] Ambiente **R** (>= 4.2) com pacotes: `shiny`, `bslib`, `tidyverse` (`dplyr`, `ggplot2`, `readr`, `stringr`, `forcats`, `tidyr`), `plotly`, `DT` (ou `reactable`), `scales`, `ineq` (ou cálculo próprio validado de Gini/Lorenz), `rstatix` / `FSA` (Kruskal-Wallis e Dunn), `testthat`, `lintr`.
- [ ] Quarto CLI (`quarto`) para compilação do relatório analítico integrado em `docs/relatorio_eda.qmd` (HTML autocontido).
- [ ] Conta configurada no `shinyapps.io` (`rsconnect`) para publicação online.
- [ ] Repositório remoto no **GitHub** configurado para gestão de branches, PRs e entrega do código.

## 9. Rollout Plan

- **Fase 1 (Fundação de Dados, EDA e Relatório Base)**: Implementar `R/01_data_prep.R`, `R/02_stats_engine.R`, testes unitários `testthat` e rascunho do relatório EDA em `docs/`.
- **Fase 2 (Protótipo Shiny + Deploy Antecipado)**: Criar esqueleto modular (`app.R`, tema `bslib` e Abas 1–3), validar performance e realizar primeiro deploy de validação no `shinyapps.io`.
- **Fase 3 (Expansão Completa das 10 Abas e Sincronia Final)**: Implementar Abas 4–10 com seletores específicos, gráficos, tabelas e finalizar o relatório sincronizado com os achados.
- **Gatilho de Rollback / Bloqueio de Merge**: Qualquer PR que quebre testes `testthat`, introduza divergência numérica com o relatório, exceda 750 MB de RAM no app ou viole a regra de staging explícito no Git é bloqueado antes do merge.

## 10. Acceptance Criteria

- [ ] **AC-1**: O aplicativo Shiny possui **10 abas funcionais**, cada uma contendo pelo menos 1 gráfico interativo, 1 tabela informativa e seletores específicos funcionais.
- [ ] **AC-2**: O estilo visual (`bslib`, paleta, tipografia, cards) é coerente e responsivo em todas as 10 abas, sem erros de console ou falhas com filtros vazios.
- [ ] **AC-3**: Todos os principais resultados do aplicativo (totais, medianas, IQR, Gini, testes Kruskal-Wallis/Dunn/$\chi^2$) estão documentados e numericamente idênticos no relatório analítico.
- [ ] **AC-4**: O aplicativo está publicado e acessível publicamente online (ex.: `shinyapps.io`), com link verificado no `README.md`.
- [ ] **AC-5**: Todos os testes unitários (`testthat`) e verificações de estilo passam sem falhas.
- [ ] **AC-6**: O repositório no GitHub evidencia fluxo adequado de branches, Pull Requests e commits atômicos sem uso de `git add .` ou `git add -A`.

## 11. Open Questions

- [ ] Confirmar disponibilidade de conta e token `rsconnect` para `shinyapps.io` na etapa de deploy.
