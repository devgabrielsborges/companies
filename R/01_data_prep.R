# ==============================================================================
# 01_data_prep.R
# Pipeline de ingestão, validação de integridade e engenharia de atributos
# para a base de empresas (data/raw/*.csv).
# ==============================================================================

#' Carrega os 4 arquivos CSV brutos do diretório especificado
#'
#' @param raw_dir Caminho relativo para o diretório de dados brutos.
#' @return Lista nomeada contendo companies, legal_nature, qualifications e size.
load_raw_data <- function(raw_dir = file.path("data", "raw")) {
  required_files <- c("companies.csv", "legal_nature.csv", "qualifications.csv", "size.csv")
  missing_files <- required_files[!file.exists(file.path(raw_dir, required_files))]

  if (length(missing_files) > 0L) {
    stop(
      sprintf("Arquivos ausentes em '%s': %s", raw_dir, paste(missing_files, collapse = ", ")),
      call. = FALSE
    )
  }

  # Os CSVs originais possuem uma primeira coluna de índice sem nome ("")
  # gerada pelo write.csv() do R; descartamos essa coluna na leitura.
  read_clean_csv <- function(filename, col_types) {
    readr::read_csv(
      file.path(raw_dir, filename),
      col_types = col_types,
      show_col_types = FALSE,
      name_repair = "unique_quiet"
    ) |>
      dplyr::select(-1)
  }

  list(
    companies = read_clean_csv(
      "companies.csv",
      readr::cols(
        company_id = readr::col_double(),
        company_name = readr::col_character(),
        legal_nature = readr::col_character(),
        owner_qualification = readr::col_character(),
        capital_stock = readr::col_double(),
        company_size = readr::col_character()
      )
    ),
    legal_nature = read_clean_csv(
      "legal_nature.csv",
      readr::cols(
        id = readr::col_integer(),
        legal_nature = readr::col_character()
      )
    ),
    qualifications = read_clean_csv(
      "qualifications.csv",
      readr::cols(
        id = readr::col_integer(),
        owner_qualification = readr::col_character()
      )
    ),
    size = read_clean_csv(
      "size.csv",
      readr::cols(
        id = readr::col_integer(),
        company_size = readr::col_character()
      )
    )
  )
}

#' Valida integridade estrutural e referencial dos dados brutos
#'
#' @param raw_list Lista retornada por load_raw_data().
#' @return TRUE invisivelmente se todas as asserções passarem; interrompe em erro.
validate_raw_data <- function(raw_list) {
  df <- raw_list$companies
  expected_cols <- c(
    "company_id", "company_name", "legal_nature",
    "owner_qualification", "capital_stock", "company_size"
  )

  if (!all(expected_cols %in% names(df))) {
    stop("Colunas obrigatórias ausentes em companies.csv.", call. = FALSE)
  }
  if (anyNA(df)) {
    stop("Valores ausentes (NA) detectados em companies.csv.", call. = FALSE)
  }
  if (dplyr::n_distinct(df$company_id) != nrow(df)) {
    stop("company_id não é único em companies.csv.", call. = FALSE)
  }
  if (any(!is.finite(df$capital_stock)) || any(df$capital_stock <= 0)) {
    stop("capital_stock contém valores não finitos ou <= 0.", call. = FALSE)
  }

  # Integridade referencial contra as tabelas auxiliares de domínio
  if (!all(df$legal_nature %in% raw_list$legal_nature$legal_nature)) {
    stop("Existem valores de legal_nature fora da tabela auxiliar.", call. = FALSE)
  }
  if (!all(df$owner_qualification %in% raw_list$qualifications$owner_qualification)) {
    stop("Existem valores de owner_qualification fora da tabela auxiliar.", call. = FALSE)
  }
  if (!all(df$company_size %in% raw_list$size$company_size)) {
    stop("Existem valores de company_size fora da tabela auxiliar.", call. = FALSE)
  }

  invisible(TRUE)
}

#' Extrai sufixo societário padronizado a partir da razão social
#'
#' @param company_name Vetor de caracteres com razões sociais.
#' @return Vetor de fatores ordenados com sufixos societários principais.
extract_legal_suffix <- function(company_name) {
  upper_name <- stringr::str_to_upper(stringr::str_squish(company_name))

  suffix <- dplyr::case_when(
    stringr::str_detect(upper_name, "\\bLTDA\\b|LIMITADA\\b") ~ "LTDA / Limitada",
    stringr::str_detect(upper_name, "\\bS/?A\\b|S\\.A\\.?$|SOCIEDADE ANONIMA") ~ "S/A",
    stringr::str_detect(upper_name, "\\bEIRELI\\b") ~ "EIRELI",
    stringr::str_detect(upper_name, "\\bSLU\\b|UNIPESSOAL\\b") ~ "Unipessoal / SLU",
    stringr::str_detect(upper_name, "\\bME\\b$") ~ "ME (sufixo)",
    stringr::str_detect(upper_name, "\\bEPP\\b$") ~ "EPP (sufixo)",
    TRUE ~ "Outros / Sem sufixo"
  )

  suffix_levels <- c(
    "LTDA / Limitada", "S/A", "Unipessoal / SLU", "EIRELI",
    "ME (sufixo)", "EPP (sufixo)", "Outros / Sem sufixo"
  )

  factor(suffix, levels = suffix_levels)
}

#' Prepara a base analítica completa e gera auditoria de cobertura de domínio
#'
#' @param raw_list Lista validada por validate_raw_data().
#' @return Lista com data.frame `companies`, tabela `domain_audit` e `lookup`.
prepare_companies_data <- function(raw_list) {
  validate_raw_data(raw_list)

  df <- raw_list$companies

  # Mantemos a ordem lógica de porte empresarial e preservamos os rótulos
  # originais em inglês para rastreabilidade direta com data/raw/.
  size_levels <- c("micro-enterprise", "small-enterprise", "other")

  log_cap <- log10(df$capital_stock)
  q1_log <- stats::quantile(log_cap, 0.25, names = FALSE)
  q3_log <- stats::quantile(log_cap, 0.75, names = FALSE)
  iqr_log <- q3_log - q1_log
  upper_tukey_log <- q3_log + 1.5 * iqr_log

  p99_cap <- stats::quantile(df$capital_stock, 0.99, names = FALSE)

  dup_names <- df$company_name[duplicated(df$company_name) | duplicated(df$company_name, fromLast = TRUE)]

  companies_clean <- df |>
    dplyr::mutate(
      company_size = factor(.data$company_size, levels = size_levels, ordered = TRUE),
      legal_nature = forcats::fct_infreq(factor(.data$legal_nature)),
      owner_qualification = forcats::fct_infreq(factor(.data$owner_qualification)),
      log10_capital = log_cap,
      name_length = nchar(.data$company_name),
      word_count = stringr::str_count(.data$company_name, "\\S+"),
      legal_suffix = extract_legal_suffix(.data$company_name),
      is_duplicate_name = .data$company_name %in% dup_names,
      is_outlier_log_iqr = log_cap > upper_tukey_log,
      is_outlier_p99 = .data$capital_stock > p99_cap
    )

  domain_audit <- tibble::tibble(
    entidade = c("Empresas (registros)", "Nomes únicos", "Portes (company_size)",
                 "Naturezas jurídicas (legal_nature)", "Qualificações (owner_qualification)"),
    total_auxiliar = c(
      NA_integer_,
      NA_integer_,
      nrow(raw_list$size),
      nrow(raw_list$legal_nature),
      nrow(raw_list$qualifications)
    ),
    presentes_na_base = c(
      nrow(companies_clean),
      dplyr::n_distinct(companies_clean$company_name),
      dplyr::n_distinct(companies_clean$company_size),
      dplyr::n_distinct(companies_clean$legal_nature),
      dplyr::n_distinct(companies_clean$owner_qualification)
    ),
    valores_ausentes = c(
      sum(is.na(companies_clean$company_id)),
      sum(is.na(companies_clean$company_name)),
      sum(is.na(companies_clean$company_size)),
      sum(is.na(companies_clean$legal_nature)),
      sum(is.na(companies_clean$owner_qualification))
    )
  )

  list(
    companies = companies_clean,
    domain_audit = domain_audit,
    lookup = list(
      legal_nature = raw_list$legal_nature,
      qualifications = raw_list$qualifications,
      size = raw_list$size
    )
  )
}

#' Carrega dados preparados em RDS ou constrói a partir de data/raw se necessário
#'
#' @param rds_path Caminho do artefato RDS pré-processado.
#' @param raw_dir Diretório de dados brutos caso o RDS não exista.
#' @return Lista preparada com `companies`, `domain_audit` e `lookup`.
get_prepared_data <- function(
    rds_path = file.path("data", "processed", "companies_prep.rds"),
    raw_dir = file.path("data", "raw")) {
  if (file.exists(rds_path)) {
    return(readRDS(rds_path))
  }

  raw_list <- load_raw_data(raw_dir)
  prepared <- prepare_companies_data(raw_list)

  dir.create(dirname(rds_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(prepared, rds_path, compress = "xz")
  prepared
}
