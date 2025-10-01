# app.R
# Beta Explorer — deployment-safe fonts, bigger readable plots, and exact numeric entries under sliders

library(shiny)
library(ggplot2)
library(tibble)
library(scales)
library(DT)

# Robust, deployment-safe font pipeline for plots
library(sysfonts)  # font_add()
library(showtext)  # showtext_auto()
library(ragg)      # crisp PNG exports

# ------------------------ Constants (styling & sizes) -----------------------

# UI uses web CSS font (loaded in <head>); plots register same font from local files.
PLOT_FONT_FAMILY_NAME <- "Source Sans 3"
FALLBACK_FAMILY       <- "sans"  # used if local font not found

# Plot text sizing (explicit; do NOT use base_size to avoid scaling lines)
P_TITLE  <- 28
P_SUB    <- 20
P_AXTIT  <- 18
P_AXTXT  <- 16
P_LEGEND <- 16

# Line weights
LINE_MAIN <- 0.9  # curve
LINE_MEAN <- 0.8  # mean vline
LINE_REF  <- 0.5  # dotted refs

# Colors
MEAN_COLOR <- "#0072B2" # Okabe–Ito blue (colorblind-safe)

# On-screen render sizes (match CSS to avoid downscaling tiny text)
RES_SCREEN  <- 96
PLOT_W_PX   <- 900
PLOT_H_PX   <- 540

# Domain for alpha/beta
AB_MIN <- 0.05
AB_MAX <- 50
AB_STEP <- 0.01

# ------------------------ Safe font registration for plots ------------------

# Try to register local TTFs if present; otherwise fall back to system 'sans'
plot_family <- FALLBACK_FAMILY
try({
  reg_path  <- "www/fonts/SourceSans3-Regular.ttf"
  bold_path <- "www/fonts/SourceSans3-SemiBold.ttf"  # or -Bold.ttf
  if (file.exists(reg_path)) {
    sysfonts::font_add(family = PLOT_FONT_FAMILY_NAME, regular = reg_path,
                       bold = if (file.exists(bold_path)) bold_path else reg_path)
    plot_family <- PLOT_FONT_FAMILY_NAME
  }
}, silent = TRUE)

# Enable showtext (works with both custom & system fonts)
showtext_auto()
showtext_opts(dpi = RES_SCREEN)

# ------------------------ Global ggplot theme (explicit sizes) --------------

theme_set(
  theme_minimal(base_family = plot_family) +
    theme(
      plot.title    = element_text(size = P_TITLE, face = "bold", margin = margin(b = 4)),
      plot.subtitle = element_text(size = P_SUB,   margin = margin(t = 2, b = 10)),
      axis.title    = element_text(size = P_AXTIT, margin = margin(t = 2, r = 4)),
      axis.text     = element_text(size = P_AXTXT),
      legend.title  = element_blank(),
      legend.text   = element_text(size = P_LEGEND),
      legend.position = "right"
    )
)

# ------------------------ Helpers -------------------------------------------

beta_xgrid <- function(alpha, beta) {
  x <- c(seq(0, .02, length.out = 200),
         seq(.02, .98, length.out = 600),
         seq(.98, 1,   length.out = 200))
  unique(pmin(pmax(x, 0), 1))
}

fmt_dec <- function(x, k = 2) sprintf(paste0("%.", k, "f"), x)

beta_summaries <- function(alpha, beta, probs = c(.05,.10,.25,.50,.75,.90,.95)) {
  stopifnot(is.finite(alpha), is.finite(beta), alpha > 0, beta > 0)
  mu  <- alpha / (alpha + beta)
  var <- (alpha * beta) / ((alpha + beta)^2 * (alpha + beta + 1))
  sdv <- sqrt(var)
  qs  <- qbeta(probs, alpha, beta)
  list(alpha = alpha, beta = beta, mu = mu, var = var, sd = sdv,
       k = alpha + beta, probs = probs, quant = qs)
}

cap_pdf_y <- function(y) {
  yf <- y[is.finite(y)]
  if (!length(yf)) return(10)
  min(max(yf), 1e3)
}

alpha_beta_from_mean_sd <- function(mu, sd) {
  if (!is.finite(mu) || !is.finite(sd) || mu <= 0 || mu >= 1 || sd <= 0) {
    return(list(ok = FALSE, msg = "Mean must be in (0,1) and SD > 0."))
  }
  v <- sd^2
  vmax <- mu * (1 - mu)
  if (v >= vmax) {
    return(list(ok = FALSE, msg = sprintf("SD too large for this mean. Max SD is %s.", fmt_dec(sqrt(vmax)))))
  }
  kappa <- vmax / v - 1
  if (kappa <= 0) return(list(ok = FALSE, msg = "Infeasible (κ ≤ 0)."))
  list(ok = TRUE,
       alpha = mu * kappa,
       beta  = (1 - mu) * kappa,
       msg   = sprintf("α≈%s, β≈%s (κ≈%s)", fmt_dec(mu * kappa), fmt_dec((1 - mu) * kappa), fmt_dec(kappa)))
}

# ------------------------ Plot builders (simple & consistent) ---------------

build_pdf_plot <- function(df, s, y_cap) {
  ggplot(df, aes(x, pdf)) +
    geom_line(linewidth = LINE_MAIN) +
    geom_vline(xintercept = s$mu, color = MEAN_COLOR, linewidth = LINE_MEAN) +
    coord_cartesian(xlim = c(0,1), ylim = c(0, y_cap)) +
    labs(
      title = "Beta PDF",
      x = "x", y = "Density",
      subtitle = sprintf("α=%s, β=%s  •  Mean=%s  •  SD=%s",
                         fmt_dec(s$alpha), fmt_dec(s$beta), fmt_dec(s$mu), fmt_dec(s$sd))
    )
}

build_cdf_plot <- function(df, s, probs_show = c(.10,.50,.90)) {
  qv <- tibble(p = probs_show, q = qbeta(probs_show, s$alpha, s$beta))
  ggplot(df, aes(x, cdf)) +
    geom_line(linewidth = LINE_MAIN) +
    geom_hline(data = qv, aes(yintercept = p), linetype = "dotted", linewidth = LINE_REF) +
    geom_vline(data = qv, aes(xintercept = q), linetype = "dotted", linewidth = LINE_REF) +
    geom_vline(xintercept = s$mu, color = MEAN_COLOR, linewidth = LINE_MEAN) +
    coord_cartesian(xlim = c(0,1), ylim = c(0,1)) +
    labs(
      title = "Beta CDF",
      x = "x", y = "Cumulative Probability",
      subtitle = sprintf("α=%s, β=%s  •  Mean=%s  •  SD=%s",
                         fmt_dec(s$alpha), fmt_dec(s$beta), fmt_dec(s$mu), fmt_dec(s$sd))
    )
}

# ------------------------ UI ------------------------------------------------

ui <- fluidPage(
  # Fonts + CSS + MathJax config (configure BEFORE withMathJax)
  tags$head(
    tags$link(rel="preconnect", href="https://fonts.googleapis.com"),
    tags$link(rel="preconnect", href="https://fonts.gstatic.com", crossorigin="crossorigin"),
    tags$link(
      rel="stylesheet",
      href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;600;700&display=swap"
    ),
    tags$style(HTML("
      :root {
        --app-font: 'Source Sans 3', -apple-system, BlinkMacSystemFont, 'Segoe UI',
                    Roboto, 'Helvetica Neue', Arial, 'Noto Sans', 'Liberation Sans', sans-serif;
      }
      html, body, .container-fluid { font-family: var(--app-font); font-size: 16px; line-height: 1.45; }
      h1,h2,h3,h4,h5,h6, .navbar, .nav-tabs>li>a { font-weight: 600; letter-spacing: 0.1px; }
      .form-control, .btn, .shiny-input-container { font-family: var(--app-font); }
      table.dataTable, table.dataTable th, table.dataTable td { font-family: var(--app-font); font-size: 0.95rem; }
      .tooltip-inner { font-family: var(--app-font); font-size: 0.9rem; }
      mjx-container { line-height: 1.25; }
      p + mjx-container, mjx-container + p { margin-top: 0.35rem; margin-bottom: 0.35rem; }
      .shiny-plot-output { font-family: var(--app-font); }
    ")),
    # MathJax v3 for equations (prose uses Unicode α/β)
    tags$script(HTML("
      window.MathJax = {
        chtml: { font: 'STIX-Web', scale: 1 },
        svg:   { fontCache: 'global' },
        tex:   { packages: {'[+]': ['ams']}, inlineMath: [['\\\\(','\\\\)'], ['$', '$']] }
      };
    "))
  ),
  
  titlePanel("Explore the Beta Distribution"),
  withMathJax(),
  
  sidebarLayout(
    sidebarPanel(
      tags$strong("Shape Parameters"),
      # Alpha slider + exact numeric entry directly beneath
      sliderInput(
        "alpha",
        tagList(
          HTML("&alpha;"),
          tags$span(
            icon("question-circle"),
            title = "Larger α increases weight near 1; α<1 creates a spike at 0.",
            style = "margin-left:6px; cursor:help; color:#6c757d;"
          )
        ),
        min = AB_MIN, max = AB_MAX, value = 2, step = AB_STEP
      ),
      numericInput("alpha_exact", "Alpha (exact)", value = 2, min = AB_MIN, max = AB_MAX, step = AB_STEP),
      
      # Beta slider + exact numeric entry directly beneath
      sliderInput(
        "beta",
        tagList(
          HTML("&beta;"),
          tags$span(
            icon("question-circle"),
            title = "Larger β increases weight near 0; β<1 creates a spike at 1.",
            style = "margin-left:6px; cursor:help; color:#6c757d;"
          )
        ),
        min = AB_MIN, max = AB_MAX, value = 2, step = AB_STEP
      ),
      numericInput("beta_exact", "Beta (exact)", value = 2, min = AB_MIN, max = AB_MAX, step = AB_STEP),
      
      tags$hr(),
      tags$strong("Presets"),
      fluidRow(
        column(6, actionButton("preset_uniform",     "Uniform (1, 1)")),
        column(6, actionButton("preset_ushape",      "U-shape (0.5, 0.5)"))
      ),
      fluidRow(
        column(6, actionButton("preset_rightskew",   "Right-skew (2, 10)")),
        column(6, actionButton("preset_leftskew",    "Left-skew (10, 2)"))
      ),
      fluidRow(
        column(6, actionButton("preset_concentrated","Mound (20, 20)"))
      ),
      tags$hr(),
      tags$strong("Set α, β from Targets"),
      div(style="margin: 2px 0 6px 0; color:#6c757d; font-size: 90%;",
          "Enter Mean and SD, then click Preview."
      ),
      fluidRow(
        column(6, numericInput("mean_target", "Mean", value = 0.50, min = 0.0001, max = 0.9999, step = 0.01)),
        column(6, numericInput("sd_target",   "SD",   value = 0.10, min = 0.0001, max = 0.5,    step = 0.01))
      ),
      div(style="margin-top: 4px;", actionButton("preview_ms", "Preview")),
      div(style="margin: 6px 0 4px 0; color:#6c757d; font-size: 90%;",
          "Click Apply to use these values of α and β."
      ),
      div(style="margin-bottom: 6px;", actionButton("apply_ms", "Apply")),
      div(style="margin: 6px 0; color:#6c757d;", textOutput("ms_preview", inline = TRUE)),
      tags$hr(),
      downloadButton("download_png", "Save Current Plot (PNG)"),
      width = 3
    ),
    mainPanel(
      tabsetPanel(id = "tabs",
                  tabPanel("PDF",
                           uiOutput("boundary_note"),
                           plotOutput("pdf_plot", height = PLOT_H_PX)
                  ),
                  tabPanel("CDF",
                           plotOutput("cdf_plot", height = PLOT_H_PX),
                           br(),
                           DTOutput("quant_table")
                  ),
                  tabPanel("Simulations",
                           p("One hundred simulated draws from the current Beta(α, β), rounded to two decimals."),
                           DTOutput("sim_table")
                  ),
                  tabPanel("Summaries",
                           uiOutput("summary_text")
                  ),
                  tabPanel("Learn",
                           tags$h4("What is Beta(α, β)?"),
                           tags$ul(
                             tags$li(HTML("PDF: \\( f(x|\\alpha,\\beta)=\\dfrac{x^{\\alpha-1}(1-x)^{\\beta-1}}{B(\\alpha,\\beta)} \\), \\( 0 < x < 1 \\).")),
                             tags$li(HTML("CDF: \\( F(x|\\alpha,\\beta)=I_x(\\alpha,\\beta) \\) (regularized incomplete beta).")),
                             tags$li(HTML("Mean: \\( \\alpha/(\\alpha+\\beta) \\); Variance: \\( \\alpha\\beta /[(\\alpha+\\beta)^2(\\alpha+\\beta+1)] \\)."))
                           ),
                           p("Shape rules: α=β=1 is uniform; α,β<1 is U-shaped (boundary spikes); α,β>1 is mound-shaped; α≫β puts mass near 1; β≫α puts mass near 0."),
                           tags$h5("Reading Quantiles from the CDF"),
                           p("To find qₚ: go to y = p, move horizontally to the curve, then down to x.")
                  )
      )
    )
  )
)

# ------------------------ Server -------------------------------------------

server <- function(input, output, session) {
  
  # Utility
  clamp <- function(x, lo, hi) max(lo, min(hi, x))
  
  # Guard invalid slider inputs
  observeEvent(input$alpha, {
    if (isTruthy(input$alpha) && input$alpha <= 0) {
      showNotification("α must be > 0; set to 0.05.", type = "warning", duration = 3)
      updateSliderInput(session, "alpha", value = AB_MIN)
    }
  }, ignoreInit = TRUE)
  observeEvent(input$beta, {
    if (isTruthy(input$beta) && input$beta <= 0) {
      showNotification("β must be > 0; set to 0.05.", type = "warning", duration = 3)
      updateSliderInput(session, "beta", value = AB_MIN)
    }
  }, ignoreInit = TRUE)
  
  # ---- Synchronize sliders ⇄ numeric inputs (Option A) ---------------------
  
  # Slider → numeric (mirrors current value, rounded to 2 decimals)
  observeEvent(input$alpha, ignoreInit = TRUE, {
    updateNumericInput(session, "alpha_exact", value = round(input$alpha, 2))
  })
  observeEvent(input$beta, ignoreInit = TRUE, {
    updateNumericInput(session, "beta_exact", value = round(input$beta, 2))
  })
  
  # Numeric → slider (validate + clamp to [AB_MIN, AB_MAX])
  observeEvent(input$alpha_exact, ignoreInit = TRUE, {
    val <- clamp(as.numeric(input$alpha_exact), AB_MIN, AB_MAX)
    if (!isTRUE(all.equal(val, input$alpha))) {
      freezeReactiveValue(input, "alpha")
      updateSliderInput(session, "alpha", value = val)
    }
  })
  observeEvent(input$beta_exact, ignoreInit = TRUE, {
    val <- clamp(as.numeric(input$beta_exact), AB_MIN, AB_MAX)
    if (!isTRUE(all.equal(val, input$beta))) {
      freezeReactiveValue(input, "beta")
      updateSliderInput(session, "beta", value = val)
    }
  })
  
  # Presets
  observeEvent(input$preset_uniform, {
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = 1)
    updateSliderInput(session, "beta",  value = 1)
  }, ignoreInit = TRUE)
  observeEvent(input$preset_ushape, {
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = 0.5)
    updateSliderInput(session, "beta",  value = 0.5)
  }, ignoreInit = TRUE)
  observeEvent(input$preset_rightskew, {
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = 2)
    updateSliderInput(session, "beta",  value = 10)
  }, ignoreInit = TRUE)
  observeEvent(input$preset_leftskew, {
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = 10)
    updateSliderInput(session, "beta",  value = 2)
  }, ignoreInit = TRUE)
  observeEvent(input$preset_concentrated, {
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = 20)
    updateSliderInput(session, "beta",  value = 20)
  }, ignoreInit = TRUE)
  
  # Debounce sliders for downstream calculations
  alpha_d <- debounce(reactive(input$alpha), 200)
  beta_d  <- debounce(reactive(input$beta),  200)
  
  # Summaries and data
  summ <- reactive({
    req(alpha_d(), beta_d())
    beta_summaries(alpha_d(), beta_d())
  })
  pdf_data <- reactive({
    x <- beta_xgrid(alpha_d(), beta_d())
    tibble(x = x, pdf = dbeta(x, alpha_d(), beta_d()))
  })
  cdf_data <- reactive({
    x <- seq(0, 1, length.out = 1000)
    tibble(x = x, cdf = pbeta(x, alpha_d(), beta_d()))
  })
  
  output$boundary_note <- renderUI({
    s <- summ()
    if (s$alpha < 1 || s$beta < 1) {
      div(style = "margin-bottom:6px; color:#6c757d;",
          "Note: density diverges at the boundary; axis is capped for visibility.")
    }
  })
  
  # Plots (render at same pixel size as container)
  output$pdf_plot <- renderPlot({
    s <- summ()
    df <- pdf_data()
    ycap <- cap_pdf_y(df$pdf)
    build_pdf_plot(df, s, y_cap = ycap)
  }, res = RES_SCREEN, width = PLOT_W_PX, height = PLOT_H_PX)
  
  output$cdf_plot <- renderPlot({
    s <- summ()
    df <- cdf_data()
    build_cdf_plot(df, s)
  }, res = RES_SCREEN, width = PLOT_W_PX, height = PLOT_H_PX)
  
  # Tables
  output$quant_table <- renderDT({
    s <- summ()
    datatable(
      tibble(Probability = percent(s$probs), Quantile = fmt_dec(s$quant, 2)),
      rownames = FALSE, options = list(dom = 't', ordering = FALSE), class = "compact"
    )
  })
  
  output$sim_table <- renderDT({
    s <- summ()
    M <- matrix(round(rbeta(100, s$alpha, s$beta), 2), nrow = 10, ncol = 10, byrow = TRUE)
    datatable(as.data.frame(M), rownames = FALSE, colnames = rep("", ncol(M)),
              options = list(dom = 't', ordering = FALSE), class = "compact")
  })
  
  # Narrative summaries
  output$summary_text <- renderUI({
    s <- summ()
    q <- setNames(s$quant, paste0("p", sprintf("%02d", round(100*s$probs))))
    getq <- function(nm) if (nm %in% names(q)) q[[nm]] else NA_real_
    Q10 <- fmt_dec(getq("p10")); Q90 <- fmt_dec(getq("p90"))
    Q25 <- fmt_dec(getq("p25")); Q75 <- fmt_dec(getq("p75"))
    IQRv <- fmt_dec(as.numeric(getq("p75") - getq("p25")))
    shape_note <- NULL
    if (s$alpha < 1 || s$beta < 1) {
      side <- if (s$alpha < 1 && s$beta < 1) "both boundaries" else if (s$alpha < 1) "0" else "1"
      shape_note <- p("The PDF diverges at the boundary (spike at ", side, ").")
    }
    tagList(
      h4("Parameters (α, β)"),
      p("For this selection, α = ", fmt_dec(s$alpha),
        " and β = ", fmt_dec(s$beta),
        " (concentration α+β = ", fmt_dec(s$k), ")."),
      h4("Center & Spread"),
      p("The mean is ", fmt_dec(s$mu),
        " and the standard deviation is ", fmt_dec(s$sd), "."),
      h4("Middle 80% (Equal-Tailed)"),
      p("From the 10th to the 90th percentile, the distribution runs from ", Q10, " to ", Q90, "."),
      h4("Interquartile Range (IQR)"),
      p("The 25th to 75th percentile spans from ", Q25, " to ", Q75, " (IQR = ", IQRv, ")."),
      if (!is.null(shape_note)) tagList(h4("Shape Note"), shape_note)
    )
  })
  
  # Mean & SD helper
  ms_result <- reactiveVal(NULL)
  observeEvent(input$preview_ms, {
    ms_result(alpha_beta_from_mean_sd(input$mean_target, input$sd_target))
  })
  output$ms_preview <- renderText({
    res <- ms_result()
    if (is.null(res)) return("")
    if (isTRUE(res$ok)) paste("Preview:", res$msg) else paste("Problem:", res$msg)
  })
  observeEvent(input$apply_ms, {
    res <- ms_result()
    if (is.null(res) || !isTRUE(res$ok)) {
      showNotification("No feasible (α, β) to apply. Preview first or adjust targets.", type="error")
      return(NULL)
    }
    freezeReactiveValue(input, "alpha"); freezeReactiveValue(input, "beta")
    updateSliderInput(session, "alpha", value = res$alpha)
    updateSliderInput(session, "beta",  value = res$beta)
    showNotification("Applied α, β from Mean & SD.", type="message")
  })
  
  # Downloads (print-friendly; same fonts/colors)
  output$download_png <- downloadHandler(
    filename = function() sprintf("beta-%s_a%s_b%s.png", tolower(input$tabs), fmt_dec(alpha_d()), fmt_dec(beta_d())),
    content = function(file) {
      s <- summ()
      g <- if (identical(input$tabs, "CDF")) {
        build_cdf_plot(cdf_data(), s)
      } else {
        df <- pdf_data(); build_pdf_plot(df, s, y_cap = cap_pdf_y(df$pdf))
      }
      ragg::agg_png(filename = file, width = 10, height = 6, units = "in", res = 150)
      print(g); dev.off()
    }
  )
}

shinyApp(ui, server)
