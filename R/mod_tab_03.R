# ==============================================================================
# mod_tab_03.R — Aba 3: Comparação por Porte Empresarial
# ==============================================================================

mod_tab_03_ui <- function(id, size_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Comparação por Porte",
      width = 280,
      shiny::checkboxGroupInput(
        ns("sizes"),
        "Portes comparados:",
        choices = size_choices,
        selected = size_choices
      ),
      shiny::radioButtons(
        ns("scale_mode"),
        "Escala do eixo Y:",
        choices = c("Logarítmica (log10)" = "log10", "Linear (R$)" = "linear"),
        selected = "log10"
      ),
      shiny::radioButtons(
        ns("geom_type"),
        "Tipo de gráfico:",
        choices = c("Violin + Boxplot" = "violin", "Boxplot Clássico" = "box"),
        selected = "violin"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Comparação da distribuição de capital social entre micro-enterprise, small-enterprise e other."
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Distribuição Comparativa por Porte"),
        plotly::plotlyOutput(ns("plot_size_comp"), height = "430px")
      ),
      bslib::card(
        bslib::card_header("Estatísticas Estratificadas por Porte"),
        DT::DTOutput(ns("table_size_comp"))
      )
    )
  )
}

mod_tab_03_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    filtered_df <- shiny::reactive({
      req_sizes <- input$sizes
      if (is.null(req_sizes) || length(req_sizes) == 0L) {
        return(companies_df[0, ])
      }
      df <- companies_df |> dplyr::filter(as.character(.data$company_size) %in% req_sizes)
      safe_validate_df(df)
      df
    })

    output$plot_size_comp <- plotly::renderPlotly({
      df <- filtered_df()
      # Amostragem estratificada de até 15.000 pontos apenas para renderização fluida
      # de violin/boxplot no plotly sem perder fidelidade visual dos quantis.
      if (nrow(df) > 15000L) {
        set.seed(42)
        df_plot <- df |>
          dplyr::group_by(.data$company_size) |>
          dplyr::slice_sample(prop = 15000 / nrow(df)) |>
          dplyr::ungroup()
      } else {
        df_plot <- df
      }

      y_vals <- if (input$scale_mode == "log10") df_plot$log10_capital else df_plot$capital_stock
      ylab <- if (input$scale_mode == "log10") "log10(Capital Social)" else "Capital Social (R$)"

      if (input$geom_type == "violin") {
        p <- plotly::plot_ly(
          data = df_plot,
          x = ~company_size,
          y = y_vals,
          split = ~company_size,
          color = ~company_size,
          colors = SIZE_PALETTE,
          type = "violin",
          box = list(visible = TRUE),
          meanline = list(visible = TRUE),
          points = FALSE
        )
      } else {
        p <- plotly::plot_ly(
          data = df_plot,
          x = ~company_size,
          y = y_vals,
          color = ~company_size,
          colors = SIZE_PALETTE,
          type = "box",
          boxpoints = "outliers"
        )
      }

      p <- p |> plotly::layout(showlegend = FALSE)
      style_plotly(p, title = "Capital Social por Porte Empresarial", xlab = "Porte", ylab = ylab)
    })

    output$table_size_comp <- DT::renderDT({
      df <- filtered_df()
      summ <- compute_grouped_summary(df, "company_size") |>
        dplyr::transmute(
          Porte = .data$grupo,
          N = format(.data$n, big.mark = "."),
          `%` = sprintf("%.2f%%", .data$pct),
          Q1 = format_brl(.data$q1, compact = TRUE),
          Mediana = format_brl(.data$mediana, compact = TRUE),
          Q3 = format_brl(.data$q3, compact = TRUE),
          IQR = format_brl(.data$iqr, compact = TRUE)
        )
      build_dt_table(summ, page_len = 5L)
    })
  })
}
