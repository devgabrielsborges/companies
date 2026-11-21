# ==============================================================================
# mod_tab_07.R — Aba 7: Concentração e Outliers (Curva de Lorenz e Gini)
# ==============================================================================

mod_tab_07_ui <- function(id, size_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Concentração e Extremos",
      width = 280,
      shiny::selectInput(
        ns("scope_size"),
        "Escopo de análise:",
        choices = c("Base completa (Geral)" = "ALL", size_choices),
        selected = "ALL"
      ),
      shiny::radioButtons(
        ns("outlier_rule"),
        "Critério de identificação de outliers:",
        choices = c(
          "Tukey 1,5×IQR em escala log10" = "tukey_log",
          "Acima do P99 (Top 1%)" = "p99"
        ),
        selected = "tukey_log"
      ),
      shiny::sliderInput(
        ns("top_outliers_n"),
        "Quantidade de outliers na tabela:",
        min = 10, max = 100, value = 25, step = 5
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Mensuração da desigualdade de capital social via Curva de Lorenz, coeficiente de Gini e detecção de valores extremos."
    ),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      bslib::value_box(
        title = "Índice de Gini",
        value = shiny::textOutput(ns("kpi_gini")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      ),
      bslib::value_box(
        title = "Participação do Top 1%",
        value = shiny::textOutput(ns("kpi_top1")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#EE6C4D")
      ),
      bslib::value_box(
        title = "Outliers Detectados",
        value = shiny::textOutput(ns("kpi_outliers")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      )
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Curva de Lorenz do Capital Social"),
        plotly::plotlyOutput(ns("plot_lorenz"), height = "390px")
      ),
      bslib::card(
        bslib::card_header("Maiores Outliers Identificados"),
        DT::DTOutput(ns("table_outliers"))
      )
    )
  )
}

mod_tab_07_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    scoped_df <- shiny::reactive({
      df <- companies_df
      if (input$scope_size != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$company_size) == input$scope_size)
      }
      safe_validate_df(df)
      df
    })

    gini_r <- shiny::reactive({
      compute_gini_and_lorenz(scoped_df()$capital_stock)
    })

    outliers_r <- shiny::reactive({
      df <- scoped_df()
      if (input$outlier_rule == "tukey_log") {
        df |> dplyr::filter(.data$is_outlier_log_iqr)
      } else {
        cutoff <- stats::quantile(df$capital_stock, 0.99, names = FALSE)
        df |> dplyr::filter(.data$capital_stock > cutoff)
      }
    })

    output$kpi_gini <- shiny::renderText({
      sprintf("%.4f", gini_r()$gini)
    })

    output$kpi_top1 <- shiny::renderText({
      sprintf("%.2f%% do capital", gini_r()$top_1_pct_share)
    })

    output$kpi_outliers <- shiny::renderText({
      n_out <- nrow(outliers_r())
      pct_out <- 100 * n_out / nrow(scoped_df())
      sprintf("%s (%.2f%%)", format_int(n_out), pct_out)
    })

    output$plot_lorenz <- plotly::renderPlotly({
      g <- gini_r()
      ldf <- g$lorenz_df

      p <- plotly::plot_ly() |>
        plotly::add_trace(
          x = c(0, 100), y = c(0, 100),
          type = "scatter", mode = "lines",
          name = "Igualdade Perfeita",
          line = list(color = MUTED_COLOR, dash = "dash", width = 1.5)
        ) |>
        plotly::add_trace(
          data = ldf,
          x = ~p * 100, y = ~lorenz * 100,
          type = "scatter", mode = "lines",
          name = sprintf("Curva de Lorenz (Gini = %.4f)", g$gini),
          fill = "tozeroy",
          fillcolor = "rgba(27, 73, 101, 0.15)",
          line = list(color = PRIMARY_COLOR, width = 3)
        ) |>
        plotly::layout(legend = list(x = 0.05, y = 0.92))

      style_plotly(
        p,
        title = "Curva de Lorenz — Concentração de Capital",
        xlab = "% Acumulado de Empresas",
        ylab = "% Acumulado de Capital Social"
      )
    })

    output$table_outliers <- DT::renderDT({
      out_df <- outliers_r() |>
        dplyr::arrange(dplyr::desc(.data$capital_stock)) |>
        dplyr::slice_head(n = input$top_outliers_n) |>
        dplyr::transmute(
          Empresa = stringr::str_trunc(.data$company_name, 35),
          Porte = as.character(.data$company_size),
          Natureza = stringr::str_trunc(as.character(.data$legal_nature), 28),
          `Capital (R$)` = format_brl(.data$capital_stock, compact = TRUE)
        )
      build_dt_table(out_df, page_len = 8L)
    })
  })
}
