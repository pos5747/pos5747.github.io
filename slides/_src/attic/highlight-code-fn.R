highlight_code <- function(
    in_file = "script.R",
    out_file = "script.html",
    language = "r",
    theme = NULL,
    custom_css = NULL,
    open_browser = TRUE
) {
  # 1. Read code
  code <- paste(readLines(in_file), collapse = "\n")
  
  # 2. Choose stylesheet:
  if (is.null(theme) && is.null(custom_css)) {
    stop("Either 'theme' or 'custom_css' must be provided.")
  }
  stylesheet_tag <- if (!is.null(custom_css)) {
    htmltools::tags$style(custom_css)
  } else {
    htmltools::tags$link(
      rel = "stylesheet",
      href = paste0(
        "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/",
        theme,
        ".min.css"
      )
    )
  }
  
  # 3. Build HTML
  html_page <- htmltools::tags$html(
    htmltools::tags$head(
      stylesheet_tag,
      htmltools::tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"),
      htmltools::tags$script("hljs.highlightAll();")
    ),
    htmltools::tags$body(
      htmltools::tags$pre(
        htmltools::HTML(paste0("<code class=\"language-", language, "\">", code, "</code>"))
      )
    )
  )
  
  # 4. Save & Optionally open
  htmltools::save_html(html_page, file = out_file)
  message("Highlighted code saved to ", out_file)
  if (open_browser) {
    browseURL(normalizePath(out_file))
  }
}

# Custom theme example
custom_theme <- "\n.hljs {\n  background: transparent;\n  color: black;\n}\n\n.hljs-comment,\n.hljs-quote,\n.hljs-variable {\n  color: #e41a1c;\n}\n\n.hljs-keyword,\n.hljs-selector-tag,\n.hljs-built_in,\n.hljs-name,\n.hljs-tag {\n  color: #377eb8;\n}\n\n.hljs-string,\n.hljs-title,\n.hljs-section,\n.hljs-attribute,\n.hljs-literal,\n.hljs-template-tag,\n.hljs-template-variable,\n.hljs-type,\n.hljs-addition {\n  color: #4daf4a;\n}\n\n.hljs-deletion,\n.hljs-selector-attr,\n.hljs-selector-pseudo,\n.hljs-meta {\n  color: #377eb8;\n}\n\n.hljs-doctag {\n  color: #808080;\n}\n\n.hljs-attr {\n  color: #e41a1c;\n}\n\n.hljs-symbol,\n.hljs-bullet,\n.hljs-link {\n  color: #377eb8;\n}\n\n.hljs-emphasis {\n  font-style: italic;\n}\n\n.hljs-strong {\n  font-weight: bold;\n}\n"

# Example usage:
# highlight_code(
#   in_file = "script.R",
#   out_file = "script.html",
#   language = "r",
#   custom_css = custom_theme
# )






highlight_code("wk00/slides-material/R/illustrate-plot-styles.R", 
               "wk00/slides-material/colorized-code/illustrate-plot-styles.html", 
               custom_css = custom_theme)
