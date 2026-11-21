# ==============================================================================
# mod_tab_08.R — Aba 8: Padrões de Nomenclatura e Entidades
# ==============================================================================

mod_tab_08_ui <- function(id, size_choices) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Mineração de Nomes",
      width = 280,
      shiny::selectInput(
        ns("size_filter"),
        "Filtrar por porte:",
        choices = c("Todos os portes" = "ALL", size_choices),
        selected = "ALL"
      ),
      shiny::radioButtons(
        ns("view_mode"),
        "Dimensão textual analisada:",
        choices = c(
          "Sufixos societários (LTDA, S/A...)" = "suffix",
          "Termos mais frequentes no nome" = "tokens"
        ),
        selected = "suffix"
      ),
      shiny::sliderInput(
        ns("top_n_tokens"),
        "Top-N termos (quando aplicável):",
        min = 10, max = 30, value = 15, step = 5
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Análise lexical de company_name: sufixos societários, termos mais recorrentes e identificação de 593 homônimos nominais."
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Frequência Textual na Razão Social"),
        plotly::plotlyOutput(ns("plot_naming"), height = "420px")
      ),
      bslib::card(
        bslib::card_header("Tabela de Padrões e Capital Mediano"),
        DT::DTOutput(ns("table_naming"))
      )
    )
  )
}

mod_tab_08_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    filtered_df <- shiny::reactive({
      df <- companies_df
      if (input$size_filter != "ALL") {
        df <- df |> dplyr::filter(as.character(.data$company_size) == input$size_filter)
      }
      safe_validate_df(df)
      df
    })

    naming_r <- shiny::reactive({
      df <- filtered_df()
      if (input$view_mode == "suffix") {
        compute_grouped_summary(df, "legal_suffix") |>
          dplyr::transmute(
            padrao = .data$grupo,
            ocorrencias = .data$n,
            pct = .data$pct,
            mediana_capital = .data$mediana
          )
      } else {
        compute_top_name_tokens(df, top_n = input$top_n_tokens) |>
          dplyr::transmute(
            padrao = .data$termo,
            ocorrencias = .data$ocorrencias,
            pct = 100 * .data$ocorrencias / nrow(df),
            mediana_capital = .data$mediana_capital
          )
      }
    })

    output$plot_naming <- plotly::renderPlotly({
      ndf <- naming_r() |>
        dplyr::mutate(padrao = factor(.data$padrao, levels = rev(.data$padrao)))

      p <- plotly::plot_ly(
        data = ndf,
        x = ~ocorrencias,
        y = ~padrao,
        type = "bar",
        orientation = "h",
        marker = list(color = PRIMARY_COLOR),
        hovertemplate = paste(
          "<b>%{y}</b><br>",
          "Ocorrências: %{customdata[0]}<br>",
          "Mediana Capital: %{customdata[1]}<extra></extra>"
        ),
        customdata = ~cbind(format(ocorrencias, big.mark = "."), format_brl(mediana_capital, compact = TRUE))
      )

      title_txt <- if (input$view_mode == "suffix") {
        "Distribuição por Sufixo Societário"
      } else {
        sprintf("Top %d Termos na Razão Social", nrow(ndf))
      }

      style_plotly(p, title = title_txt, xlab = "Ocorrências", ylab = "")
    })

    output$table_naming <- DT::renderDT({
      tab <- naming_r() |>
        dplyr::transmute(
          `Padrão / Termo` = .data$padrao,
          Ocorrências = format(.data$ocorrencias, big.mark = "."),
          `% da Seleção` = sprintf("%.2f%%", .data$pct),
          `Mediana Capital` = format_brl(.data$mediana_capital, compact = TRUE)
        )
      build_dt_table(tab, page_len = 10L)
    })
  })
}
