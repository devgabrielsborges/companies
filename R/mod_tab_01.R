# ==============================================================================
# mod_tab_01.R — Aba 1: Panorama Geral
# ==============================================================================

mod_tab_01_ui <- function(id, size_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Filtros do Panorama",
      width = 280,
      shiny::checkboxGroupInput(
        ns("sizes"),
        "Porte empresarial (company_size):",
        choices = size_choices,
        selected = size_choices
      ),
      shiny::radioButtons(
        ns("metric_mode"),
        "Escala do gráfico:",
        choices = c("Contagem absoluta (N)" = "count", "Participação (%)" = "pct"),
        selected = "pct"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Visão executiva da base de empresas: distribuição por porte, capital social mediano e concentração societária."
    ),
    bslib::layout_columns(
      col_widths = c(3, 3, 3, 3),
      bslib::value_box(
        title = "Empresas Selecionadas",
        value = shiny::textOutput(ns("kpi_n")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      ),
      bslib::value_box(
        title = "Mediana do Capital Social",
        value = shiny::textOutput(ns("kpi_median")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      ),
      bslib::value_box(
        title = "Intervalo Interquartil (IQR)",
        value = shiny::textOutput(ns("kpi_iqr")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      ),
      bslib::value_box(
        title = "Natureza Dominante",
        value = shiny::textOutput(ns("kpi_top_nat")),
        theme = bslib::value_box_theme(bg = "#F8FAFC", fg = "#1B4965")
      )
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Composição por Porte Empresarial"),
        plotly::plotlyOutput(ns("plot_size"), height = "380px")
      ),
      bslib::card(
        bslib::card_header("Sumário Executivo por Porte"),
        DT::DTOutput(ns("table_overview"))
      )
    )
  )
}

mod_tab_01_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    filtered_df <- shiny::reactive({
      req_sizes <- input$sizes
      if (is.null(req_sizes) || length(req_sizes) == 0L) {
        return(companies_df[0, ])
      }
      companies_df |> dplyr::filter(as.character(.data$company_size) %in% req_sizes)
    })

    kpis_r <- shiny::reactive({
      df <- filtered_df()
      safe_validate_df(df)
      compute_overview_kpis(df)
    })

    output$kpi_n <- shiny::renderText({
      format_int(kpis_r()$n_companies)
    })

    output$kpi_median <- shiny::renderText({
      format_brl(kpis_r()$median_capital, compact = TRUE)
    })

    output$kpi_iqr <- shiny::renderText({
      format_brl(kpis_r()$iqr_capital, compact = TRUE)
    })

    output$kpi_top_nat <- shiny::renderText({
      k <- kpis_r()
      sprintf("%.1f%% (%s)", k$top_legal_nature_pct, stringr::str_trunc(k$top_legal_nature, 24))
    })

    summary_r <- shiny::reactive({
      df <- filtered_df()
      safe_validate_df(df)
      compute_grouped_summary(df, "company_size")
    })

    output$plot_size <- plotly::renderPlotly({
      summ <- summary_r()
      y_var <- if (input$metric_mode == "pct") summ$pct else summ$n
      y_lab <- if (input$metric_mode == "pct") "Participação (%)" else "Quantidade de Empresas"

      p <- plotly::plot_ly(
        data = summ,
        x = ~grupo,
        y = y_var,
        type = "bar",
        color = ~grupo,
        colors = SIZE_PALETTE,
        text = ~sprintf("%s (%.1f%%)", format(n, big.mark = "."), pct),
        textposition = "outside",
        hovertemplate = paste(
          "<b>%{x}</b><br>",
          "Empresas: %{customdata[0]}<br>",
          "Participação: %{customdata[1]:.2f}%<br>",
          "Mediana Capital: %{customdata[2]}<extra></extra>"
        ),
        customdata = ~cbind(
          format(n, big.mark = "."),
          pct,
          format_brl(mediana, compact = TRUE)
        )
      ) |>
        plotly::layout(showlegend = FALSE)

      style_plotly(p, title = "Distribuição por Porte Empresarial", xlab = "Porte", ylab = y_lab)
    })

    output$table_overview <- DT::renderDT({
      summ <- summary_r() |>
        dplyr::transmute(
          Porte = .data$grupo,
          Empresas = format(.data$n, big.mark = "."),
          `%` = sprintf("%.2f%%", .data$pct),
          Mediana = format_brl(.data$mediana),
          IQR = format_brl(.data$iqr),
          Média = format_brl(.data$media)
        )
      build_dt_table(summ, page_len = 5L)
    })
  })
}
