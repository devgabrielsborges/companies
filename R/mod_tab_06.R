# ==============================================================================
# mod_tab_06.R — Aba 6: Associações Categóricas
# ==============================================================================

mod_tab_06_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Parâmetros de Associação",
      width = 280,
      shiny::selectInput(
        ns("pair_choice"),
        "Par de variáveis categóricas:",
        choices = c(
          "Porte × Natureza Jurídica" = "company_size__legal_nature",
          "Porte × Qualificação do Sócio" = "company_size__owner_qualification",
          "Natureza Jurídica × Qualificação" = "legal_nature__owner_qualification"
        ),
        selected = "company_size__legal_nature"
      ),
      shiny::sliderInput(
        ns("top_k"),
        "Top-K categorias (demais em 'Outros'):",
        min = 3, max = 10, value = 6, step = 1
      ),
      shiny::radioButtons(
        ns("heat_metric"),
        "Métrica no mapa de calor:",
        choices = c(
          "Resíduo padronizado de Pearson" = "residuo_padronizado",
          "Proporção por linha (%)" = "prop_linha",
          "Proporção por coluna (%)" = "prop_coluna"
        ),
        selected = "residuo_padronizado"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Teste Qui-quadrado de independência, V de Cramér e resíduos padronizados para identificar associações estruturais entre categorias."
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(
        bslib::card_header("Mapa de Calor da Associação"),
        plotly::plotlyOutput(ns("plot_assoc"), height = "430px")
      ),
      bslib::card(
        bslib::card_header("Tabela de Contingência e Teste Qui-quadrado"),
        shiny::uiOutput(ns("assoc_summary_badge")),
        DT::DTOutput(ns("table_assoc"))
      )
    )
  )
}

mod_tab_06_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    assoc_r <- shiny::reactive({
      parts <- strsplit(input$pair_choice, "__")[[1]]
      res <- compute_contingency_analysis(
        companies_df,
        var1 = parts[1],
        var2 = parts[2],
        top_k = input$top_k
      )
      shiny::validate(shiny::need(!is.null(res), "Associação indisponível para esta seleção."))
      res
    })

    output$assoc_summary_badge <- shiny::renderUI({
      res <- assoc_r()
      p_txt <- if (res$p_value < 1e-4) "< 0,0001" else sprintf("%.4f", res$p_value)
      shiny::div(
        class = "alert alert-info py-2 px-3 mb-2",
        shiny::HTML(sprintf(
          "<strong>&chi;&sup2;</strong> = %s | <strong>p-valor</strong> %s | <strong>V de Cramér</strong> = %.4f",
          format(round(res$chi_sq, 1), big.mark = ".", decimal.mark = ","),
          p_txt,
          res$cramers_v
        ))
      )
    })

    output$plot_assoc <- plotly::renderPlotly({
      res <- assoc_r()
      cell_df <- res$cell_df |>
        dplyr::mutate(
          cat_1_short = stringr::str_trunc(as.character(.data$cat_1), 24),
          cat_2_short = stringr::str_trunc(as.character(.data$cat_2), 28)
        )

      z_vals <- cell_df[[input$heat_metric]]
      colorscale <- if (input$heat_metric == "residuo_padronizado") "RdBu" else "Blues"

      p <- plotly::plot_ly(
        data = cell_df,
        x = ~cat_1_short,
        y = ~cat_2_short,
        z = z_vals,
        type = "heatmap",
        colorscale = colorscale,
        reversescale = (input$heat_metric == "residuo_padronizado"),
        hovertemplate = paste(
          "<b>%{x}</b> × <b>%{y}</b><br>",
          "N: %{customdata[0]}<br>",
          "Prop. linha: %{customdata[1]:.1f}%<br>",
          "Resíduo Pearson: %{customdata[2]:.2f}<extra></extra>"
        ),
        customdata = ~cbind(format(n, big.mark = "."), prop_linha, residuo_padronizado)
      )

      style_plotly(p, title = "Associação Entre Variáveis Categóricas", xlab = "", ylab = "")
    })

    output$table_assoc <- DT::renderDT({
      res <- assoc_r()
      tab <- res$cell_df |>
        dplyr::arrange(dplyr::desc(abs(.data$residuo_padronizado))) |>
        dplyr::transmute(
          `Categoria 1` = .data$cat_1,
          `Categoria 2` = .data$cat_2,
          N = format(.data$n, big.mark = "."),
          `% Linha` = sprintf("%.1f%%", .data$prop_linha),
          `% Coluna` = sprintf("%.1f%%", .data$prop_coluna),
          `Resíduo` = round(.data$residuo_padronizado, 2)
        )
      build_dt_table(tab, page_len = 8L)
    })
  })
}
