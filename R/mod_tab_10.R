# ==============================================================================
# mod_tab_10.R — Aba 10: Explorador de Dados e Sincronia com o Relatório
# ==============================================================================

mod_tab_10_ui <- function(id, size_choices, legal_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Explorador Granular",
      width = 290,
      shiny::textInput(
        ns("search_name"),
        "Buscar na razão social:",
        placeholder = "Ex.: CONSTRUCAO, CLINICA, BANCO"
      ),
      shiny::selectInput(
        ns("size_filter"),
        "Porte:",
        choices = c("Todos" = "ALL", size_choices),
        selected = "ALL"
      ),
      shiny::selectInput(
        ns("legal_filter"),
        "Natureza jurídica:",
        choices = c("Todas" = "ALL", legal_choices),
        selected = "ALL"
      ),
      shiny::sliderInput(
        ns("log_cap_range"),
        "Faixa de log10(Capital Social):",
        min = 5.0, max = 12.0, value = c(5.0, 12.0), step = 0.2
      ),
      shiny::downloadButton(ns("download_csv"), "Exportar CSV Filtrado", class = "btn-primary w-100 mt-2")
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Consulta registro a registro (141.332 empresas), auditoria de cobertura frente às tabelas auxiliares e exportação CSV."
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Subconjunto Filtrado vs. Base Global (log10 Capital)"),
        plotly::plotlyOutput(ns("plot_explorer_dist"), height = "260px")
      ),
      bslib::card(
        bslib::card_header("Auditoria de Domínio e Sincronia com o Relatório"),
        DT::DTOutput(ns("table_audit"))
      )
    ),
    bslib::card(
      bslib::card_header("Registros Filtrados (Paginação no Servidor)"),
      DT::DTOutput(ns("table_explorer"))
    )
  )
}

mod_tab_10_server <- function(id, companies_df, domain_audit_df) {
  shiny::moduleServer(id, function(input, output, session) {
    filtered_df <- shiny::reactive({
      df <- companies_df |>
        dplyr::filter(
          .data$log10_capital >= input$log_cap_range[1],
          .data$log10_capital <= input$log_cap_range[2]
        )

      if (input$size_filter != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$company_size) == input$size_filter)
      }
      if (input$legal_filter != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$legal_nature) == input$legal_filter)
      }
      if (nzchar(trimws(input$search_name))) {
        query <- stringr::str_to_upper(trimws(input$search_name))
        df <- df |> dplyr::filter(stringr::str_detect(.data$company_name, stringr::fixed(query)))
      }
      df
    })

    output$plot_explorer_dist <- plotly::renderPlotly({
      df <- filtered_df()
      safe_validate_df(df)

      # Amostragem leve para manter resposta < 1.5s mesmo com 141k linhas
      global_sample <- if (nrow(companies_df) > 10000L) companies_df$log10_capital[seq(1, nrow(companies_df), by = 14)] else companies_df$log10_capital
      sub_sample <- if (nrow(df) > 10000L) df$log10_capital[seq(1, nrow(df), length.out = 10000)] else df$log10_capital

      p <- plotly::plot_ly(alpha = 0.55) |>
        plotly::add_histogram(
          x = global_sample, histnorm = "probability density",
          name = "Base Global", marker = list(color = MUTED_COLOR)
        ) |>
        plotly::add_histogram(
          x = sub_sample, histnorm = "probability density",
          name = sprintf("Filtrado (N=%s)", format(nrow(df), big.mark = ".")),
          marker = list(color = PRIMARY_COLOR)
        ) |>
        plotly::layout(barmode = "overlay", legend = list(x = 0.65, y = 0.95))

      style_plotly(p, title = NULL, xlab = "log10(Capital Social)", ylab = "Densidade")
    })

    output$table_audit <- DT::renderDT({
      build_dt_table(domain_audit_df, page_len = 5L)
    })

    output$table_explorer <- DT::renderDT(
      {
        df <- filtered_df()
        safe_validate_df(df)
        df |>
          dplyr::transmute(
            ID = .data$company_id,
            `Razão Social` = .data$company_name,
            Porte = as.character(.data$company_size),
            `Natureza Jurídica` = as.character(.data$legal_nature),
            Qualificação = as.character(.data$owner_qualification),
            `Capital (R$)` = format_brl(.data$capital_stock)
          )
      },
      server = TRUE,
      rownames = FALSE,
      options = list(pageLength = 10L, scrollX = TRUE)
    )

    output$download_csv <- shiny::downloadHandler(
      filename = function() {
        sprintf("empresas_filtradas_%s.csv", format(Sys.Date(), "%Y%m%d"))
      },
      content = function(file) {
        readr::write_csv(filtered_df(), file)
      }
    )
  })
}
