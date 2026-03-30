# %% repr ----
repr <- new_generic("repr", "x")


# %% to_base ----
to_base <- new_generic("to_base", "x")


# %% to_json ----
to_json <- new_generic("to_json", "x")


# %% fmt ----
#' Get output type
#'
#' Get output type for printing text.
#'
#' @param output_type Character vector of output types.
#' @param filename Optional Character: Filename for output.
#'
#' @details
#' Exported as internal function for use by other rtemis packages.
#'
#' @return Character with selected output type.
#'
#' @author EDG
#'
#' @noRd
#' @examples
#' get_output_type()
get_output_type <- function(
  output_type = c("ansi", "html", "plain"),
  filename = NULL
) {
  if (!is.null(filename)) {
    return("plain")
  }

  if (is.null(output_type)) {
    if (interactive()) {
      return("ansi")
    } else {
      return("plain")
    }
  }

  match.arg(output_type)
}


#' Text formatting
#'
#' Formats text with specified color, styles, and background using ANSI escape codes or HTML, with
#' support for plain text output.
#'
#' @param x Character: Text to format.
#' @param col Character: Color (hex code, named color, or NULL for no color).
#' @param bold Logical: If TRUE, make text bold.
#' @param italic Logical: If TRUE, make text italic.
#' @param underline Logical: If TRUE, underline text.
#' @param thin Logical: If TRUE, make text thin/light.
#' @param muted Logical: If TRUE, make text muted/dimmed.
#' @param bg Character: Background color (hex code, named color, or NULL).
#' @param pad Integer: Number of spaces to pad before text.
#' @param output_type Character: Output type ("ansi", "html", "plain").
#'
#' @return Character: Formatted text with specified styling.
#'
#' @details
#' This function combines multiple formatting options into a single call,
#' making it more efficient than nested function calls. It generates
#' optimized ANSI escape sequences and clean HTML output.
#'
#' @author EDG
#' @noRd
#'
#' @examples
#' # Simple color
#' fmt("Hello", col = "red")
#'
#' # Bold red text
#' fmt("Error", col = "red", bold = TRUE)
#'
#' # Multiple styles
#' fmt("Warning", col = "yellow", bold = TRUE, italic = TRUE)
#'
#' # With background
#' fmt("Highlight", col = "white", bg = "blue", bold = TRUE)
fmt <- function(
  x,
  col = NULL,
  bold = FALSE,
  italic = FALSE,
  underline = FALSE,
  thin = FALSE,
  muted = FALSE,
  bg = NULL,
  pad = 0L,
  output_type = c("ansi", "html", "plain")
) {
  output_type <- match.arg(output_type)

  out <- switch(
    output_type,
    "ansi" = {
      codes <- character()

      # Style codes
      if (bold) {
        codes <- c(codes, "1")
      } else {
        # Explicitly set normal weight to override message() bold default
        codes <- c(codes, "22")
      }
      if (thin || muted) {
        codes <- c(codes, "2")
      } # Both use dim/faint
      if (italic) {
        codes <- c(codes, "3")
      }
      if (underline) {
        codes <- c(codes, "4")
      }

      # Foreground color
      if (!is.null(col)) {
        tryCatch(
          {
            col_rgb <- col2rgb(col)
            codes <- c(
              codes,
              paste0("38;2;", col_rgb[1], ";", col_rgb[2], ";", col_rgb[3])
            )
          },
          error = function(e) {
            warning("Invalid color '", col, "', ignoring color")
          }
        )
      }

      # Background color
      if (!is.null(bg)) {
        tryCatch(
          {
            bg_rgb <- col2rgb(bg)
            codes <- c(
              codes,
              paste0("48;2;", bg_rgb[1], ";", bg_rgb[2], ";", bg_rgb[3])
            )
          },
          error = function(e) {
            warning("Invalid background color '", bg, "', ignoring background")
          }
        )
      }

      # Generate ANSI sequence
      if (length(codes) > 0) {
        paste0("\033[", paste(codes, collapse = ";"), "m", x, "\033[0m")
      } else {
        x
      }
    },
    "html" = {
      styles <- character()

      # Colors
      if (!is.null(col)) {
        styles <- c(styles, paste0("color: ", col))
      }
      if (!is.null(bg)) {
        styles <- c(styles, paste0("background-color: ", bg))
      }

      # Styles
      if (bold) {
        styles <- c(styles, "font-weight: bold")
      }
      if (thin) {
        styles <- c(styles, "font-weight: lighter")
      }
      if (muted) {
        styles <- c(styles, "color: gray")
      } # Override color for muted
      if (italic) {
        styles <- c(styles, "font-style: italic")
      }
      if (underline) {
        styles <- c(styles, "text-decoration: underline")
      }

      # Generate HTML span
      if (length(styles) > 0) {
        paste0(
          '<span style="',
          paste(styles, collapse = "; "),
          '">',
          x,
          "</span>"
        )
      } else {
        x
      }
    },
    "plain" = x
  )
  if (pad > 0L) {
    out <- paste0(strrep(" ", pad), out)
  }
  out
}


#' Highlight text
#'
#' A `fmt()` convenience wrapper for highlighting text.
#'
#' @param x Character: Text to highlight.
#' @param pad Integer: Number of spaces to pad before text.
#' @param output_type Character: Output type ("ansi", "html", "plain").
#'
#' @return Character: Formatted text with highlight.
#'
#' @author EDG
#' @noRd
highlight <- function(
  x,
  pad = 0L,
  output_type = c("ansi", "html", "plain")
) {
  fmt(x, col = highlight_col, bold = TRUE, pad = pad, output_type = output_type)
}


#' Make text bold
#'
#' A `fmt()` convenience wrapper for making text bold.
#'
#' @param text Character: Text to make bold
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with bold styling
#'
#' @author EDG
#' @noRd
bold <- function(text, output_type = c("ansi", "html", "plain")) {
  fmt(text, bold = TRUE, output_type = output_type)
}


#' Make text italic
#'
#' A `fmt()` convenience wrapper for making text italic.
#'
#' @param text Character: Text to make italic
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with italic styling
#'
#' @author EDG
#' @noRd
italic <- function(text, output_type = c("ansi", "html", "plain")) {
  fmt(text, italic = TRUE, output_type = output_type)
}


#' Make text underlined
#'
#' A `fmt()` convenience wrapper for making text underlined.
#'
#' @param text Character: Text to underline
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with underline styling
#'
#' @author EDG
#' @noRd
underline <- function(text, output_type = c("ansi", "html", "plain")) {
  fmt(text, underline = TRUE, output_type = output_type)
}


#' Make text thin/light
#'
#' A `fmt()` convenience wrapper for making text thin/light.
#'
#' @param text Character: Text to make thin
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with thin/light styling
#'
#' @author EDG
#' @noRd
thin <- function(text, output_type = c("ansi", "html", "plain")) {
  fmt(text, thin = TRUE, output_type = output_type)
}


#' Muted text
#'
#' A `fmt()` convenience wrapper for making text muted.
#'
#' @param x Character: Text to format
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with muted styling
#'
#' @author EDG
#' @noRd
muted <- function(x, output_type = c("ansi", "html", "plain")) {
  fmt(x, muted = TRUE, output_type = output_type)
}


#' Gray text
#'
#' A `fmt()` convenience wrapper for making text gray.
#'
#' @param x Character: Text to format
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with gray styling
#'
#' @details
#' Can be useful in contexts where muted is not supported.
#'
#' @author EDG
#' @noRd
gray <- function(x, output_type = c("ansi", "html", "plain")) {
  fmt(x, col = "#808080", output_type = output_type)
}


#' Apply 256-color formatting
#'
#' @param text Character: Text to color
#' @param col Character or numeric: Color (ANSI 256-color code, hex for HTML)
#' @param bg Logical: If TRUE, apply as background color
#' @param output_type Character: Output type ("ansi", "html", "plain")
#'
#' @return Character: Formatted text with 256-color styling
#'
#' @author EDG
#' @noRd
col256 <- function(
  text,
  col = "79",
  bg = FALSE,
  output_type = c("ansi", "html", "plain")
) {
  output_type <- match.arg(output_type)

  switch(
    output_type,
    "ansi" = {
      if (bg) {
        paste0("\033[48;5;", col, "m", text, "\033[0m")
      } else {
        paste0("\033[38;5;", col, "m", text, "\033[0m")
      }
    },
    "html" = {
      # Convert ANSI color codes to hex colors if needed
      hex_col <- if (
        is.numeric(col) || (is.character(col) && !grepl("^#", col))
      ) {
        ansi256_to_hex(col)
      } else {
        col
      }
      if (bg) {
        paste0(
          '<span style="background-color: ',
          hex_col,
          '">',
          text,
          "</span>"
        )
      } else {
        paste0('<span style="color: ', hex_col, '">', text, "</span>")
      }
    },
    "plain" = text
  )
}


#' Convert ANSI 256 color code to HEX
#'
#' @param code Integer: ANSI 256 color code (0-255).
#' @return Character: HEX color string.
#' @author EDG
#' @noRd
ansi256_to_hex <- function(code) {
  code <- as.integer(code)
  if (is.na(code) || code < 0 || code > 255) {
    return("#000000") # Return black for invalid codes
  }

  # Standard and high-intensity colors (0-15)
  if (code < 16) {
    return(c(
      "#000000",
      "#cd0000",
      "#00cd00",
      "#cdcd00",
      "#0000ee",
      "#cd00cd",
      "#00cdcd",
      "#e5e5e5",
      "#7f7f7f",
      "#ff0000",
      "#00ff00",
      "#ffff00",
      "#5c5cff",
      "#ff00ff",
      "#00ffff",
      "#ffffff"
    )[code + 1])
  }

  # 6x6x6 color cube (16-231)
  if (code >= 16 && code <= 231) {
    code <- code - 16
    r <- floor(code / 36)
    g <- floor((code %% 36) / 6)
    b <- code %% 6
    levels <- c(0, 95, 135, 175, 215, 255) # xterm levels
    return(grDevices::rgb(
      levels[r + 1],
      levels[g + 1],
      levels[b + 1],
      maxColorValue = 255
    ))
  }

  # Grayscale ramp (232-255)
  gray_level <- (code - 232) * 10 + 8
  grDevices::rgb(
    gray_level,
    gray_level,
    gray_level,
    maxColorValue = 255
  )
}


#' Gradient text
#'
#' @param x Character: Text to colorize.
#' @param colors Character vector: Colors to use for the gradient.
#' @param bold Logical: If TRUE, make text bold.
#' @param output_type Character: Output type ("ansi", "html", "plain").
#'
#' @return Character: Text with gradient color applied.
#'
#' @author EDG
#' @noRd
fmt_gradient <- function(
  x,
  colors,
  bold = FALSE,
  output_type = c("ansi", "html", "plain")
) {
  output_type <- match.arg(output_type)

  if (output_type == "plain") {
    return(x)
  }

  # Split text into individual characters
  chars <- strsplit(x, "")[[1]]
  n_chars <- length(chars)

  if (n_chars <= 1) {
    # For single character or empty string, use first color
    return(fmt(x, col = colors[1], output_type = output_type))
  }

  # Generate gradient colors using colorRampPalette
  tryCatch(
    {
      gradient_colors <- grDevices::colorRampPalette(colors)(
        n_chars
      )
    },
    error = function(e) {
      warning("Invalid gradient colors, using default")
      x
    }
  )

  # Apply gradient colors to each character
  gradient_chars <- character(n_chars)
  for (i in seq_len(n_chars)) {
    gradient_chars[i] <- fmt(
      chars[i],
      col = gradient_colors[i],
      bold = bold,
      output_type = output_type
    )
  }

  # Combine all colored characters
  paste(gradient_chars, collapse = "")
}


#' Add padding
#'
#' Convenience function to add padding.
#'
#' @param pad Integer: Number of spaces to ouput - that's all.
#' @param output_type Character: Output type ("ansi", "html", "plain").
#'
#' @author EDG
#' @noRd
show_pad <- function(pad = 2L, output_type = NULL) {
  if (is.null(output_type)) {
    output_type <- get_output_type()
  }
  pad_str <- strrep(" ", pad)
  switch(
    output_type,
    "ansi" = {
      # ANSI: pad with spaces, optionally style (no color for pad)
      pad_str
    },
    "html" = {
      # HTML: pad with non-breaking spaces
      strrep("&nbsp;", pad)
    },
    "plain" = pad_str
  )
}


# %% repr_S7name ----
#' Show S7 class name
#'
#' @param x Character: S7 class name.
#' @param col Color: Color code for the object name.
#' @param pad Integer: Number of spaces to pad the message with.
#' @param prefix Character: Prefix to add to the object name.
#' @param output_type Character: Output type ("ansi", "html", "plain").
#'
#' @return Character: Formatted string that can be printed with cat().
#'
#' @author EDG
#' @noRd
#'
#' @examples
#' repr_S7name("Supervised") |> cat()
repr_S7name <- function(
  x,
  col = col_object,
  pad = 0L,
  prefix = NULL,
  output_type = NULL
) {
  output_type <- get_output_type(output_type)
  paste0(
    strrep(" ", pad),
    fmt("<", col = col, output_type = output_type),
    if (!is.null(prefix)) {
      gray(prefix, output_type = output_type)
    },
    fmt(x, bold = TRUE, output_type = output_type),
    fmt(">", col = col, output_type = output_type),
    "\n"
  )
}


#' Color columns of text art
#'
#' This function accepts text input of 1 or more lines and two colors.
#' It will:
#' a) generate a color gradient between the two colors
#' b) apply the gradient to each column of the text, creating a left to right color gradient.
#'
#' @param x Character vector of text to colorize.
#' @param color_left Color for the left side of the gradient.
#' @param color_right Color for the right side of the gradient.
#' @param output_type Character: Output type. One of "ansi", "html", "plain".
#'   Default = "ansi".
#'
#' @return Character vector with color formatting applied to each column.
#'
#' @author EDG
#' @noRd
color_txt_columns <- function(
  x,
  color_left,
  color_right,
  output_type = c("ansi", "html", "plain")
) {
  output_type <- match.arg(output_type)
  # Count number of columns in input text
  ncols <- max(nchar(x, type = "width"))

  if (ncols == 0) {
    return(x)
  }

  # Create color gradient from color_left to color_right with ncols steps
  gradient <- grDevices::colorRampPalette(c(color_left, color_right))(ncols)

  # Apply the colors to each column of the text
  result <- character(length(x))

  for (i in seq_along(x)) {
    line <- x[i]
    line_chars <- strsplit(line, "")[[1]]
    line_width <- nchar(line, type = "width")

    if (line_width == 0) {
      result[i] <- line
      next
    }

    colored_chars <- character(length(line_chars))

    for (j in seq_along(line_chars)) {
      char <- line_chars[j]
      if (char == " ") {
        colored_chars[j] <- char
      } else {
        # Use column position for gradient color
        col_pos <- min(j, ncols)
        colored_chars[j] <- fmt(
          char,
          col = gradient[col_pos],
          output_type = output_type
        )
      }
    }

    result[i] <- paste0(colored_chars, collapse = "")
  }

  result
}


# used by msgdatetime, log_to_file
datetime <- function(datetime_format = "%Y-%m-%d %H:%M:%S") {
  format(Sys.time(), datetime_format)
}

#' Message datetime()
#'
#' @param datetime_format Character: Format for the date and time.
#'
#' @return Character: Formatted date and time.
#'
#' @author EDG
#' @noRd
# Used by msg(), msg0(), msgstart()
msgdatetime <- function(datetime_format = "%Y-%m-%d %H:%M:%S") {
  message(gray(paste0(datetime(), " ")), appendLF = FALSE)
}


format_caller <- function(call_stack, call_depth, caller_id, max_char = 30L) {
  stack.length <- length(call_stack)
  if (stack.length < 2) {
    caller <- NA
  } else {
    call_depth <- call_depth + caller_id
    if (call_depth > stack.length) {
      call_depth <- stack.length
    }
    caller <- paste(
      lapply(
        rev(seq(call_depth)[-seq(caller_id)]),
        function(i) rev(call_stack)[[i]][[1]]
      ),
      collapse = ">>"
    )
  }
  # do.call and similar will change the call stack, it will contain the full
  # function definition instead of the name alone
  # Capture S7 method calls
  if (!is.na(caller) && substr(caller, 1, 8) == "`method(") {
    caller <- sub("`method\\(([^,]+),.*\\)`", "\\1", caller)
  }
  if (is.function(caller)) {
    # Try to get function name from call stack context
    caller <- tryCatch(
      {
        # Get the original call stack element as character
        call_str <- deparse(rev(call_stack)[[rev(seq(call_depth)[
          -seq(caller_id)
        ])[1]]])
        # Extract function name from the call
        fn_match <- regexpr("^[a-zA-Z_][a-zA-Z0-9_\\.]*", call_str)
        if (fn_match > 0) {
          regmatches(call_str, fn_match)
        } else {
          "(fn)"
        }
      },
      error = function(e) "(fn)"
    )
  }
  if (is.character(caller)) {
    if (nchar(caller) > 30) caller <- paste0(substr(caller, 1, 27), "...")
  }
  caller
}


#' Message with provenance
#'
#' Print message to output with a prefix including data and time, and calling function or full
#' call stack
#'
#' If `msg` is called directly from the console, it will print `[interactive>]` in place of
#'   the call stack.
#' `msg0`, similar to `paste0`, is `msg(..., sep = "")`
#'
# Add following to each function using \code{msg}:
# \code{current <- as.list(sys.call())[[1]]}
#'
#' @param ... Message to print
#' @param date Logical: if TRUE, include date and time in the prefix
#' @param caller Character: Name of calling function
#' @param call_depth Integer: Print the system call path of this depth.
#' @param caller_id Integer: Which function in the call stack to print
#' @param newline_pre Logical: If TRUE begin with a new line.
#' @param newline Logical: If TRUE end with a new line.
#' @param format_fn Function: Formatting function to use on the message text.
#' @param sep Character: Use to separate objects in `...`
#'
#' @return Invisibly: List with call, message, and date
#'
#' @author EDG
#' @noRd
#'
#' @examples
#' msg("Hello, world!")
msg <- function(
  ...,
  date = TRUE,
  caller = NULL,
  call_depth = 1L,
  caller_id = 1L,
  newline_pre = FALSE,
  newline = TRUE,
  format_fn = plain,
  sep = " "
) {
  if (is.null(caller)) {
    call_stack <- as.list(sys.calls())
    caller <- format_caller(call_stack, call_depth, caller_id)
  }

  txt <- Filter(Negate(is.null), list(...))
  if (newline_pre) {
    message("")
  }
  if (date) {
    msgdatetime()
  }
  message(
    format_fn(paste(txt, collapse = sep)),
    appendLF = FALSE
  )
  if (!is.null(caller) && !is.na(caller) && nchar(caller) > 0L) {
    message(plain(gray(paste0(" [", caller, "]"))))
  } else if (newline) {
    message("")
  }
}


#' @rdname msg
#'
#' @author EDG
#' @noRd
#'
#' @examples
#' x <- 42L
#' msg0("The answer is what you think it is (", x, ").")
msg0 <- function(
  ...,
  caller = NULL,
  call_depth = 1,
  caller_id = 1,
  newline_pre = FALSE,
  newline = TRUE,
  format_fn = plain,
  sep = ""
) {
  if (is.null(caller)) {
    call_stack <- as.list(sys.calls())
    caller <- format_caller(call_stack, call_depth, caller_id)
  }

  txt <- Filter(Negate(is.null), list(...))
  if (newline_pre) {
    message("")
  }
  msgdatetime()
  message(
    format_fn(paste(txt, collapse = sep)),
    appendLF = FALSE
  )
  if (!is.null(caller) && !is.na(caller) && nchar(caller) > 0L) {
    message(plain(gray(paste0(" [", caller, "]"))))
  } else if (newline) {
    message("")
  }
}


#' Pad-cat
#'
#' Pad and concatenate two strings, with optional newline.
#'
#' @param left Character: Left string to pad and print.
#' @param right Character: Right string to print after left.
#' @param pad Integer: Total width to pad the left string to.
#' @param newline Logical: If TRUE, print a newline after the right string.
#'
#' @author EDG
#' @noRd
#'
#' @examples
#' \dontrun{
#' {
#'   msg("Hello")
#'   pcat("super", "wow")
#'   pcat(NULL, "oooo")
#' }
#' }
pcat <- function(left, right, pad = 17, newline = TRUE) {
  lpad <- max(0, pad - 1 - max(0, nchar(left)))
  cat(pad_string(left), right)
  if (newline) cat("\n")
}


pad_string <- function(x, target = 17, char = " ") {
  lpad <- max(0, target - max(0, nchar(x)))
  paste0(
    paste(rep(char, lpad), collapse = ""),
    x
  )
}


#' msgstart
#'
#' @inheritParams msg
#'
#' @author EDG
#' @noRd
msgstart <- function(
  ...,
  newline_pre = FALSE,
  sep = ""
) {
  txt <- Filter(Negate(is.null), list(...))
  if (newline_pre) {
    message()
  }
  msgdatetime()
  message(plain(paste(txt, collapse = sep)), appendLF = FALSE)
}


#' msgdone
#'
#' @inheritParams msg
#'
#' @author EDG
#' @noRd
msgdone <- function(caller = NULL, call_depth = 1, caller_id = 1, sep = " ") {
  if (is.null(caller)) {
    call_stack <- as.list(sys.calls())
    caller <- format_caller(call_stack, call_depth, caller_id)
  }
  message(" ", appendLF = FALSE)
  yay(end = "")
  message(gray(paste0("[", caller, "]\n")), appendLF = FALSE)
}


#' Force plain text when using `message()`
#'
#' @param x Character: Text to be output to console.
#'
#' @return Character: Text with ANSI escape codes removed.
#'
#' @author EDG
#' @noRd
plain <- function(x) {
  paste0("\033[0m", x)
}


# %% utils.checks ----------------------------------------------------------------------------------
# clean_* functions performm checks and return clean inputs.
# check_* functions perform checks (do not return a value).

# %% test_inherits ----
#' Check class of object
#'
#' @param x Object to check
#' @param cl Character: class to check against
#'
#' @return Logical
#' @author EDG
#' @keywords internal
#' @noRd
#'
#' @examples
#' test_inherits("papaya", "character") # TRUE
#' test_inherits(c(1, 2.5, 3.2), "integer")
#' test_inherits(iris, "list") # FALSE, compare to is_check(iris, is.list)
test_inherits <- function(x, cl) {
  if (!inherits(x, cl)) {
    input <- deparse(substitute(x))
    message(red(bold(input), "is not", bold(cl)))
    return(FALSE)
  }
  TRUE
}


# %% check_inherits ----
#' Check class of object
#'
#' @param x Object to check.
#' @param cl Character: class to check against.
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' check_inherits("papaya", "character")
#' # These will throw errors:
#' # check_inherits(c(1, 2.5, 3.2), "integer")
#' # check_inherits(iris, "list")
check_inherits <- function(
  x,
  cl,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!inherits(x, cl)) {
    cli::cli_abort(
      "{.var {xname}} must be of class {.cls {cl}}."
    )
  }

  invisible()
}


# %% clean_int ----
#' Clean integer input
#'
#' @details
#' The goal is to return an integer vector.
#' If the input is integer, it is returned as is.
#' If the input is numeric, it is coerced to integer only if the numeric values are integers,
#' otherwise an error is thrown.
#'
#' @param x Double or integer vector to check.
#'
#' @return Integer vector
#' @author EDG
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' clean_int(6L)
#' clean_int(3)
#' # clean_int(12.1) # Error
#' clean_int(c(3, 5, 7))
#' # clean_int(c(3, 5, 7.01)) # Error
clean_int <- function(x, xname = deparse(substitute(x))) {
  if (is.integer(x)) {
    return(x)
  } else if (is.numeric(x)) {
    if (all(x %% 1 == 0)) {
      storage.mode(x) <- "integer"
      return(x)
    } else {
      cli::cli_abort("{.var {xname}} must be integer.")
    }
  } else if (is.null(x)) {
    return(NULL)
  }
  cli::cli_abort("{.var {xname}} must be integer.")
}


# %% match_arg ----
#' Match Arguments Ignoring Case
#'
#' @param x Character: Argument to match.
#' @param choices Character vector: Choices to match against.
#'
#' @return Character: Matched argument.
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
#'
#' @examples
#' match_arg("papaya", c("AppleExtreme", "SuperBanana", "PapayaMaster"))
match_arg <- function(x, choices) {
  out <- match.arg(tolower(x), tolower(choices))
  grep(out, choices, value = TRUE, ignore.case = TRUE)
}


# %% check_logical ----
#' Check logical
#'
#' @param x Vector to check
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#' @author EDG
#'
#' @keywords internal
#' @noRd
check_logical <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }
  if (!is.logical(x)) {
    cli::cli_abort("{.var {xname}} must be logical.")
  }

  invisible()
}


# %% check_character ----
#' Check character
#'
#' @param x Vector to check
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#' @keywords internal
#' @noRd
check_character <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }
  if (!is.character(x)) {
    cli::cli_abort("{.var {xname}} must be character.")
  }

  invisible()
}


# %% check_floatpos ----
#' Check positive float
#'
#' @details
#' Checking with `is.numeric()` allows integer inputs as well, which should be ok since it is
#' unlikely the function that consumes this will enforce double type only, but instead is most
#' likely to allow implicit coercion from integer to numeric.
#'
#' @param x Float vector.
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail, otherwise invisible().
#'
#' @author EDG
#' @keywords internal
#' @noRd
check_floatpos <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort("{.var {xname}} must be numeric.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x <= 0)) {
    cli::cli_abort("{.var {xname}} must be greater than 0.")
  }

  invisible()
}


# %% check_float01exc ----
#' Check float between 0 and 1, exclusive
#'
#' @param x Vector to check
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#' @keywords internal
#' @noRd
#' @examples
#' check_float01exc(0.5)
check_float01exc <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort("{.var {xname}} must be numeric.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x <= 0 | x >= 1)) {
    cli::cli_abort(
      "{.var {xname}} must be between 0 and 1, exclusive."
    )
  }

  invisible()
}


# %% check_float01inc ----
#' Check float between 0 and 1, inclusive
#'
#' @param x Float vector.
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#' @keywords internal
#' @noRd
#' @examples
#' check_float01inc(0.5)
check_float01inc <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort(
      "{.var {xname}} must be numeric. Received: {.val {x}} of class {class(x)}",
      call. = FALSE
    )
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x < 0 | x > 1)) {
    cli::cli_abort("{.var {xname}} must be between 0 and 1, inclusive.")
  }

  invisible()
}


# %% check_floatpos1 ----
check_floatpos1 <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort("{.var {xname}} must be numeric.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x <= 0) || any(x > 1)) {
    cli::cli_abort(
      "{.var {xname}} must be greater than 0 and less or equal to 1."
    )
  }

  invisible()
}


# %% clean_posint ----
#' Check positive integer
#'
#' @param x Integer vector.
#'
#' @return x, otherwise error.
#'
#' @author EDG
#' @keywords internal
#' @noRd
#'
#' @examples
#' clean_posint(5)
clean_posint <- function(x, allow_na = FALSE, xname = deparse(substitute(x))) {
  if (is.null(x)) {
    return(NULL)
  }

  if (!allow_na && anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  } else {
    x <- na.exclude(x)
  }

  if (any(x <= 0)) {
    cli::cli_abort("{.var {xname}} must contain only positive integers.")
  }

  clean_int(x, xname = xname)
}


# %% check_float0pos ----
#' Check float greater than or equal to 0
#'
#' Checks if an input is a numeric vector containing non-negative
#'   (>= 0) values and no `NA`s. It is designed to validate function arguments.
#'
#' @param x Numeric vector: The input object to check.
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
check_float0pos <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort("{.var {xname}} must be numeric.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x < 0)) {
    cli::cli_abort("{.var {xname}} must be zero or greater.")
  }

  invisible()
}


# %% check_float_neg1_1 ----
#' Check float -1 <= x <= 1
#'
#' @param x Numeric vector: The input object to check.
#' @param allow_null Logical: If TRUE, NULL values are allowed and return early.
#'
#' @return Called for side effects. Throws an error if checks fail.
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
check_float_neg1_1 <- function(
  x,
  allow_null = TRUE,
  xname = deparse(substitute(x))
) {
  if (allow_null && is.null(x)) {
    return(invisible())
  }

  if (is.null(x)) {
    cli::cli_abort("{.var {xname}} cannot be NULL.")
  }

  if (!is.numeric(x)) {
    cli::cli_abort("{.var {xname}} must be numeric.")
  }

  if (anyNA(x)) {
    cli::cli_abort("{.var {xname}} must not contain NAs.")
  }

  if (any(x < -1 | x > 1)) {
    cli::cli_abort("{.var {xname}} must be between -1 and 1, inclusive.")
  }

  invisible()
}


# %% abbreviate_class ----
#' Abbreviate object class name
#'
#' @param x Object
#'
#' @return Character: Abbreviated class
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
abbreviate_class <- function(x, n = 4L) {
  paste0("<", abbreviate(class(x)[1], minlength = n), ">")
}


# %% check_dependencies ----
#' \pkg{rtemis} internal: Dependencies check
#'
#' Checks if dependencies can be loaded; names missing dependencies if not.
#'
#' @param ... List or vector of strings defining namespaces to be checked
#' @param verbosity Integer: Verbosity level.
#' Note: An error will always printed if dependencies are missing.
#' Setting this to FALSE stops it from printing
#' "Dependencies check passed".
#'
#' @return Called for side effects. Aborts and prints list of missing dependencies, if any.
#'
#' @author EDG
#'
#' @keywords internal
#' @noRd
check_dependencies <- function(..., verbosity = 0L) {
  ns <- as.list(c(...))
  err <- !sapply(ns, \(i) requireNamespace(i, quietly = TRUE))
  if (any(err)) {
    cli::cli_abort(
      paste0(
        "Please install the following ",
        ngettext(sum(err), "dependency", "dependencies"),
        ":\n",
        pastels(ns[err], bullet = "    -")
      )
    )
  } else {
    if (verbosity > 0L) msg("Dependency check passed")
  }
  invisible()
}


# %% check_data.table ----
#' Check data.table
#'
#' @param x Object to check.
#'
#' @return Called for side effects. Throws an error if input is not a data.table, returns x
#' invisibly otherwise.
#'
#' @author EDG
#' @keywords internal
#' @noRd
check_data.table <- function(x, xname = deparse(substitute(x))) {
  if (!data.table::is.data.table(x)) {
    cli::cli_abort("{.var {xname}} must be a data.table.")
  }
  invisible(x)
}


# %% check_tabular ----
#' Check object is tabular
#'
#' Checks if object is of class `data.frame`, `data.table`, or `tbl_df`.
#'
#' @param x Object to check.
#'
#' @return Called for side effects. Throws an error if input is not tabular, returns x invisibly
#' otherwise.
#'
#' @author EDG
#' @keywords internal
#' @noRd
check_tabular <- function(x) {
  if (!inherits(x, c("data.frame", "data.table", "tbl_df"))) {
    cli::cli_abort(
      "{.var {deparse(substitute(x))}} must be a data.frame, data.table, or tbl_df."
    )
  }
  invisible(x)
}


# %% pastels ----
#' @keywords internal
#' @noRd
pastels <- function(x, bullet = "  -") {
  paste(paste(bullet, x, collapse = "\n"), "\n")
} # /rtemis.utils::pastels


# %% red ----
#' Red
#'
#' @author EDG
#' @keywords internal
#' @noRd
red <- function(..., bold = FALSE) {
  fmt(
    paste(...),
    col = rt_red,
    bold = bold
  )
}


# %% green ----
#' Make text green
#'
#' @param ... Character: Text to colorize.
#' @param bold Logical: If TRUE, make text bold.
#'
#' @author EDG
#' @noRd
green <- function(..., bold = FALSE) {
  fmt(
    paste(...),
    col = rt_green,
    bold = bold
  )
}


# %% yay ----
#' Success message
#'
#' @param ... Character: Message components.
#' @param sep Character: Separator between message components.
#' @param end Character: End character.
#' @param pad Integer: Number of spaces to pad the message with.
#'
#' @author EDG
#' @keywords internal
#' @noRd
yay <- function(..., sep = " ", end = "\n", pad = 0) {
  message(
    strrep(" ", pad),
    green("\u2714 "),
    paste(..., sep = sep),
    end,
    appendLF = FALSE
  )
}
