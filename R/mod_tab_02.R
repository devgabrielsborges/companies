# ==============================================================================
# mod_tab_02.R — Aba 2: Distribuição do Capital Social
# ==============================================================================

mod_tab_02_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Parâmetros da Distribuição",
      width = 280,
      shiny::radioButtons(
        ns("scale_mode"),
        "Escala do eixo de capital:",
        choices = c("Logarítmica (log10)" = "log10", "Linear (R$)" = "linear"),
        selected = "log10"
      ),
      shiny::selectInput(
        ns("plot_type"),
        "Tipo de visualização:",
        choices = c(
          "Histograma + Densidade" = "hist",
          "Distribuição Acumulada (ECDF)" = "ecdf"
        ),
        selected = "hist"
      ),
      shiny::selectInput(
        ns("quantile_cap"),
        "Recorte de quantil superior:",
        choices = c(
          "Base completa (0–100%)" = "1.0",
          "Até P99 (remove 1% extremo)" = "0.99",
          "Até P95 (remove 5% extremo)" = "0.95"
        ),
        selected = "1.0"
      ),
      shiny::sliderInput(
        ns("bins"),
        "Número de faixas (bins):",
        min = 15, max = 80, value = 40, step = 5
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Análise univariada de capital_stock: evidência de assimetria severa à direita e necessidade de escala log10."
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Distribuição do Capital Social"),
        plotly::plotlyOutput(ns("plot_dist"), height = "430px")
      ),
      bslib::card(
        bslib::card_header("Tabela de Quantis e Forma"),
        DT::DTOutput(ns("table_quantiles"))
      )
    )
  )
}

mod_tab_02_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    sliced_df <- shiny::reactive({
      cap_prob <- as.numeric(input$quantile_cap)
      if (cap_prob < 1) {
        cutoff <- stats::quantile(companies_df$capital_stock, probs = cap_prob, names = FALSE)
        df <- companies_df |> dplyr::filter(.data$capital_stock <= cutoff)
      } else {
        df <- companies_df
      }
      safe_validate_df(df)
      df
    })

    output$plot_dist <- plotly::renderPlotly({
      df <- sliced_df()
      vals <- if (input$scale_mode == "log10") df$log10_capital else df$capital_stock
      xlab <- if (input$scale_mode == "log10") "log10(Capital Social em R$)" else "Capital Social (R$)"

      if (input$plot_type == "hist") {
        med_val <- stats::median(vals)
        p <- plotly::plot_ly(
          x = vals,
          type = "histogram",
          nbinsx = input$bins,
          marker = list(color = PRIMARY_COLOR, line = list(color = "#FFFFFF", width = 0.5)),
          name = "Frequência"
        ) |>
          plotly::layout(
            shapes = list(
              list(
                type = "line", x0 = med_val, x1 = med_val, y0 = 0, y1 = 1,
                yref = "paper", line = list(color = ACCENT_COLOR, width = 2, dash = "dash")
              )
            ),
            annotations = list(
              list(
                x = med_val, y = 0.95, yref = "paper",
                text = sprintf("Mediana: %.2f", med_val),
                showarrow = TRUE, arrowhead = 2, ax = 40, ay = -20,
                font = list(color = ACCENT_COLOR, size = 12)
              )
            )
          )
        style_plotly(p, title = "Histograma do Capital Social", xlab = xlab, ylab = "Empresas")
      } else {
        # ECDF amostrada em 400 pontos para manter o gráfico leve e instantâneo
        probs <- seq(0, 1, length.out = 400)
        q_vals <- stats::quantile(vals, probs = probs, names = FALSE)
        p <- plotly::plot_ly(
          x = q_vals,
          y = probs * 100,
          type = "scatter",
          mode = "lines",
          line = list(color = PRIMARY_COLOR, width = 3),
          hovertemplate = "Valor: %{x:.2f}<br>Acumulado: %{y:.1f}%<extra></extra>"
        )
        style_plotly(p, title = "Função de Distribuição Acumulada (ECDF)", xlab = xlab, ylab = "% Acumulado")
      }
    })

    output$table_quantiles <- DT::renderDT({
      df <- sliced_df()
      q_tab <- compute_capital_quantiles(df)
      shape <- compute_shape_metrics(df$capital_stock)

      out_tab <- q_tab |>
        dplyr::transmute(
          Quantil = .data$quantil,
          `Capital (R$)` = format_brl(.data$capital_brl),
          `log10(Capital)` = .data$log10_capital
        ) |>
        dplyr::bind_rows(
          tibble::tibble(
            Quantil = c("Assimetria (Skewness)", "Curtose em Excesso"),
            `Capital (R$)` = c(
              sprintf("%.2f", shape$skewness),
              sprintf("%.2f", shape$excess_kurtosis)
            ),
            `log10(Capital)` = NA_real_
          )
        )

      build_dt_table(out_tab, page_len = 12L)
    })
  })
}
