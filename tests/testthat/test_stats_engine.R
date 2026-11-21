# ==============================================================================
# test_stats_engine.R — Testes unitários do motor estatístico compartilhado
# ==============================================================================

library(testthat)

source(file.path("..", "..", "R", "01_data_prep.R"))
source(file.path("..", "..", "R", "02_stats_engine.R"))

test_that("compute_gini_and_lorenz retorna 0 para igualdade perfeita e > 0.9 para concentração extrema", {
  eq <- compute_gini_and_lorenz(rep(100, 1000))
  expect_equal(eq$gini, 0, tolerance = 1e-6)

  ineq <- compute_gini_and_lorenz(c(rep(1, 999), 1000000))
  expect_gt(ineq$gini, 0.95)
  expect_gt(ineq$top_1_pct_share, 99)
})

test_that("compute_overview_kpis e run_nonparametric_tests são consistentes com a base real", {
  prep <- get_prepared_data(
    rds_path = file.path("..", "..", "data", "processed", "companies_prep.rds"),
    raw_dir = file.path("..", "..", "data", "raw")
  )
  df <- prep$companies

  kpis <- compute_overview_kpis(df)
  expect_equal(kpis$n_companies, 141332L)
  expect_equal(kpis$median_capital, 400000)

  kw <- run_nonparametric_tests(df, "company_size", p_adjust_method = "holm")
  expect_equal(nrow(kw$omnibus), 1L)
  expect_lt(kw$omnibus$p_valor, 1e-4)
  expect_equal(nrow(kw$pairwise), 3L)

  assoc <- compute_contingency_analysis(df, "company_size", "legal_nature", top_k = 5L)
  expect_lt(assoc$p_value, 1e-4)
  expect_gt(assoc$cramers_v, 0)
})
