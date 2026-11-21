# ==============================================================================
# 02_stats_engine.R
# Motor estatístico compartilhado (single source of truth) entre o relatório
# Quarto e os 10 módulos do aplicativo Shiny.
# ==============================================================================

#' Calcula KPIs executivos para o panorama geral
#'
#' @param df Data frame de empresas (filtrado ou completo).
#' @return Lista com métricas agregadas.
compute_overview_kpis <- function(df) {
  if (nrow(df) == 0L) {
    return(list(
      n_companies = 0L,
      median_capital = NA_real_,
      iqr_capital = NA_real_,
      mean_capital = NA_real_,
      total_capital = 0,
      top_legal_nature = NA_character_,
      top_legal_nature_pct = NA_real_
    ))
  }

  nat_counts <- df |>
    dplyr::count(.data$legal_nature, sort = TRUE)

  list(
    n_companies = nrow(df),
    median_capital = stats::median(df$capital_stock),
    iqr_capital = stats::IQR(df$capital_stock),
    mean_capital = mean(df$capital_stock),
    total_capital = sum(df$capital_stock),
    top_legal_nature = as.character(nat_counts$legal_nature[1]),
    top_legal_nature_pct = 100 * nat_counts$n[1] / nrow(df)
  )
}

#' Calcula tabela detalhada de quantis e momentos de capital_stock
#'
#' @param df Data frame contendo `capital_stock` e `log10_capital`.
#' @return Tibble com quantis P1..P99.9 e métricas de forma.
compute_capital_quantiles <- function(df) {
  probs <- c(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 0.999)
  labels <- c("P1", "P5", "P10", "P25 (Q1)", "P50 (Mediana)", "P75 (Q3)",
              "P90", "P95", "P99", "P99.9")

  q_vals <- stats::quantile(df$capital_stock, probs = probs, names = FALSE)
  q_log <- stats::quantile(df$log10_capital, probs = probs, names = FALSE)

  tibble::tibble(
    quantil = labels,
    probabilidade = probs,
    capital_brl = q_vals,
    log10_capital = round(q_log, 4)
  )
}

#' Calcula assimetria (skewness) e curtose em excesso amostrais
#'
#' @param x Vetor numérico.
#' @return Lista nomeada com `skewness` e `excess_kurtosis`.
compute_shape_metrics <- function(x) {
  n <- length(x)
  if (n < 4L) {
    return(list(skewness = NA_real_, excess_kurtosis = NA_real_))
  }
  mu <- mean(x)
  s <- stats::sd(x)
  if (s == 0) {
    return(list(skewness = 0, excess_kurtosis = 0))
  }
  z <- (x - mu) / s
  list(
    skewness = mean(z^3),
    excess_kurtosis = mean(z^4) - 3
  )
}

#' Gera sumário estatístico estratificado por uma coluna categórica
#'
#' @param df Data frame de empresas.
#' @param group_col Nome da coluna de agrupamento (string).
#' @return Tibble ordenada por contagem decrescente com estatísticas robustas.
compute_grouped_summary <- function(df, group_col) {
  total_n <- nrow(df)
  if (total_n == 0L) {
    return(tibble::tibble())
  }

  df |>
    dplyr::group_by(grupo = as.character(.data[[group_col]])) |>
    dplyr::summarise(
      n = dplyr::n(),
      pct = 100 * dplyr::n() / total_n,
      mediana = stats::median(.data$capital_stock),
      q1 = stats::quantile(.data$capital_stock, 0.25, names = FALSE),
      q3 = stats::quantile(.data$capital_stock, 0.75, names = FALSE),
      iqr = stats::IQR(.data$capital_stock),
      media = mean(.data$capital_stock),
      dp = stats::sd(.data$capital_stock),
      capital_total = sum(.data$capital_stock),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$n)) |>
    dplyr::mutate(pct_acumulado = cumsum(.data$pct))
}

#' Calcula índice de Gini e pontos da curva de Lorenz de forma vetorizada
#'
#' @param x Vetor numérico positivo (capital_stock).
#' @param n_points Número máximo de pontos na curva de Lorenz para renderização leve.
#' @return Lista com `gini`, `top_1_pct_share`, `top_10_pct_share` e `lorenz_df`.
compute_gini_and_lorenz <- function(x, n_points = 200L) {
  x <- sort(x[is.finite(x) & x >= 0])
  n <- length(x)
  if (n == 0L || sum(x) == 0) {
    return(list(
      gini = NA_real_,
      top_1_pct_share = NA_real_,
      top_10_pct_share = NA_real_,
      lorenz_df = tibble::tibble(p = c(0, 1), lorenz = c(0, 1))
    ))
  }

  # Fórmula exata e O(n log n) para o coeficiente de Gini:
  # G = (2 * sum(i * x_i) / (n * sum(x_i))) - (n + 1) / n
  idx <- seq_len(n)
  total_x <- sum(x)
  gini <- (2 * sum(as.numeric(idx) * x) / (n * total_x)) - (n + 1) / n

  cum_x <- cumsum(x) / total_x
  cum_p <- idx / n

  top_1_idx <- max(1L, floor(0.99 * n))
  top_10_idx <- max(1L, floor(0.90 * n))
  top_1_share <- 100 * (1 - cum_x[top_1_idx])
  top_10_share <- 100 * (1 - cum_x[top_10_idx])

  # Subamostragem uniforme da curva para manter o plotly responsivo
  sample_idx <- unique(c(1L, round(seq(1, n, length.out = min(n, n_points))), n))
  lorenz_df <- tibble::tibble(
    p = c(0, cum_p[sample_idx]),
    lorenz = c(0, cum_x[sample_idx])
  )

  list(
    gini = gini,
    top_1_pct_share = top_1_share,
    top_10_pct_share = top_10_share,
    lorenz_df = lorenz_df
  )
}

#' Agrupa níveis de cauda longa em "Outros" mantendo os top_k mais frequentes
#'
#' @param x Vetor categórico/fator.
#' @param top_k Quantidade de categorias principais preservadas.
#' @return Fator com no máximo top_k + 1 níveis.
lump_top_k <- function(x, top_k = 8L) {
  forcats::fct_lump_n(factor(x), n = top_k, other_level = "Outros (cauda longa)")
}

#' Analisa associação entre duas variáveis categóricas (Qui-quadrado e V de Cramér)
#'
#' @param df Data frame de empresas.
#' @param var1 Nome da primeira coluna categórica.
#' @param var2 Nome da segunda coluna categórica.
#' @param top_k Limite de categorias por variável (agrupando cauda longa).
#' @return Lista com tabela longa `cell_df`, matriz `contingency` e métricas do teste.
compute_contingency_analysis <- function(df, var1, var2, top_k = 6L) {
  if (nrow(df) == 0L || var1 == var2) {
    return(NULL)
  }

  v1 <- lump_top_k(df[[var1]], top_k = top_k)
  v2 <- lump_top_k(df[[var2]], top_k = top_k)

  tab <- table(v1, v2)
  if (nrow(tab) < 2L || ncol(tab) < 2L) {
    return(NULL)
  }

  # Usamos simulate.p.value quando há células esperadas < 5 para rigor estatístico
  chi_res <- suppressWarnings(stats::chisq.test(tab))
  use_sim <- any(chi_res$expected < 5)
  if (use_sim) {
    chi_res <- stats::chisq.test(tab, simulate.p.value = TRUE, B = 2000L)
  }

  n_obs <- sum(tab)
  min_dim <- min(nrow(tab) - 1L, ncol(tab) - 1L)
  cramers_v <- sqrt(as.numeric(chi_res$statistic) / (n_obs * min_dim))

  row_prop <- prop.table(tab, margin = 1) * 100
  col_prop <- prop.table(tab, margin = 2) * 100
  std_res <- chi_res$stdres

  cell_df <- as.data.frame(tab, stringsAsFactors = FALSE) |>
    dplyr::rename(cat_1 = 1, cat_2 = 2, n = "Freq") |>
    dplyr::mutate(
      prop_linha = as.numeric(row_prop),
      prop_coluna = as.numeric(col_prop),
      residuo_padronizado = as.numeric(std_res)
    )

  list(
    cell_df = tibble::as_tibble(cell_df),
    contingency = tab,
    chi_sq = as.numeric(chi_res$statistic),
    df = if (is.null(chi_res$parameter) || is.na(chi_res$parameter)) NA_real_ else as.numeric(chi_res$parameter),
    p_value = chi_res$p.value,
    cramers_v = cramers_v,
    simulated_p = use_sim
  )
}

#' Executa teste não paramétrico de Kruskal-Wallis, epsilon^2 e pós-hoc pareado
#'
#' @param df Data frame contendo `capital_stock` e a coluna de grupo.
#' @param group_col Nome da coluna de agrupamento.
#' @param p_adjust_method Método de ajuste ("holm", "bonferroni", "BH").
#' @param top_k Limite máximo de grupos mais frequentes para manter legibilidade.
#' @return Lista com `omnibus` (tibble) e `pairwise` (tibble).
run_nonparametric_tests <- function(
    df,
    group_col,
    p_adjust_method = "holm",
    top_k = 8L) {
  if (nrow(df) == 0L) {
    return(NULL)
  }

  grp <- forcats::fct_lump_n(factor(df[[group_col]]), n = top_k, other_level = "Outros")
  if (nlevels(droplevels(grp)) < 2L) {
    return(NULL)
  }

  kw <- stats::kruskal.test(df$capital_stock ~ grp)
  n_obs <- nrow(df)
  k_groups <- nlevels(droplevels(grp))
  # Tamanho de efeito epsilon-quadrado para Kruskal-Wallis: H / ((n^2 - 1)/(n + 1))
  epsilon_sq <- as.numeric(kw$statistic) * (n_obs + 1) / (n_obs^2 - 1)

  omnibus <- tibble::tibble(
    teste = "Kruskal-Wallis",
    fator = group_col,
    grupos = k_groups,
    estatistica_h = as.numeric(kw$statistic),
    gl = as.numeric(kw$parameter),
    p_valor = kw$p.value,
    epsilon_quadrado = epsilon_sq
  )

  # Comparações pareadas via pairwise.wilcox.test (equivalente não paramétrico robusto)
  pw <- suppressWarnings(
    stats::pairwise.wilcox.test(
      x = df$capital_stock,
      g = grp,
      p.adjust.method = "none"
    )
  )

  p_mat <- pw$p.value
  pairwise_df <- tibble::tibble()

  if (!is.null(p_mat) && length(p_mat) > 0L) {
    idx <- which(!is.na(p_mat), arr.ind = TRUE)
    raw_p <- p_mat[idx]
    adj_p <- stats::p.adjust(raw_p, method = p_adjust_method)

    # Também calculamos a mediana de cada grupo para mostrar a direção da diferença
    med_map <- tapply(df$capital_stock, grp, stats::median)

    pairwise_df <- tibble::tibble(
      grupo_1 = rownames(p_mat)[idx[, "row"]],
      grupo_2 = colnames(p_mat)[idx[, "col"]],
      mediana_1 = as.numeric(med_map[rownames(p_mat)[idx[, "row"]]]),
      mediana_2 = as.numeric(med_map[colnames(p_mat)[idx[, "col"]]]),
      p_bruto = raw_p,
      p_ajustado = adj_p,
      metodo_ajuste = p_adjust_method
    ) |>
      dplyr::arrange(.data$p_ajustado)
  }

  list(
    omnibus = omnibus,
    pairwise = pairwise_df
  )
}

#' Extrai frequência de termos principais em `company_name`
#'
#' @param df Data frame contendo `company_name` e `capital_stock`.
#' @param top_n Quantidade de termos retornados.
#' @return Tibble com termo, frequência e capital mediano.
compute_top_name_tokens <- function(df, top_n = 20L) {
  if (nrow(df) == 0L) {
    return(tibble::tibble())
  }

  stopwords_pt <- c(
    "DE", "DA", "DO", "DAS", "DOS", "E", "EM", "COM", "PARA", "POR",
    "LTDA", "LIMITADA", "SA", "S", "A", "ME", "EPP", "EIRELI", "UNIPESSOAL"
  )

  tokens <- stringr::str_split(stringr::str_to_upper(df$company_name), "[^A-Z0-9]+")
  lengths_vec <- lengths(tokens)

  token_df <- tibble::tibble(
    termo = unlist(tokens, use.names = FALSE),
    capital_stock = rep(df$capital_stock, times = lengths_vec)
  ) |>
    dplyr::filter(nchar(.data$termo) >= 3L, !(.data$termo %in% stopwords_pt)) |>
    dplyr::group_by(.data$termo) |>
    dplyr::summarise(
      ocorrencias = dplyr::n(),
      mediana_capital = stats::median(.data$capital_stock),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$ocorrencias)) |>
    dplyr::slice_head(n = top_n)

  token_df
}
