# ==============================================================================
# test_data_prep.R — Testes do pipeline de ingestão e preparação de dados
# ==============================================================================

library(testthat)

source(file.path("..", "..", "R", "01_data_prep.R"))

test_that("load_raw_data e prepare_companies_data preservam 141.332 registros sem NA", {
  raw_list <- load_raw_data(file.path("..", "..", "data", "raw"))
  expect_equal(nrow(raw_list$companies), 141332L)
  expect_true(validate_raw_data(raw_list))

  prep <- prepare_companies_data(raw_list)
  df <- prep$companies

  expect_equal(nrow(df), 141332L)
  expect_false(anyNA(df))
  expect_true(is.ordered(df$company_size))
  expect_equal(levels(df$company_size), c("micro-enterprise", "small-enterprise", "other"))
  expect_equal(nrow(prep$domain_audit), 5L)
})

test_that("extract_legal_suffix identifica sufixos principais corretamente", {
  res <- extract_legal_suffix(c("EMPRESA X LTDA", "BANCO Y S/A", "JOAO EIRELI", "PADARIA DO SOL"))
  expect_equal(as.character(res), c("LTDA / Limitada", "S/A", "EIRELI", "Outros / Sem sufixo"))
})
