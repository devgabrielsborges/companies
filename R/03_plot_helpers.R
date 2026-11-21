# ==============================================================================
# 03_plot_helpers.R
# Paleta institucional, formatadores monetários e helpers visuais compartilhados
# entre os 10 módulos Shiny e o relatório Quarto.
# ==============================================================================

#' Paleta de cores consistente para os portes empresariais
SIZE_PALETTE <- c(
  "micro-enterprise" = "#1B4965",
  "small-enterprise" = "#5FA8D3",
  "other" = "#EE6C4D"
)

PRIMARY_COLOR <- "#1B4965"
ACCENT_COLOR <- "#EE6C4D"
MUTED_COLOR <- "#6C757D"

#' Formata inteiros no padrão brasileiro (ponto como separador de milhar)
#'
#' @param x Vetor numérico/inteiro.
#' @return Vetor de caracteres formatado.
format_int <- function(x) {
  format(x, big.mark = ".", decimal.mark = ",", scientific = FALSE)
}

#' Formata valores numéricos em Reais (BRL) de forma compacta ou completa
#'
#' @param x Vetor numérico.
#' @param compact Se TRUE, usa sufixos K, M, B, T para leitura rápida em eixos/KPIs.
#' @return Vetor de caracteres formatado.
format_brl <- function(x, compact = FALSE) {
  if (!compact) {
    return(scales::dollar(x, prefix = "R$ ", big.mark = ".", decimal.mark = ",", accuracy = 1))
  }

  dplyr::case_when(
    is.na(x) ~ "N/A",
    abs(x) >= 1e12 ~ sprintf("R$ %.2f T", x / 1e12),
    abs(x) >= 1e9  ~ sprintf("R$ %.2f B", x / 1e9),
    abs(x) >= 1e6  ~ sprintf("R$ %.2f M", x / 1e6),
    abs(x) >= 1e3  ~ sprintf("R$ %.1f K", x / 1e3),
    TRUE ~ sprintf("R$ %.0f", x)
  )
}

#' Valida se um data frame reativo possui registros antes de renderizar saídas
#'
#' @param df Data frame filtrado.
#' @param msg Mensagem amigável para estado vazio.
safe_validate_df <- function(df, msg = "Nenhum registro encontrado para os filtros selecionados.") {
  shiny::validate(
    shiny::need(!is.null(df) && nrow(df) > 0L, msg)
  )
}

#' Aplica layout padronizado e limpo aos gráficos plotly do aplicativo
#'
#' @param p Objeto plotly.
#' @param title Título do gráfico.
#' @param xlab Rótulo do eixo X.
#' @param ylab Rótulo do eixo Y.
#' @return Objeto plotly estilizado.
style_plotly <- function(p, title = NULL, xlab = NULL, ylab = NULL) {
  p |>
    plotly::layout(
      title = if (!is.null(title)) list(text = title, font = list(size = 15, color = "#1B4965")) else NULL,
      xaxis = list(title = xlab, gridcolor = "#EDF2F7", zeroline = FALSE),
      yaxis = list(title = ylab, gridcolor = "#EDF2F7", zeroline = FALSE),
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor = "rgba(0,0,0,0)",
      font = list(family = "Inter, system-ui, -apple-system, sans-serif", color = "#2D3748"),
      hoverlabel = list(bgcolor = "#1B4965", font = list(color = "#FFFFFF")),
      margin = list(t = 50, r = 20, b = 55, l = 60)
    ) |>
    plotly::config(displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d"))
}

#' Constrói tabela DT padronizada em PT-BR com estilo compacto
#'
#' @param df Data frame a exibir.
#' @param page_len Número de linhas por página.
#' @param server_mode Se TRUE, usa processamento no servidor (recomendado para > 5k linhas).
#' @return Widget DT::datatable.
build_dt_table <- function(df, page_len = 10L, server_mode = FALSE) {
  DT::datatable(
    df,
    rownames = FALSE,
    class = "compact stripe hover row-border",
    options = list(
      pageLength = page_len,
      scrollX = TRUE,
      autoWidth = FALSE,
      language = list(
        search = "Buscar:",
        lengthMenu = "Mostrar _MENU_ registros",
        info = "Mostrando _START_ a _END_ de _TOTAL_ registros",
        infoEmpty = "Nenhum registro disponível",
        zeroRecords = "Nenhum registro correspondente encontrado",
        paginate = list(previous = "Anterior", `next` = "Próximo")
      )
    )
  )
}
