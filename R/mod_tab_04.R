# ==============================================================================
# mod_tab_04.R — Aba 4: Natureza Jurídica
# ==============================================================================

mod_tab_04_ui <- function(id, size_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Filtros de Natureza Jurídica",
      width = 280,
      shiny::sliderInput(
        ns("top_n"),
        "Exibir Top-N naturezas no gráfico:",
        min = 5, max = 22, value = 10, step = 1
      ),
      shiny::radioButtons(
        ns("order_by"),
        "Ordenar ranking por:",
        choices = c("Frequência (N)" = "n", "Mediana do Capital" = "mediana"),
        selected = "n"
      ),
      shiny::selectInput(
        ns("size_filter"),
        "Filtrar por porte:",
        choices = c("Todos os portes" = "ALL", size_choices),
        selected = "ALL"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Análise das 22 naturezas jurídicas presentes na base (de 91 possíveis em legal_nature.csv), destacando forte concentração societária."
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Ranking de Naturezas Jurídicas"),
        plotly::plotlyOutput(ns("plot_legal"), height = "450px")
      ),
      bslib::card(
        bslib::card_header("Tabela Completa por Natureza Jurídica"),
        DT::DTOutput(ns("table_legal"))
      )
    )
  )
}

mod_tab_04_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    summary_r <- shiny::reactive({
      df <- companies_df
      if (input$size_filter != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$company_size) == input$size_filter)
      }
      safe_validate_df(df)
      summ <- compute_grouped_summary(df, "legal_nature")
      if (input$order_by == "mediana") {
        summ <- summ |> dplyr::arrange(dplyr::desc(.data$mediana))
      }
      summ
    })

    output$plot_legal <- plotly::renderPlotly({
      top_df <- summary_r() |>
        dplyr::slice_head(n = input$top_n) |>
        dplyr::mutate(
          label_curto = stringr::str_trunc(.data$grupo, 36),
          label_curto = factor(.data$label_curto, levels = rev(.data$label_curto))
        )

      x_vals <- if (input$order_by == "mediana") top_df$mediana else top_df$n
      xlab <- if (input$order_by == "mediana") "Capital Social Mediano (R$)" else "Quantidade de Empresas"

      p <- plotly::plot_ly(
        data = top_df,
        x = x_vals,
        y = ~label_curto,
        type = "bar",
        orientation = "h",
        marker = list(color = PRIMARY_COLOR),
        hovertemplate = paste(
          "<b>%{customdata[0]}</b><br>",
          "Empresas: %{customdata[1]} (%{customdata[2]:.2f}%)<br>",
          "Mediana: %{customdata[3]}<extra></extra>"
        ),
        customdata = ~cbind(
          grupo,
          format(n, big.mark = "."),
          pct,
          format_brl(mediana, compact = TRUE)
        )
      ) |>
        plotly::layout(yaxis = list(title = ""))

      style_plotly(p, title = sprintf("Top %d Naturezas Jurídicas", nrow(top_df)), xlab = xlab, ylab = "")
    })

    output$table_legal <- DT::renderDT({
      tab <- summary_r() |>
        dplyr::transmute(
          `Natureza Jurídica` = .data$grupo,
          N = format(.data$n, big.mark = "."),
          `%` = sprintf("%.2f%%", .data$pct),
          `% Acum.` = sprintf("%.2f%%", .data$pct_acumulado),
          Mediana = format_brl(.data$mediana, compact = TRUE),
          IQR = format_brl(.data$iqr, compact = TRUE)
        )
      build_dt_table(tab, page_len = 10L)
    })
  })
}
