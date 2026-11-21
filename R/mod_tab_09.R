# ==============================================================================
# mod_tab_09.R — Aba 9: Testes Estatísticos e Tamanhos de Efeito
# ==============================================================================

mod_tab_09_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "Parâmetros Inferenciais",
      width = 280,
      shiny::selectInput(
        ns("group_factor"),
        "Fator de comparação (sobre capital_stock):",
        choices = c(
          "Porte empresarial (company_size)" = "company_size",
          "Natureza jurídica (Top-6 + Outros)" = "legal_nature",
          "Qualificação do sócio (Top-6 + Outros)" = "owner_qualification"
        ),
        selected = "company_size"
      ),
      shiny::selectInput(
        ns("p_adjust"),
        "Método de correção para múltiplos testes:",
        choices = c(
          "Holm-Bonferroni" = "holm",
          "Bonferroni" = "bonferroni",
          "Benjamini-Hochberg (FDR)" = "BH"
        ),
        selected = "holm"
      ),
      shiny::radioButtons(
        ns("alpha"),
        "Nível de significância (α):",
        choices = c("0,01" = "0.01", "0,05" = "0.05", "0,10" = "0.10"),
        selected = "0.05"
      )
    ),
    shiny::div(
      class = "tab-intro-banner",
      "Inferência não paramétrica (Kruskal-Wallis + tamanho de efeito epsilon² + comparações pós-hoc pareadas) alinhada à assimetria da base."
    ),
    bslib::layout_columns(
      col_widths = c(12),
      shiny::uiOutput(ns("omnibus_banner"))
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Significância Pós-Hoc (-log10 p-ajustado)"),
        plotly::plotlyOutput(ns("plot_tests"), height = "400px")
      ),
      bslib::card(
        bslib::card_header("Tabela de Comparações Pareadas"),
        DT::DTOutput(ns("table_tests"))
      )
    )
  )
}

mod_tab_09_server <- function(id, companies_df) {
  shiny::moduleServer(id, function(input, output, session) {
    test_res_r <- shiny::reactive({
      res <- run_nonparametric_tests(
        companies_df,
        group_col = input$group_factor,
        p_adjust_method = input$p_adjust,
        top_k = 6L
      )
      shiny::validate(shiny::need(!is.null(res), "Não foi possível executar o teste para este fator."))
      res
    })

    output$omnibus_banner <- shiny::renderUI({
      om <- test_res_r()$omnibus
      p_txt <- if (om$p_valor < 1e-4) "< 0,0001" else sprintf("%.4f", om$p_valor)
      shiny::div(
        class = "alert alert-primary py-2 px-3",
        shiny::HTML(sprintf(
          "<strong>Teste Omnibus (%s):</strong> H = %s | gl = %d | p-valor %s | <strong>Tamanho de efeito (&epsilon;&sup2;)</strong> = %.4f",
          om$teste,
          format(round(om$estatistica_h, 2), big.mark = ".", decimal.mark = ","),
          as.integer(om$gl),
          p_txt,
          om$epsilon_quadrado
        ))
      )
    })

    output$plot_tests <- plotly::renderPlotly({
      pw <- test_res_r()$pairwise
      alpha_num <- as.numeric(input$alpha)
      thresh <- -log10(alpha_num)

      pw_plot <- pw |>
        dplyr::slice_head(n = 15L) |>
        dplyr::mutate(
          par = paste(stringr::str_trunc(.data$grupo_1, 18), "vs.", stringr::str_trunc(.data$grupo_2, 18)),
          neg_log10_p = -log10(pmax(.data$p_ajustado, 1e-300)),
          significativo = ifelse(.data$p_ajustado < alpha_num, "Significativo", "Não significativo"),
          par = factor(.data$par, levels = rev(.data$par))
        )

      p <- plotly::plot_ly(
        data = pw_plot,
        x = ~neg_log10_p,
        y = ~par,
        type = "bar",
        orientation = "h",
        color = ~significativo,
        colors = c("Significativo" = PRIMARY_COLOR, "Não significativo" = MUTED_COLOR),
        hovertemplate = "<b>%{y}</b><br>-log10(p_adj): %{x:.2f}<extra></extra>"
      ) |>
        plotly::layout(
          shapes = list(
            list(
              type = "line", x0 = thresh, x1 = thresh, y0 = 0, y1 = 1,
              yref = "paper", line = list(color = ACCENT_COLOR, dash = "dash", width = 2)
            )
          )
        )

      style_plotly(p, title = "Força da Evidência Pós-Hoc (-log10 p-ajustado)", xlab = "-log10(p_ajustado)", ylab = "")
    })

    output$table_tests <- DT::renderDT({
      alpha_num <- as.numeric(input$alpha)
      tab <- test_res_r()$pairwise |>
        dplyr::transmute(
          `Grupo 1` = stringr::str_trunc(.data$grupo_1, 22),
          `Grupo 2` = stringr::str_trunc(.data$grupo_2, 22),
          `Mediana 1` = format_brl(.data$mediana_1, compact = TRUE),
          `Mediana 2` = format_brl(.data$mediana_2, compact = TRUE),
          `p-ajustado` = ifelse(.data$p_ajustado < 1e-4, "< 0,0001", sprintf("%.4f", .data$p_ajustado)),
          Decisão = ifelse(.data$p_ajustado < alpha_num, "Rejeita H0", "Não rejeita H0")
        )
      build_dt_table(tab, page_len = 10L)
    })
  })
}
