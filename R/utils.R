

# utility functions-----------------------------------------------------------------------------------------------------

# return character matrix of formatted contents, suitably escaped
clean_contents <- function(ht, type = c('latex', 'html', 'screen', 'markdown', 'word'), ...) {
  mytype <- match.arg(type)
  contents <- as.matrix(as.data.frame(ht))

  for (col in 1:ncol(contents)) {
    for (row in 1:nrow(contents)) {
      cell <- contents[row, col]
      if (is_a_number(cell)) {
        cell <- as.numeric(cell)
        cell <- format_number(cell, number_format(ht)[[row, col]]) # a list element, double brackets needed
      }
      if (is.na(cell)) cell <- na_string(ht)[row, col]

      contents[row, col] <- cell
    }
    contents[, col] <- decimal_pad(contents[, col], pad_decimal(ht)[,col])
    if (type %in% c('latex', 'html')) {
      # xtable::sanitize.numbers would do very little and is buggy
      to_esc <- escape_contents(ht)[, col]
      contents[to_esc, col] <-  xtable::sanitize(contents[to_esc, col], type)
    }
  }

  contents
}

# compute_real_borders <- function (ht) {
#   borders <- matrix(0, nrow(ht) + 1, ncol(ht) + 1)
#   # borders[y, x] gives the border above row y and left of col x
#   dcells <- display_cells(ht, all = FALSE)
#   dcells <- dcells[!dcells$shadowed,]
#   for (i in seq_along(nrow(dcells))) {
#     dcr <- dcells[i,]
#     pos <- list(
#           left   = list(dcr$display_row:dcr$end_row, dcr$display_col),
#           right  = list(dcr$display_row:dcr$end_row, dcr$end_col + 1),
#           top    = list(dcr$display_row, dcr$display_col:dcr$end_col),
#           bottom = list(dcr$end_row + 1, dcr$display_col:dcr$end_col)
#         )
#     bords <- get_all_borders(ht, dcr$display_row, dcr$display_col)
#     bords <- bords[names(pos)] # safety
#     f <- function(pos, bords) {
#       borders[ pos[[1]], pos[[2]] ] <- pmax(borders[ pos[[1]], pos[[2]] ], bords)
#     }
#     mapply(f, pos, bords)
#   }
#
#   borders
# }


get_all_borders <- function(ht, row, col) {
  list(
          left   = left_border(ht)[row, col],
          right  = right_border(ht)[row, col],
          top    = top_border(ht)[row, col],
          bottom = bottom_border(ht)[row, col]
        )
}


format_number <- function (num, nf) {
  res <- num
  if (is.function(nf)) res[] <- nf(num)
  if (is.character(nf)) res[] <- sprintf(nf, num)
  if (is.numeric(nf)) res[] <- formatC(round(num, nf), format = 'f', digits = nf)
  res[is.na(num)] <- NA

  res
}

decimal_pad <- function(col, pad_chars) {
  # where pad_chars is NA we do not pad
  orig_col  <- col
  na_pad    <- is.na(pad_chars)
  col       <- col[! na_pad]
  pad_chars <- pad_chars[! na_pad]
  if (length(col) == 0) return(orig_col)

  find_pos  <- function(string, char) {
    regex <- gregexpr(char, string, fixed = TRUE)[[1]]
    regex[length(regex)]
  }
  pos <- mapply(find_pos, col, pad_chars)
  nchars <- nchar(col, type = 'width')
  # take the biggest distance from the decimal point
  pos[pos == -1L] <- nchars[pos == -1L] + 1
  chars_after_. <- nchars - pos

  pad_to <- max(chars_after_.) - chars_after_.
  col <- paste0(col, str_rep(' ', pad_to))

  orig_col[! na_pad] <- col
  orig_col
}

# return data frame mapping real cell positions to cells displayed
display_cells <- function(ht, all = TRUE, new_rowspan = rowspan(ht), new_colspan = colspan(ht)) {
  dcells <- data.frame(row = rep(1:nrow(ht), ncol(ht)), col = rep(1:ncol(ht), each = nrow(ht)),
    rowspan = as.vector(new_rowspan), colspan = as.vector(new_colspan))
  dcells$display_row <- dcells$row
  dcells$display_col <- dcells$col
  dcells$shadowed <- FALSE

  change_cols <- c('display_row', 'display_col', 'rowspan', 'colspan')
  for (i in 1:nrow(dcells)) {
    if (dcells$rowspan[i] == 1 && dcells$colspan[i] == 1) next
    if (dcells$shadowed[i]) next

    dr <- dcells$row[i]
    dc <- dcells$col[i]
    spanned <- dcells$row %in% dr:(dr + dcells$rowspan[i] - 1) & dcells$col %in% dc:(dc + dcells$colspan[i] - 1)
    dcells[spanned, change_cols] <- matrix(as.numeric(dcells[i, change_cols]), sum(spanned), length(change_cols), byrow = TRUE)

    shadowed <- spanned & (1:nrow(dcells)) != i
    dcells$shadowed[shadowed] <- TRUE
  }
  dcells$end_row <- dcells$display_row + dcells$rowspan - 1
  dcells$end_col <- dcells$display_col + dcells$colspan - 1

  if (! all) dcells <- dcells[! dcells$shadowed, ]

  dcells
}


#' Set Default Print Method
#'
#' You can change the default print method for huxtable objects. This
#' allows you to print huxtables appropriately, in e.g. knitr documents, simply
#' by evaluating the huxtable object.
#'
#' @param method Print method to use for huxtable objects.
#'
#' @return \code{NULL}
#' @export
#'
#' @examples
#' \dontrun{
#' # inside a knitr HTML document:
#' set_print_method(print_html)
#' }
set_print_method <- function(method) {
  if (is.character(method)) method <- eval(as.symbol(method))
  print.huxtable <<- method
  NULL
}

#' Guess Knitr Output Format
#'
#' Convenience function which tries to guess the ultimate output from knitr and rmarkdown.
#'
#' @return 'html', 'latex' or something else
#' @export
#'
#' @examples
#' \dontrun{
#' # in a knitr document
#' guess_knitr_output_format()
#' }
guess_knitr_output_format <- function() {
  of <- knitr::opts_knit$get('out.format')
  if (of == 'markdown') {
    of <- knitr::opts_knit$get('rmarkdown.pandoc.to')
    if (is.null(of)) {
      of <- rmarkdown::default_output_format(knitr::current_input())
      of <- of$name
      of <- sub('_.*', '', of)
      if (of %in% c('ioslides', 'revealjs', 'slidy')) of <- 'html'
    }
  }
  if (of == 'pdf') of <- 'latex'
  of
}


#' Huxtable Logo
#'
#' @param latex Use LaTeX names for fonts.
#' @return The huxtable logo
#' @export
#'
#' @examples
#' print_screen(hux_logo())
#'
hux_logo <- function(latex = FALSE) {
  logo <- hux(c('h', NA), c('u', 'table'), c('x', NA))
  rowspan(logo)[1, 1] <- 2
  colspan(logo)[2, 2] <- 2
  logo <- set_all_borders(logo, , ,1)
  font_size(logo) <- if (latex) 12 else 20
  font_size(logo)[1, 2:3] <- if (latex) 16 else 24
  font_size(logo)[1, 1] <-  if (latex) 28 else 42
  background_color(logo)[1, 1] <- '#e83abc'
  background_color(logo)[1, 3] <- 'black'
  text_color(logo)[1, 3] <- 'white'
  width(logo) <- if (latex) 0.2 else '60pt'
  height(logo) <- if (latex) '40pt' else '60pt'
  font(logo) <- 'Palatino, Palatino Linotype, Palatino LT STD, Book Antiqua, Georgia, serif'
  if (latex) font(logo) <- 'ppl'
  #set_all_padding(logo, , , 6)
  top_padding(logo) <- 2
  bottom_padding(logo) <- 2
  col_width(logo) <- c(.4, .3, .3)
  #left_padding(logo)[1, 1] <- 10
  position(logo) <- 'center'
  logo
}