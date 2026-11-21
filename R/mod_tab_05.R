# ==============================================================================
# mod_tab_05.R — Aba 5: Qualificação dos Sócios / Responsáveis
# ==============================================================================

mod_tab_05_ui <- function(id, legal_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Filtros de Qualificação",
      width = 280,
      shiny::sliderInput(
        ns("top_n"),
        "Exibir Top-N qualificações:",
        min = 3, max = 13, value = 10, step = 1
      ),
      shiny::radioButtons(
        ns("metric_type"),
        "Métrica do gráfico:",
        choices = c("Frequência (N)" = "n", "Mediana do Capital" = "mediana"),
        selected = "n"
      ),
      shiny::selectInput(
        ns("legal_filter"),
        "Filtrar por natureza jurídica:",
        choices = c("Todas as naturezas" = "ALL", legal_choices),
        selected = "ALL"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Perfil de governança: análise das 13 qualificações de responsáveis observadas (de 68 listadas em qualifications.csv)."
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Distribuição por Qualificação do Responsável"),
        plotly::plotlyOutput(ns("plot_qual"), height = "430px")
      ),
      bslib::card(
        bslib::card_header("Resumo Estatístico por Qualificação"),
        DT::DTOutput(ns("table_qual"))
      )
    )
  )
}

mod_tab_05_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    summary_r <- shiny::reactive({
      df <- companies_df
      if (input$legal_filter != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$legal_nature) == input$legal_filter)
      }
      safe_validate_df(df)

      # Calculamos também o porte modal por qualificação
      modal_size <- df |>
        dplyr::count(.data$owner_qualification, .data$company_size) |>
        dplyr::group_by(.data$owner_qualification) |>
        dplyr::slice_max(.data$n, n = 1, with_ties = FALSE) |>
        dplyr::ungroup() |>
        dplyr::transmute(
          grupo = as.character(.data$owner_qualification),
          porte_modal = as.character(.data$company_size)
        )

      summ <- compute_grouped_summary(df, "owner_qualification") |>
        dplyr::left_join(modal_size, by = "grupo")

      if (input$metric_type == "mediana") {
        summ <- summ |> dplyr::arrange(dplyr::desc(.data$mediana))
      }
      summ
    })

    output$plot_qual <- plotly::renderPlotly({
      top_df <- summary_r() |>
        dplyr::slice_head(n = input$top_n) |>
        dplyr::mutate(
          label_curto = stringr::str_trunc(.data$grupo, 36),
          label_curto = factor(.data$label_curto, levels = rev(.data$label_curto))
        )

      x_vals <- if (input$metric_type == "mediana") top_df$mediana else top_df$n
      xlab <- if (input$metric_type == "mediana") "Capital Social Mediano (R$)" else "Quantidade de Empresas"

      p <- plotly::plot_ly(
        data = top_df,
        x = x_vals,
        y = ~label_curto,
        type = "scatter",
        mode = "markers",
        marker = list(size = 12, color = ACCENT_COLOR),
        hovertemplate = paste(
          "<b>%{customdata[0]}</b><br>",
          "Empresas: %{customdata[1]} (%{customdata[2]:.2f}%)<br>",
          "Mediana: %{customdata[3]}<br>",
          "Porte modal: %{customdata[4]}<extra></extra>"
        ),
        customdata = ~cbind(
          grupo,
          format(n, big.mark = "."),
          pct,
          format_brl(mediana, compact = TRUE),
          porte_modal
        )
      )

      style_plotly(p, title = sprintf("Top %d Qualificações de Sócios/Responsáveis", nrow(top_df)), xlab = xlab, ylab = "")
    })

    output$table_qual <- DT::renderDT({
      tab <- summary_r() |>
        dplyr::transmute(
          Qualificação = .data$grupo,
          N = format(.data$n, big.mark = "."),
          `%` = sprintf("%.2f%%", .data$pct),
          Mediana = format_brl(.data$mediana, compact = TRUE),
          IQR = format_brl(.data$iqr, compact = TRUE),
          `Porte Modal` = .data$porte_modal
        )
      build_dt_table(tab, page_len = 10L)
    })
  })
}
